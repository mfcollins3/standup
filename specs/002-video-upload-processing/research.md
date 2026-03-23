# Research: Upload Status Video for Processing

**Date**: 2026-03-22
**Phase**: 0 — Outline & Research
**Status**: Complete

---

## R-001: Azure Developer CLI (azd) Project Structure

**Decision**: Use standard azd project layout with `azure.yaml` at repo root, `infra/` for Bicep, `api/` for Azure Functions.

**Rationale**: azd enforces conventions that reduce configuration overhead. Following the standard layout means `azd up`, `azd provision`, and `azd deploy` work out of the box. The project already uses Azure for backend services, so azd alignment is natural.

**Key Findings**:

- `azure.yaml` declares the project and maps services to source directories:
  ```yaml
  name: standup
  services:
    api:
      host: function
      language: dotnet
      project: ./api
  ```
- `main.bicep` MUST use `targetScope = 'subscription'` — azd creates the resource group itself.
- azd auto-passes `environmentName` and `location` parameters to `main.bicep`. These are the only required parameters; additional parameters go in `main.bicepparam`.
- `main.bicepparam` supports azd variable substitution: `${AZURE_ENV_NAME}`, `${AZURE_LOCATION}`, `${AZURE_PRINCIPAL_ID}`. Bicep parameter files use the `using` declaration to reference the Bicep template and native Bicep syntax for parameter values.
- Resources MUST have an `azd-service-name` tag matching the service key in `azure.yaml` so azd can discover the deployed resource for code deployment.
- Use `abbreviations.json` for Cloud Adoption Framework naming: `apim-` (API Management), `func-` (Function App), `kv-` (Key Vault), `st` (Storage), `plan-` (App Service Plan), `rg-` (Resource Group).
- Generate globally unique names with: `resourceToken = toLower(uniqueString(subscription().id, environmentName, location))`.
- Outputs from `main.bicep` become azd environment variables (e.g., `output AZURE_STORAGE_ACCOUNT_NAME string`).
- A Function App requires a backing storage account for internal runtime state — this is separate from the video storage account.
- Use Consumption SKU (`Y1/Dynamic`) for the Function App's App Service Plan.

**Alternatives Considered**:
- Manual ARM/Bicep deployment without azd — rejected because azd provides a unified `provision + deploy` workflow that simplifies developer onboarding and CI/CD.
- Terraform — rejected per constitution (Principle V mandates Bicep for Azure IaC).

---

## R-002: SAS URL Generation Pattern (Azure Functions + Blob Storage)

**Decision**: Use **user delegation SAS** signed with the Function App's managed identity via Entra ID. No storage account keys anywhere.

**Rationale**: Microsoft explicitly recommends user delegation SAS over service/account SAS. It eliminates storage account key management entirely — no keys to rotate, no keys to store in Key Vault. The Function App authenticates to Blob Storage via its system-assigned managed identity, which is the most secure pattern.

**Key Findings**:

- **RBAC roles required on the Function App's managed identity**:
  1. **Storage Blob Delegator** (`db58b8e5-c6ad-4a2a-8342-4190687cbf4a`) — required to call `GetUserDelegationKey`
  2. **Storage Blob Data Contributor** (`ba92f5b4-2d11-453d-a403-e96b0029c9fe`) — required to generate SAS tokens that grant blob write access

- **NuGet packages**: `Azure.Identity`, `Azure.Storage.Blobs`

- **SAS configuration**:
  - `BlobSasBuilder.Resource = "b"` (blob-level, not container)
  - Permissions: `Write | Create` only
  - Protocol: HTTPS only (`SasProtocol.Https`)
  - `StartsOn`: `UtcNow - 5 minutes` (clock skew tolerance)
  - `ExpiresOn`: `UtcNow + 15 minutes` (per FR-020)
  - Blob path scoped to a unique path per upload (e.g., `uploads/{userId}/{guid}.mp4`)

- **DI registration**: Register `BlobServiceClient` with `DefaultAzureCredential` and the storage account URL from an environment variable (`AZURE_STORAGE_BLOB_ENDPOINT`).

- **Code pattern** (C# .NET 10 isolated worker):
  ```csharp
  var userDelegationKey = await blobServiceClient.GetUserDelegationKeyAsync(
      DateTimeOffset.UtcNow.AddMinutes(-5),
      DateTimeOffset.UtcNow.AddMinutes(15));

  var sasBuilder = new BlobSasBuilder
  {
      BlobContainerName = containerName,
      BlobName = blobName,
      Resource = "b",
      StartsOn = DateTimeOffset.UtcNow.AddMinutes(-5),
      ExpiresOn = DateTimeOffset.UtcNow.AddMinutes(15),
      Protocol = SasProtocol.Https
  };
  sasBuilder.SetPermissions(BlobSasPermissions.Write | BlobSasPermissions.Create);

  var blobUriBuilder = new BlobUriBuilder(blobServiceClient.Uri)
  {
      BlobContainerName = containerName,
      BlobName = blobName,
      Sas = sasBuilder.ToSasQueryParameters(userDelegationKey, blobServiceClient.AccountName)
  };

  return blobUriBuilder.ToUri();
  ```

- **Bicep role assignments**: Use `guid(storageAccount.id, functionApp.id, roleDefinitionId)` for deterministic role assignment names.

**Alternatives Considered**:
- Service SAS signed with storage account key — rejected because it requires key management and Microsoft discourages it.
- Account key stored in Key Vault — rejected because user delegation SAS eliminates key management entirely.

---

## R-003: API Management + Azure Functions Bicep Integration

**Decision**: Use APIM **Consumption** tier with subscription key authentication, backed by the Azure Function App.

**Rationale**: Consumption tier is free at startup volumes (first 1M calls/month), has a 99.95% SLA, auto-scales, and supports subscription key auth — the only auth mechanism needed now. Developer tier is explicitly for non-production use and has no SLA, so it was rejected for a shipping product.

**Key Findings**:

### APIM Tier Selection

| Factor | Consumption | Developer | BasicV2 |
|--------|------------|-----------|---------|
| Monthly cost | ~$0 (first 1M free) | ~$48/mo | ~$150/mo |
| SLA | 99.95% | None | 99.95% |
| Subscription keys | Yes | Yes | Yes |
| Auto-scaling | Yes | No | Yes |
| Developer portal | No | Yes | Yes |
| VNet integration | No | Yes | Yes |
| Production use | Yes | No | Yes |

- Cold start caveat: Consumption tier has ~1-2s cold start after idle. Acceptable for upload initiation (not latency-sensitive).
- Upgrade path: Move to BasicV2 when developer portal, analytics, or VNet is needed.

### Bicep Resources Required

1. **APIM Service** (`Microsoft.ApiManagement/service`) — Consumption SKU, `capacity: 0`
2. **Named Value** (`service/namedValues`) — stores Function App host key as a secret
3. **Backend** (`service/backends`) — points to Function App URL, injects `x-functions-key` header
4. **API** (`service/apis`) — defines the Standup API with `subscriptionRequired: true`
5. **API Policy** (`service/apis/policies`) — `<set-backend-service>` routes to Function App backend
6. **Subscription** (`service/subscriptions`) — creates the iOS client API key, scoped to the API

### Custom API Key Header

- Configured `subscriptionKeyParameterNames.header` to `X-Api-Key` (instead of default `Ocp-Apim-Subscription-Key`).
- iOS client passes: `request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")`.

### APIM-to-Function Authentication

- APIM backend definition includes the Function App host key in the `x-functions-key` header via a named value reference.
- This means the Function App can use `AuthorizationLevel.Function` to restrict direct access — only APIM can call it.
- The host key is passed to Bicep as a `@secure()` parameter (retrieved from Key Vault or azd environment).

### Policy XML

```xml
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="{functionAppBackendName}" />
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
```

- `<base />` in inbound inherits subscription key validation (automatic when `subscriptionRequired: true`).
- `<set-backend-service>` rewrites the request URL to the Function App and injects the `x-functions-key` header.

**Alternatives Considered**:
- Developer tier — rejected: no SLA, explicitly for non-production use only.
- No APIM (call Functions directly) — rejected: violates the requirement for API key auth and future OAuth 2.0 migration. APIM provides a clean gateway abstraction.
- Azure Front Door as the gateway — rejected: Front Door is a CDN/load balancer, not an API gateway. It doesn't support subscription key auth or API-level policies.

---

## R-004: iOS URLSession Background Transfer Configuration

**Decision**: Use `URLSession` with `background(withIdentifier:)` configuration for video uploads.

**Rationale**: This is the only iOS mechanism that survives app suspension, termination, and device restart. Required by FR-002 and FR-016.

**Key Findings**:

- Create session with `URLSessionConfiguration.background(withIdentifier: "app.nakedstandup.upload")`.
- Set `isDiscretionary = false` for user-initiated uploads (system won't defer them).
- Set `allowsCellularAccess` based on user preference (FR-017/018).
- Use `uploadTask(with:fromFile:)` — the file-based variant is required for background sessions (data-based is not supported).
- The video file must remain on disk at a stable path for the duration of the upload.
- Implement `URLSessionDelegate` methods: `urlSession(_:task:didCompleteWithError:)`, `urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)`.
- Reconnect to the background session on app launch via `application(_:handleEventsForBackgroundURLSession:completionHandler:)` or the SwiftUI equivalent.
- Background sessions automatically retry on transient network failures (configurable via `waitsForConnectivity`).

**Alternatives Considered**:
- In-app background task (`BGTask`) — rejected: only gets ~30 seconds of execution time, not sufficient for large file uploads.
- Third-party upload library (e.g., Alamofire) — rejected per constitution Principle VII (Simplicity). URLSession provides everything needed natively.

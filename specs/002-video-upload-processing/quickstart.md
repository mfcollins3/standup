# Quickstart: Upload Status Video for Processing

**Feature Branch**: `002-video-upload-processing`
**Prerequisites**: Azure CLI, Azure Developer CLI (`azd`), .NET 10 SDK, Xcode 26+

---

## 1. Provision Azure Infrastructure

```bash
# From the repository root
azd init           # First time only — sets environment name and location
azd provision      # Creates resource group and deploys Bicep templates
```

This provisions:
- Azure Blob Storage account with `status-videos` container
- Azure Functions App (Consumption plan, .NET 10 isolated worker)
- Azure API Management (Consumption tier)
- Azure Key Vault
- All RBAC role assignments (managed identity → Storage Blob Delegator + Storage Blob Data Contributor)

After provisioning, note the APIM subscription key from the Azure Portal:
**Portal → API Management → Subscriptions → ios-client-subscription → Show Primary Key**

## 2. Deploy the Azure Function

```bash
azd deploy         # Builds and deploys the api/ project to Azure Functions
```

Or deploy only the API service:

```bash
azd deploy api
```

## 3. Verify the Backend

Test the SAS URL endpoint via curl:

```bash
curl -X POST "https://{apim-name}.azure-api.net/standup/video" \
  -H "X-Api-Key: {subscription-key}" \
  -H "Content-Type: application/json" \
  -d '{"contentType": "video/mp4", "fileSizeBytes": 1024}'
```

Expected response:

```json
{
  "uploadUrl": "https://ststandup....blob.core.windows.net/status-videos/uploads/...?sv=...&sig=...",
  "expiresAt": "2026-03-22T10:15:00Z"
}
```

## 4. Local Development (Azure Function)

```bash
cd api
dotnet restore
func start          # Runs the Function App locally (requires Azure Functions Core Tools)
```

The Function runs at `http://localhost:7071/api/video`. For local development, you need:
- `local.settings.json` with `AZURE_STORAGE_BLOB_ENDPOINT` pointing to a storage account (or Azurite emulator).
- Azure CLI login (`az login`) so `DefaultAzureCredential` can authenticate.

## 5. iOS Development

Open the Xcode workspace and build the Standup target:

```bash
cd Apple
tuist generate      # Regenerates Xcode project if needed
open Standup.xcworkspace
```

The iOS upload service requires:
- APIM base URL configured (injected via build configuration or environment)
- API key configured (injected via build configuration — **do not hardcode**)

## 6. Run Tests

**Azure Function tests**:

```bash
cd api
dotnet test
```

**iOS tests**: Run from Xcode using `Cmd+U` on the Standup scheme, or:

```bash
cd Apple
tuist test
```

## 7. Full End-to-End Flow

1. Record and approve a status video in the iOS app
2. Tap Submit → app requests SAS URL from APIM → APIM forwards to Azure Function
3. Function generates user delegation SAS URL → returns to app
4. App uploads video directly to Blob Storage via URLSession background transfer
5. Blob Storage fires `BlobCreated` Event Grid event (processing trigger — future feature)

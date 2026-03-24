# Quickstart: Stream Video Transcoding via Cloudflare Stream

**Feature Branch**: `003-stream-video-transcoding`
**Prerequisites**: Azure CLI, Azure Developer CLI (`azd`), .NET 10 SDK, Azure Functions Core Tools v4

---

## 1. Configure Cloudflare Credentials

Store Cloudflare credentials in `local.settings.json` for local development:

```json
{
  "Values": {
    "CLOUDFLARE_ACCOUNT_ID": "<your-cloudflare-account-id>",
    "CLOUDFLARE_API_TOKEN": "<your-cloudflare-api-token>"
  }
}
```

The API token requires the **Stream Write** permission scope. Create one at:
**Cloudflare Dashboard → My Profile → API Tokens → Create Token → Custom Token**

For deployed environments, these values are stored in Azure Key Vault and referenced via Function App application settings.

## 2. Build and Run Locally

```bash
cd api
dotnet restore      # Pulls new EventGrid extension package
dotnet build
func start          # Runs the Function App locally
```

The Function App runs at `http://localhost:7071`. You need:
- Azure CLI login (`az login`) so `DefaultAzureCredential` can authenticate for SAS URL generation.
- `AZURE_STORAGE_BLOB_ENDPOINT` in `local.settings.json` pointing to a storage account (Azurite does not support user delegation keys — use a real storage account for SAS testing).

## 3. Test the ProcessVideo Function Locally

Event Grid triggers can be tested locally via HTTP POST. Send a simulated `BlobCreated` event:

```bash
curl -X POST "http://localhost:7071/runtime/webhooks/EventGrid?functionName=ProcessVideo" \
  -H "Content-Type: application/json" \
  -H "aeg-event-type: Notification" \
  -d '[{
    "id": "test-event-001",
    "topic": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest",
    "subject": "/blobServices/default/containers/status-videos/blobs/uploads/anonymous/test-video.mp4",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2026-03-23T14:30:00Z",
    "dataVersion": "",
    "metadataVersion": "1",
    "data": {
      "api": "PutBlob",
      "clientRequestId": "00000000-0000-0000-0000-000000000001",
      "requestId": "00000000-0000-0000-0000-000000000002",
      "eTag": "0x8DB12345ABCDEF0",
      "contentType": "video/mp4",
      "contentLength": 1024000,
      "blobType": "BlockBlob",
      "url": "https://ststandup.blob.core.windows.net/status-videos/uploads/anonymous/test-video.mp4",
      "sequencer": "0000000000000000000000000000012340000000000abcdef",
      "storageDiagnostics": { "batchId": "test-batch" }
    }
  }]'
```

**Expected result**: The function generates a read SAS URL for the blob and submits it to the Cloudflare Stream API. Check the function logs for:
- `Processing BlobCreated event for blob: uploads/anonymous/test-video.mp4`
- `Generated read SAS URL, expires at: ...`
- `Submitted to Cloudflare Stream, video UID: ...`

## 4. Test Validation — Unsupported Content Type

```bash
curl -X POST "http://localhost:7071/runtime/webhooks/EventGrid?functionName=ProcessVideo" \
  -H "Content-Type: application/json" \
  -H "aeg-event-type: Notification" \
  -d '[{
    "id": "test-event-002",
    "topic": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest",
    "subject": "/blobServices/default/containers/status-videos/blobs/uploads/anonymous/readme.txt",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2026-03-23T14:30:00Z",
    "dataVersion": "",
    "metadataVersion": "1",
    "data": {
      "api": "PutBlob",
      "clientRequestId": "00000000-0000-0000-0000-000000000003",
      "requestId": "00000000-0000-0000-0000-000000000004",
      "eTag": "0x8DB12345ABCDEF1",
      "contentType": "text/plain",
      "contentLength": 256,
      "blobType": "BlockBlob",
      "url": "https://ststandup.blob.core.windows.net/status-videos/uploads/anonymous/readme.txt",
      "sequencer": "0000000000000000000000000000012340000000000abcdf0",
      "storageDiagnostics": { "batchId": "test-batch" }
    }
  }]'
```

**Expected result**: The function skips processing and logs a warning about unsupported content type.

## 5. Run Unit Tests

```bash
cd api
dotnet test
```

## 6. Deploy to Azure

### First-Time Deployment (Two-Pass Bootstrap)

On the first deployment, the Event Grid subscription cannot be created because the Function App code has not been deployed yet (the system key doesn't exist):

```bash
# Pass 1: Deploy infrastructure without Event Grid
azd provision       # Uses enableEventGrid=false (default)

# Deploy function code so the runtime creates the system key
azd deploy

# Pass 2: Enable Event Grid subscription
azd provision --parameter enableEventGrid=true
```

### Subsequent Deployments

After the initial bootstrap, the system key persists across deployments:

```bash
azd provision       # enableEventGrid=true in parameters file
azd deploy
```

## 7. Verify End-to-End in Azure

1. Upload a video through the iOS app or via the CreateVideo API (Feature 002)
2. The upload creates a blob in `status-videos/uploads/`
3. Event Grid emits a `BlobCreated` event → delivered to ProcessVideo function
4. ProcessVideo generates a read SAS URL and submits to Cloudflare Stream
5. Verify in Cloudflare Dashboard → **Stream → Videos** that the video appears with status `downloading` → `ready`

### Check Function Logs

```bash
az monitor app-insights query \
  --app {app-insights-name} \
  --analytics-query "traces | where message contains 'ProcessVideo' | order by timestamp desc | take 10"
```

## 8. Key Vault Secrets (Deployed Environments)

| Secret Name | Description |
|-------------|-------------|
| `CloudflareAccountId` | Cloudflare account identifier |
| `CloudflareApiToken` | API token with Stream Write permission |

These are referenced in the Function App's application settings as Key Vault references:

```
CLOUDFLARE_ACCOUNT_ID = @Microsoft.KeyVault(SecretUri=https://{vault}.vault.azure.net/secrets/CloudflareAccountId)
CLOUDFLARE_API_TOKEN = @Microsoft.KeyVault(SecretUri=https://{vault}.vault.azure.net/secrets/CloudflareApiToken)
```

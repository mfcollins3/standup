# Quickstart: Cloudflare Stream Webhook Endpoint

**Feature Branch**: `004-cloudflare-webhook`
**Prerequisites**: .NET 10 SDK, Azure Functions Core Tools v4

---

## 1. Configure Webhook Signing Secret

Add the Cloudflare webhook signing secret to `local.settings.json`:

```json
{
  "Values": {
    "CLOUDFLARE_WEBHOOK_SIGNING_SECRET": "<your-signing-secret>"
  }
}
```

The signing secret is returned by Cloudflare when you register a webhook URL via the Stream API. For local testing, you can use any arbitrary string (e.g., `test-secret`) and compute matching signatures manually (see Step 3).

For deployed environments, the signing secret is stored in Azure Key Vault and referenced via Function App application settings.

## 2. Build and Run Locally

```bash
cd api
dotnet restore
dotnet build
func start
```

The Function App runs at `http://localhost:7071`. The webhook endpoint is available at:
```
POST http://localhost:7071/api/webhooks/cloudflare/stream
```

## 3. Test the Webhook — Valid Signature

To test locally, you need to compute a valid HMAC-SHA256 signature. Use this bash script to generate the `Webhook-Signature` header:

```bash
# Configuration
SECRET="test-secret"
TIMESTAMP=$(date +%s)

# Webhook payload (success notification)
BODY='{
  "uid": "dd5d531a12de0c724bd1275a3b2bc9c6",
  "readyToStream": true,
  "status": {
    "state": "ready",
    "pctComplete": "100"
  },
  "meta": {
    "filename": "my-video.mp4",
    "blobpath": "uploads/user123/550e8400.mp4"
  },
  "duration": 42.5,
  "input": { "width": 1920, "height": 1080 },
  "playback": {
    "hls": "https://customer-abc.cloudflarestream.com/dd5d531a/manifest/video.m3u8",
    "dash": "https://customer-abc.cloudflarestream.com/dd5d531a/manifest/video.mpd"
  },
  "thumbnail": "https://customer-abc.cloudflarestream.com/dd5d531a/thumbnails/thumbnail.jpg",
  "created": "2026-03-23T14:30:00.000Z",
  "modified": "2026-03-23T14:32:15.000Z",
  "size": 12345678,
  "preview": "https://watch.cloudflarestream.com/dd5d531a"
}'

# Compute signature
SOURCE_STRING="${TIMESTAMP}.${BODY}"
SIGNATURE=$(echo -n "$SOURCE_STRING" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

# Send webhook
curl -X POST "http://localhost:7071/api/webhooks/cloudflare/stream" \
  -H "Content-Type: application/json" \
  -H "Webhook-Signature: time=${TIMESTAMP},sig1=${SIGNATURE}" \
  -d "$BODY"
```

**Expected result**: HTTP 200 OK. Function logs show:
- `Received Cloudflare Stream webhook for video: dd5d531a12de0c724bd1275a3b2bc9c6`
- `Video dd5d531a12de0c724bd1275a3b2bc9c6 is ready to stream`

## 4. Test the Webhook — Error Notification

Use the same script from Step 3 but replace the body with an error payload:

```bash
BODY='{
  "uid": "dd5d531a12de0c724bd1275a3b2bc9c6",
  "readyToStream": false,
  "status": {
    "state": "error",
    "pctComplete": null,
    "errorReasonCode": "ERR_NON_VIDEO",
    "errorReasonText": "The file was not recognized as a valid video file."
  },
  "meta": {
    "filename": "not-a-video.txt"
  },
  "duration": 0,
  "input": { "width": 0, "height": 0 },
  "playback": null,
  "thumbnail": null,
  "created": "2026-03-23T14:30:00.000Z",
  "modified": "2026-03-23T14:31:05.000Z",
  "size": 1234,
  "preview": null
}'
```

**Expected result**: HTTP 200 OK. Function logs show:
- `Received Cloudflare Stream webhook for video: dd5d531a12de0c724bd1275a3b2bc9c6`
- `Video dd5d531a12de0c724bd1275a3b2bc9c6 processing failed: ERR_NON_VIDEO`

## 5. Test Validation — Missing Signature

```bash
curl -X POST "http://localhost:7071/api/webhooks/cloudflare/stream" \
  -H "Content-Type: application/json" \
  -d '{"uid": "test", "readyToStream": true}'
```

**Expected result**: HTTP 401 Unauthorized with body `{ "error": "Missing webhook signature" }`.

## 6. Test Validation — Invalid Signature

```bash
curl -X POST "http://localhost:7071/api/webhooks/cloudflare/stream" \
  -H "Content-Type: application/json" \
  -H "Webhook-Signature: time=1230811200,sig1=0000000000000000000000000000000000000000000000000000000000000000" \
  -d '{"uid": "test", "readyToStream": true}'
```

**Expected result**: HTTP 401 Unauthorized with body `{ "error": "Invalid webhook signature" }`.

## 7. Test Validation — Empty Body

```bash
curl -X POST "http://localhost:7071/api/webhooks/cloudflare/stream" \
  -H "Content-Type: application/json" \
  -H "Webhook-Signature: time=1230811200,sig1=abc123"
```

**Expected result**: HTTP 400 Bad Request with body `{ "error": "Request body is required" }`.

## 8. Run Unit Tests

```bash
cd api
dotnet test
```

## 9. Deploy to Azure

```bash
azd provision    # Adds CLOUDFLARE_WEBHOOK_SIGNING_SECRET Key Vault reference
azd deploy       # Deploys updated function code
```

After deployment, register the webhook URL with Cloudflare:

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/webhook" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  -d '{"notificationUrl": "https://{functionApp}.azurewebsites.net/api/webhooks/cloudflare/stream"}'
```

The response includes the `secret` field — store this value in Azure Key Vault as the `CLOUDFLARE_WEBHOOK_SIGNING_SECRET` secret.

## 10. Verify End-to-End in Azure

1. Upload a video through the iOS app or via the CreateVideo API (Feature 002)
2. The upload triggers Event Grid → ProcessVideo → Cloudflare Stream (Feature 003)
3. Cloudflare transcodes the video and sends a webhook notification to the CloudflareWebhook endpoint
4. Check Application Insights for structured logs showing video UID, status, and readyToStream state

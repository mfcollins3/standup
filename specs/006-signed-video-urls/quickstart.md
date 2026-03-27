# Quickstart: Signed Video URLs for Secure Streaming

**Date**: 2026-03-26
**Feature**: [spec.md](spec.md) | [plan.md](plan.md)

## Prerequisites

1. Existing Naked Standup API running locally (from features 001–005).
2. A Cloudflare Stream account with at least one uploaded video.
3. A Cloudflare signing key (obtain from the `/stream/key` API endpoint).
4. .NET 10.0 SDK installed.

## Setup

### 1. Obtain a Cloudflare Signing Key

```bash
curl --request POST \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/stream/key
```

Save the `id` and `jwk` (or `pem`) from the response.

### 2. Configure Local Secrets

```bash
cd api
dotnet user-secrets set "CLOUDFLARE_SIGNING_KEY_ID" "<key-id-from-step-1>"
dotnet user-secrets set "CLOUDFLARE_SIGNING_KEY_JWK" "<base64-jwk-from-step-1>"
```

### 3. Set the Customer Code

Add to `local.settings.json` (or user secrets):

```json
{
  "Values": {
    "CLOUDFLARE_CUSTOMER_CODE": "<your-customer-code>"
  }
}
```

The customer code is the value after `customer-` in your Cloudflare Stream URLs (e.g., for `customer-f33zs165nr7gyfy4.cloudflarestream.com`, the code is `f33zs165nr7gyfy4`).

### 4. Build and Run

```bash
cd api
dotnet build
cd bin/Debug/net10.0
func host start
```

## Usage

### Get a Signed HLS URL

```bash
curl "http://localhost:7071/api/video/{videoId}/stream?streamType=hls"
```

Response:

```json
{
  "signedUrl": "https://customer-<CODE>.cloudflarestream.com/<TOKEN>/manifest/video.m3u8",
  "expiresAt": "2026-03-26T14:00:00Z"
}
```

### Get a Signed DASH URL

```bash
curl "http://localhost:7071/api/video/{videoId}/stream?streamType=dash"
```

Response:

```json
{
  "signedUrl": "https://customer-<CODE>.cloudflarestream.com/<TOKEN>/manifest/video.mpd",
  "expiresAt": "2026-03-26T14:00:00Z"
}
```

### Error: Video Not Found

```bash
curl "http://localhost:7071/api/video/00000000-0000-0000-0000-000000000000/stream?streamType=hls"
```

Returns `404 Not Found`.

### Error: Invalid Stream Type

```bash
curl "http://localhost:7071/api/video/{videoId}/stream?streamType=rtmp"
```

Returns `400 Bad Request`.

## Verification

1. Upload a video through the existing `POST /video` pipeline.
2. Wait for the Cloudflare webhook to mark the video as `Ready`.
3. Request a signed HLS URL for the video.
4. Open the signed URL in a browser or video player — the video should play.
5. Try the public URL (without the token) — it should be rejected by Cloudflare.

## Running Tests

```bash
cd api
dotnet test
```

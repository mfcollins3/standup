# standup Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-23

## Active Technologies
- C# / .NET 10.0 + Azure Functions Worker v4, Azure.Storage.Blobs 12.23.0, Azure.Identity 1.13.2, Microsoft.Azure.Functions.Worker.Extensions.EventGrid 3.6.0, HttpClient (Cloudflare Stream API) (003-stream-video-transcoding)
- Azure Blob Storage (video files in `status-videos` container) (003-stream-video-transcoding)
- C# / .NET 10.0 + Azure Functions Worker v4, Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore 2.1.0, System.Security.Cryptography (HMAC-SHA256 signature verification) (004-cloudflare-webhook)
- N/A — this feature only logs notifications; persistence is deferred (004-cloudflare-webhook)

- Swift 6 (iOS client), C# / .NET 10 (Azure Functions), Bicep (infrastructure) + SwiftUI, URLSession, Azure.Storage.Blobs SDK, Azure Functions runtime v4, Azure API Management (002-video-upload-processing)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Swift 6 (iOS client), C# / .NET 10 (Azure Functions), Bicep (infrastructure)

## Code Style

Swift 6 (iOS client), C# / .NET 10 (Azure Functions), Bicep (infrastructure): Follow standard conventions

## Recent Changes
- 004-cloudflare-webhook: Added C# / .NET 10.0 + Azure Functions Worker v4, Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore 2.1.0, System.Security.Cryptography (HMAC-SHA256 signature verification)
- 003-stream-video-transcoding: Added C# / .NET 10.0 + Azure Functions Worker v4, Azure.Storage.Blobs 12.23.0, Azure.Identity 1.13.2, Microsoft.Azure.Functions.Worker.Extensions.EventGrid 3.6.0, HttpClient (Cloudflare Stream API)

- 002-video-upload-processing: Added Swift 6 (iOS client), C# / .NET 10 (Azure Functions), Bicep (infrastructure) + SwiftUI, URLSession, Azure.Storage.Blobs SDK, Azure Functions runtime v4, Azure API Management

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

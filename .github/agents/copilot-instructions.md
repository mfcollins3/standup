# standup Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-27

## Active Technologies
- C# / .NET 10.0 + Azure Functions Worker v4, Azure.Storage.Blobs 12.23.0, Azure.Identity 1.13.2, Microsoft.Azure.Functions.Worker.Extensions.EventGrid 3.6.0, HttpClient (Cloudflare Stream API) (003-stream-video-transcoding)
- Azure Blob Storage (video files in `status-videos` container) (003-stream-video-transcoding)
- C# / .NET 10.0 + Azure Functions Worker v4, Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore 2.1.0, System.Security.Cryptography (HMAC-SHA256 signature verification) (004-cloudflare-webhook)
- N/A — this feature only logs notifications; persistence is deferred (004-cloudflare-webhook)
- C# / .NET 10.0 + Microsoft.Azure.Functions.Worker 2.51.0, EF Core 10.0 + Npgsql.EntityFrameworkCore.PostgreSQL, Azure.Identity 1.13.2 (005-video-tracking-persistence)
- Azure Database for PostgreSQL Flexible Server (Burstable B1ms, 32 GB, v17) (005-video-tracking-persistence)
- Swift 6 / iOS 26.0+ + SwiftUI, AVKit, Combine (all system frameworks) (007-video-playback-screen)
- N/A (no persistence for this feature) (007-video-playback-screen)

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
- 007-video-playback-screen: Added Swift 6 / iOS 26.0+ + SwiftUI, AVKit, Combine (all system frameworks)
- 005-video-tracking-persistence: Added C# / .NET 10.0 + Microsoft.Azure.Functions.Worker 2.51.0, EF Core 10.0 + Npgsql.EntityFrameworkCore.PostgreSQL, Azure.Identity 1.13.2
- 004-cloudflare-webhook: Added C# / .NET 10.0 + Azure Functions Worker v4, Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore 2.1.0, System.Security.Cryptography (HMAC-SHA256 signature verification)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

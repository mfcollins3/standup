# Implementation Plan: Signed Video URLs for Secure Streaming

**Branch**: `006-signed-video-urls` | **Date**: 2026-03-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-signed-video-urls/spec.md`

## Summary

Lock down all Cloudflare Stream videos to require signed URLs and expose an Azure Function API endpoint (fronted by APIM) that accepts a video ID and stream type (HLS or DASH) and returns a time-limited signed streaming URL. The `ProcessVideo` function is modified to include the `requireSignedURLs: true` flag when submitting videos to Cloudflare. A new `GetSignedStreamUrl` function generates RS256 JWT tokens locally using a Cloudflare signing key (stored in Key Vault), constructs the manifest URL with the token in place of the video UID, and returns it to the client. No Cloudflare API call is required at playback time — tokens are self-signed.

## Technical Context

**Language/Version**: C# 14 / .NET 10.0
**Primary Dependencies**: Microsoft.Azure.Functions.Worker 2.51.0, System.IdentityModel.Tokens.Jwt (for RS256 JWT generation), Npgsql.EntityFrameworkCore.PostgreSQL 10.0.1, Azure.Identity 1.13.2
**Storage**: Azure Database for PostgreSQL Flexible Server (existing), Azure Key Vault (existing — signing key stored here)
**Testing**: xUnit 2.9.2, Moq 4.20.72
**Target Platform**: Azure Functions Flex Consumption (FC1), Linux
**Project Type**: Serverless cloud API (Azure Functions isolated worker)
**Performance Goals**: Signed URL generation must complete in < 200ms (purely local crypto, no network call)
**Constraints**: Cloudflare signing key material must never appear in source code or logs. Token expiration defaults to 1 hour. Tokens are RS256 JWTs compatible with Cloudflare's token verification.
**Scale/Scope**: 1 new Azure Function, 1 modified Azure Function, 1 new service interface + implementation, 1 new APIM operation, 2 new Key Vault secrets, Bicep updates

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Ship Often | PASS | Incremental feature: adds a new endpoint and modifies one existing function. No changes to existing upload/webhook contracts. |
| II. Keep Quality High | PASS | TDD for new `GetSignedStreamUrl` function and `ISignedUrlTokenService`. Unit tests for token generation, video validation, and error paths. |
| III. Solicit and Respond to Feedback | PASS | API returns meaningful error responses for all failure modes (not found, not ready, invalid stream type). |
| IV. Security by Default | PASS | Core security feature — locks videos behind signed URLs. Signing key in Key Vault. Tokens are time-limited. No secrets in code or logs. |
| V. Infrastructure as Code | PASS | New Key Vault secrets and APIM operation defined in Bicep. |
| VI. Conventional Commits | PASS | Commits will use `feat`, `build`, `test`, and `docs` types as appropriate. |
| VII. Simplicity | PASS | Self-signing with JWT avoids per-request Cloudflare API calls. Single new service, single new function. No unnecessary abstractions. |
| VIII. Accessibility and Inclusivity | PASS | Backend-only API changes; no UI impact. Both HLS and DASH supported for client flexibility. |

## Project Structure

### Documentation (this feature)

```text
specs/006-signed-video-urls/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
api/
├── Api.csproj                              (MODIFIED - add System.IdentityModel.Tokens.Jwt NuGet package)
├── Program.cs                              (MODIFIED - register ISignedUrlTokenService in DI)
├── Functions/
│   ├── GetSignedStreamUrl.cs               (NEW - HTTP GET /video/{videoId}/stream Azure Function)
│   └── ProcessVideo.cs                     (MODIFIED - pass requireSignedURLs: true to Cloudflare)
├── Models/
│   ├── GetSignedStreamUrlResponse.cs       (NEW - response record with signedUrl and expiresAt)
│   └── CloudflareStreamRequest.cs          (existing - already has RequireSignedURLs property)
├── Services/
│   ├── ISignedUrlTokenService.cs           (NEW - interface for signed URL token generation)
│   └── SignedUrlTokenService.cs            (NEW - RS256 JWT generation using Cloudflare signing key)
├── Api.Tests/
│   ├── Functions/
│   │   ├── GetSignedStreamUrlTests.cs      (NEW - unit tests for the new function)
│   │   └── ProcessVideoTests.cs            (MODIFIED - verify requireSignedURLs flag)
│   └── Services/
│       └── SignedUrlTokenServiceTests.cs   (NEW - unit tests for token generation)

infra/
├── modules/
│   ├── api-management.bicep                (MODIFIED - add get-signed-stream-url APIM operation)
│   └── key-vault.bicep                     (MODIFIED - add Cloudflare signing key secrets)
```

**Structure Decision**: Follows existing project layout. New function and service in existing directories. No new project or layer needed.

## Complexity Tracking

> No constitution violations. No complexity justifications needed.
# Implementation Plan: Video Tracking and Persistence

**Branch**: `005-video-tracking-persistence` | **Date**: 2026-03-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-video-tracking-persistence/spec.md`

## Summary

Implement video lifecycle tracking by provisioning an Azure Database for PostgreSQL Flexible Server and persisting video state across all three Azure Functions. A new `Video` entity with EF Core and the Npgsql provider will track each video through its status transitions (created → uploaded → processing → ready/failed). The `CreateVideo` function creates a record with a constant placeholder user ID and returns the video ID. `ProcessVideo` updates the status to "uploaded" then "processing", stores the Cloudflare video UID, and passes the Video record's `Id` in the Cloudflare `/stream/copy` meta dictionary alongside the existing `blobPath`. `CloudflareWebhook` looks up the Video record using the round-tripped `videoId` from the webhook payload's meta (primary) with a fallback to `cloudflare_video_uid` (for backward compatibility), then updates the record with playback URLs (HLS, DASH), thumbnail URL, duration, dimensions, and final status. PostgreSQL is provisioned via Bicep with Entra-only managed identity authentication — no database passwords. The `IDbContextFactory<StandupDbContext>` pattern is used for serverless-safe EF Core usage in Azure Functions.

## Technical Context

**Language/Version**: C# / .NET 10.0  
**Primary Dependencies**: Microsoft.Azure.Functions.Worker 2.51.0, EF Core 10.0 + Npgsql.EntityFrameworkCore.PostgreSQL, Azure.Identity 1.13.2  
**Storage**: Azure Database for PostgreSQL Flexible Server (Burstable B1ms, 32 GB, v17)  
**Testing**: xUnit 2.9.2, Moq 4.20.72, Microsoft.AspNetCore.Mvc.Testing 10.0.0  
**Target Platform**: Azure Functions Flex Consumption (FC1), Linux  
**Project Type**: Serverless cloud API (Azure Functions isolated worker)  
**Performance Goals**: Database operations should complete within reasonable latency for serverless; no specific throughput target at this stage  
**Constraints**: Entra-only authentication (no database passwords), managed identity from Function App, FC1 cold-start considerations for EF Core initialization  
**Scale/Scope**: Single Video entity, 3 Azure Functions modified, 1 new Bicep module, placeholder for ~1 user (constant ID)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Ship Often, Learn Fast | PASS | Incremental feature: adds persistence layer without changing existing HTTP/EventGrid contracts. Placeholder user ID defers auth complexity. |
| II. Quality Over Speed | PASS | TDD for new Video entity, StandupDbContext, and all function modifications. xUnit + Moq for unit tests. |
| III. Feedback Is a Gift | PASS | Video status tracking provides system-level feedback on pipeline state. CreateVideo returns video ID for client tracking. |
| IV. Security by Default | PASS | Entra-only managed identity auth to PostgreSQL — no passwords in config or code. TLS enforced. Key Vault pattern continues for Cloudflare secrets. |
| V. Infrastructure as Code | PASS | New `postgresql.bicep` module added to existing Bicep-based IaC. All provisioning automated via `azd`. |
| VI. Conventional Commits | PASS | All commits will follow the project's Conventional Commits format with appropriate types (feat, build, docs, test). |
| VII. Simplicity | PASS | Direct EF Core with IDbContextFactory — no repository pattern, no CQRS, no unnecessary abstractions. Minimal Video entity with only required fields. |
| VIII. Accessibility and Inclusivity | PASS | Backend-only changes; no UI impact. API response extension (adding videoId) is additive and backward-compatible for clients that don't use it. |

## Project Structure

### Documentation (this feature)

```text
specs/005-video-tracking-persistence/
├── spec.md              # Feature specification (NEW)
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
├── Program.cs                              (MODIFIED - add EF Core + Npgsql DI registration)
├── Api.csproj                              (MODIFIED - add EF Core + Npgsql NuGet packages)
├── Data/
│   ├── StandupDbContext.cs                 (NEW - EF Core DbContext with Video DbSet)
│   ├── Video.cs                            (NEW - Video entity with status, URLs, metadata)
│   └── Migrations/                         (NEW - EF Core migration for initial Video table)
├── Functions/
│   ├── CreateVideo.cs                      (MODIFIED - create Video record, return video ID)
│   ├── ProcessVideo.cs                     (MODIFIED - update status to uploaded/processing, store Cloudflare UID)
│   └── CloudflareWebhook.cs               (MODIFIED - update status to ready/failed, store URLs)
├── Models/
│   ├── CreateVideoResponse.cs              (MODIFIED - add VideoId property)
│   └── ErrorResponse.cs                    (existing)
├── Services/
│   ├── CloudflareStreamService.cs          (MODIFIED - add videoId parameter, include in meta dictionary)
│   ├── ICloudflareStreamService.cs         (MODIFIED - add videoId parameter to SubmitForTranscodingAsync)
│   └── ...                                 (unchanged)
├── Api.Tests/
│   ├── Api.Tests.csproj                    (MODIFIED - add EF Core InMemory or SQLite test package)
│   ├── Functions/
│   │   ├── CreateVideoTests.cs             (MODIFIED - add database assertion tests)
│   │   ├── ProcessVideoTests.cs            (MODIFIED - add database assertion tests)
│   │   └── CloudflareWebhookTests.cs       (MODIFIED - add database assertion tests)
│   └── Data/
│       └── StandupDbContextTests.cs        (NEW - DbContext configuration tests)

infra/
├── main.bicep                              (MODIFIED - add postgresql module, wire outputs)
├── main.bicepparam                         (existing)
├── abbreviations.json                      (MODIFIED - add PostgreSQL abbreviation)
└── modules/
    ├── postgresql.bicep                    (NEW - PostgreSQL Flexible Server with Entra auth)
    ├── function-app.bicep                  (MODIFIED - add PostgreSQL connection string app setting)
    └── ...                                 (unchanged)

docs/
└── adrs/
    └── 004-postgresql-video-persistence.md (NEW - ADR for PostgreSQL decision)
```

**Structure Decision**: The existing repository structure is maintained — Azure Functions in `api/`, infrastructure in `infra/modules/`, ADRs in `docs/adrs/`. A new `api/Data/` directory is introduced for the EF Core DbContext and entity classes, following .NET conventions for data access layer separation. No new projects are needed; the Video entity and DbContext live in the existing `Api` project.

## Complexity Tracking

> No constitution violations. All principles pass.

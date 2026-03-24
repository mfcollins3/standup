# Implementation Plan: Stream Video Transcoding via Cloudflare Stream

**Branch**: `003-stream-video-transcoding` | **Date**: 2026-03-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-stream-video-transcoding/spec.md`

## Summary

This feature connects the video upload pipeline (Feature 002) to streaming delivery by automatically transcoding uploaded videos via Cloudflare Stream. The implementation spans two domains:

1. **Azure Functions** — A new Event Grid–triggered Azure Function (`ProcessVideo`) that fires when a video blob is created in the `status-videos/uploads/` path. The function generates a time-limited read SAS URL for the uploaded blob and submits it to the Cloudflare Stream "Upload from URL" API, which downloads and transcodes the video for on-demand streaming playback. Cloudflare API credentials are stored in Azure Key Vault and accessed via managed identity.

2. **Azure Infrastructure** — A new Bicep module (`event-grid.bicep`) to deploy the Event Grid system topic and event subscription, wired to deliver `BlobCreated` events to the new processing function. The event subscription includes retry policy and dead-letter configuration. A two-pass bootstrap deployment is required because the Event Grid webhook endpoint needs the Function App's system key, which is only available after the function code is deployed.

The function handles idempotency (duplicate events), content-type validation, and transient failure retry. Processing status is tracked via an internal record associating blob paths with Cloudflare Stream video UIDs.

## Technical Context

**Language/Version**: C# / .NET 10.0
**Primary Dependencies**: Azure Functions Worker v4, Azure.Storage.Blobs 12.23.0, Azure.Identity 1.13.2, Microsoft.Azure.Functions.Worker.Extensions.EventGrid 3.6.0, HttpClient (Cloudflare Stream API)
**Storage**: Azure Blob Storage (video files in `status-videos` container)
**Testing**: xUnit 2.9.2, Moq 4.20.72
**Target Platform**: Azure Functions Flex Consumption (FC1, Linux, .NET 10 isolated worker)
**Project Type**: Serverless functions / cloud API + infrastructure-as-code
**Performance Goals**: Transcoding submission within 2 minutes of upload completion (SC-001); <1s p95 for read SAS URL generation
**Constraints**: Videos <50 MB, read SAS URL ~1 hour expiry, Cloudflare Stream API rate limits (120 concurrent encoding jobs per account, ~1200 requests/5 min)
**Scale/Scope**: Single Function App, single storage account, single Cloudflare Stream account

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
*Post-Phase 1 re-evaluation: All 8 principles confirmed PASS. No design drift detected.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Ship Often | PASS | Feature is scoped to Event Grid trigger + Cloudflare Stream submission. Playback integration, webhooks, and video deletion are explicitly out of scope. Status tracking (P2) is included but lightweight — just recording the Cloudflare video UID. |
| II. Keep Quality High | PASS | TDD workflow for new ProcessVideo function and Cloudflare service. xUnit + Moq. ADR for upload architecture (002) exists; new ADR for transcoding integration not required unless architectural decisions deviate. |
| III. Solicit Feedback | PASS | Processing status tracking enables downstream features to surface video readiness to users. Logging and monitoring provide operational visibility. |
| IV. Security by Default | PASS | Cloudflare API credentials stored in Azure Key Vault, accessed via managed identity. Read SAS URLs are time-limited (~1 hour), scoped to single blob, read-only, HTTPS-only. Server-to-server only — SAS URL never exposed to end users. No secrets in code or config. |
| V. Infrastructure as Code | PASS | Event Grid system topic and event subscription managed via Bicep. Key Vault secrets for Cloudflare credentials provisioned via Bicep. No manual resource creation. |
| VI. Conventional Commits | PASS | Standard commit workflow applies. |
| VII. Simplicity | PASS | One new function, one new service interface (Cloudflare client). Extends existing SasUrlService for read SAS. Minimal new abstractions. No additional storage systems — idempotency check uses blob metadata or a simple approach without a new database. |
| VIII. Accessibility | PASS | Backend-only feature — no direct UI changes. Transcoded videos will support captions/transcripts in future features. |

**Gate result: PASS** — no violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
api/
├── Functions/
│   ├── CreateVideo.cs           # (existing) POST /video endpoint
│   └── ProcessVideo.cs          # (NEW) Event Grid trigger — processes uploaded videos
├── Models/
│   ├── CreateVideoRequest.cs    # (existing)
│   ├── CreateVideoResponse.cs   # (existing)
│   ├── ErrorResponse.cs         # (existing)
│   ├── CloudflareStreamRequest.cs   # (NEW) Cloudflare "Upload from URL" API request model
│   └── CloudflareStreamResponse.cs  # (NEW) Cloudflare "Upload from URL" API response model
├── Services/
│   ├── ISasUrlService.cs        # (MODIFIED) Add read SAS method
│   ├── SasUrlService.cs         # (MODIFIED) Implement read SAS generation
│   ├── ICloudflareStreamService.cs  # (NEW) Interface for Cloudflare Stream API
│   └── CloudflareStreamService.cs   # (NEW) HTTP client for Cloudflare Stream "Upload from URL"
├── Program.cs                   # (MODIFIED) Register new services and HttpClient
├── Api.csproj                   # (MODIFIED) Add Event Grid trigger package
└── Api.Tests/
    └── Functions/
        ├── CreateVideoTests.cs      # (existing)
        └── ProcessVideoTests.cs     # (NEW) Unit tests for ProcessVideo function

infra/
├── main.bicep                   # (MODIFIED) Wire Event Grid outputs if needed
└── modules/
    ├── storage.bicep            # (MODIFIED) Remove commented-out Event Grid resources (cleanup)
    ├── event-grid.bicep         # (NEW) Event Grid system topic and event subscription
    ├── function-app.bicep       # (MODIFIED) Add Cloudflare credential app settings from Key Vault
    └── key-vault.bicep          # (MODIFIED) Add Cloudflare API key and Account ID secrets
```

**Structure Decision**: Extends the existing `api/` project structure (Mobile + API pattern). New files follow established conventions — one function per file in `Functions/`, service interface + implementation in `Services/`, models in `Models/`. No new projects needed; all code lives in the existing `Standup.Api` project and `Standup.Api.Tests` test project.

## Complexity Tracking

No constitution violations — no entries required.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | — | — |

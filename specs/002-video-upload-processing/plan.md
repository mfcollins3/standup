# Implementation Plan: Upload Status Video for Processing

**Branch**: `002-video-upload-processing` | **Date**: 2026-03-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-video-upload-processing/spec.md`

## Summary

This feature enables users to upload approved status videos from the iOS app to Azure Blob Storage for server-side processing (transcoding, captions, transcripts). The implementation spans two domains:

1. **Azure Infrastructure** — Bicep templates provisioning Blob Storage, Azure Functions, API Management, and Key Vault, compatible with Azure Developer CLI (`azd`). An Azure Function generates scoped, short-lived SAS URLs for direct blob upload. API Management fronts the Function with API key authentication (OAuth 2.0 + JWT deferred to a future story).

2. **iOS Client** — URLSession background transfer–based upload service that requests a SAS URL from the API, uploads directly to Blob Storage, and provides progress/retry/cancel UX.

Server-side processing is triggered by Blob Storage event subscriptions upon upload completion. Transcoding, caption, and transcript generation will be handled by downstream Azure Functions triggered by Event Grid.

## Technical Context

**Language/Version**: Swift 6 (iOS client), C# / .NET 10 (Azure Functions), Bicep (infrastructure)
**Primary Dependencies**: SwiftUI, URLSession, Azure.Storage.Blobs SDK, Azure Functions runtime v4, Azure API Management
**Storage**: Azure Blob Storage (video files), local device storage (pending uploads)
**Testing**: Swift Testing (iOS), xUnit (Azure Functions), Bicep linter + what-if (infrastructure)
**Target Platform**: iOS/iPadOS 26.0+ (client), Azure (backend)
**Project Type**: Mobile app + cloud API + infrastructure-as-code
**Performance Goals**: Upload initiation <5s from tap, SAS URL generation <1s p95
**Constraints**: Video files <50 MB, uploads must survive app suspension/termination, offline queueing required
**Scale/Scope**: Single-tenant initially, one storage account, one Function App, one APIM instance

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Ship Often | PASS | Feature is scoped to upload + infra provisioning. Transcoding/captions are triggered but detailed processing implementation is deferred. API key auth ships now; OAuth 2.0 is a future story. |
| II. Keep Quality High | PASS | TDD workflow for iOS upload service and Azure Function. Swift Testing + xUnit. ADR for upload architecture already exists (001). |
| III. Solicit Feedback | PASS | Upload progress UI gives immediate user feedback. Processing status available via polling. |
| IV. Security by Default | PASS | SAS URLs scoped to single blob, write and create, 15-min expiry. Secrets in Key Vault. APIM API key auth. No secrets in code. HTTPS everywhere. |
| V. Infrastructure as Code | PASS | All Azure resources provisioned via Bicep templates. azd-compatible project structure. No manual resource creation. |
| VI. Conventional Commits | PASS | Standard commit workflow applies. |
| VII. Simplicity | PASS | Minimal resource set: 1 Storage Account, 1 Function App, 1 APIM instance, 1 Key Vault. Direct blob upload avoids routing video through API. API key auth is the simplest viable option for now. |
| VIII. Accessibility | PASS | Upload progress and status are VoiceOver-accessible. Error/success messages support Dynamic Type. Captions and transcripts generated for video content. |

**Gate result: PASS** — no violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/002-video-upload-processing/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (API contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
infra/                              # Azure infrastructure (Bicep + azd)
├── main.bicep                      # Top-level orchestrator
├── main.bicepparam                 # azd Bicep parameter file
├── abbreviations.json              # Resource naming abbreviations
└── modules/
    ├── storage.bicep               # Blob Storage account + container
    ├── function-app.bicep          # Function App + App Service Plan
    ├── api-management.bicep        # APIM instance + API + operations
    └── key-vault.bicep             # Key Vault + secrets + access policies

api/                                # Azure Functions project (.NET 10)
├── Api.csproj
├── host.json
├── local.settings.json             # (gitignored)
├── Program.cs                      # Function app startup
└── Functions/
    └── CreateVideo.cs              # HTTP-triggered function: generates SAS URL

azure.yaml                          # Azure Developer CLI project file

Apple/Projects/Standup/Sources/     # iOS app (existing)
└── Upload/
    ├── UploadService.swift         # URLSession background transfer manager
    ├── UploadTask.swift            # Model: individual upload state
    ├── SasUrlClient.swift          # API client: requests SAS URL from backend
    └── UploadProgressView.swift    # UI: progress, retry, cancel

Apple/Projects/Standup/Tests/
└── Upload/
    ├── UploadServiceTests.swift
    ├── UploadTaskTests.swift
    └── SasUrlClientTests.swift
```

**Structure Decision**: Mobile + API pattern. The iOS app lives in the existing `Apple/` directory. Azure infrastructure uses a top-level `infra/` directory following azd conventions. The Azure Functions project lives in a top-level `api/` directory. An `azure.yaml` at the repo root ties the azd project together.

## Constitution Re-Check (Post–Phase 1 Design)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Ship Often | PASS | Data model has 6-state machine but all states are exercised by the scoped feature. No deferred-state bloat. Contracts define one endpoint — minimal surface. |
| II. Keep Quality High | PASS | Data model defines validation rules (file size, content type) suitable for TDD. API contract specifies error responses that can be tested against. Test file structure planned. |
| III. Solicit Feedback | PASS | Contract includes progress-observable upload (URLSession delegate). No gaps. |
| IV. Security by Default | PASS | User delegation SAS (no storage account keys). Write and create, single-blob scope, 15-min expiry. APIM API key via custom header. Function auth via host key in named value. Server generates blob path (userId + UUID) — no client-controlled path traversal. |
| V. Infrastructure as Code | PASS | All resources (Storage, Functions, APIM, Key Vault, role assignments) represented in Bicep module structure. azd-compatible layout with `azure.yaml`. |
| VI. Conventional Commits | PASS | No design impact — standard workflow applies. |
| VII. Simplicity | PASS | One API endpoint. Direct blob upload (no proxying video through API). Consumption-tier APIM. Minimal entity model (UploadTask + UploadStatus enum). No unnecessary abstractions. |
| VIII. Accessibility | PASS | Upload progress view planned with VoiceOver compatibility. Captions/transcripts as downstream processing. Dynamic Type support noted in spec. |

**Post-design gate result: PASS** — no violations or regressions from pre-research check.

## Complexity Tracking

No constitution violations to justify. The design uses the minimum resource set required by the feature spec and constitution technology stack.

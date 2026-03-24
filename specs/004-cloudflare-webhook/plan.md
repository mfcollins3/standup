# Implementation Plan: Cloudflare Stream Webhook Endpoint

**Branch**: `004-cloudflare-webhook` | **Date**: 2026-03-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/004-cloudflare-webhook/spec.md`

## Summary

This feature completes the Cloudflare Stream integration loop opened in Feature 003 by receiving inbound webhook notifications from Cloudflare when video transcoding completes or fails. The implementation adds:

1. **Azure Function** — A new HTTP-triggered Azure Function (`CloudflareWebhook`) that accepts POST requests from Cloudflare Stream. The function verifies the request signature using HMAC-SHA256 with a shared signing secret, parses the webhook payload to extract the video identifier and processing status, acknowledges receipt with an HTTP 200 response, and logs the notification details. Invalid or unsigned requests are rejected with HTTP 401.

2. **Webhook Signature Service** — A new service (`WebhookSignatureService`) that encapsulates Cloudflare's webhook signature verification algorithm: parsing the `Webhook-Signature` header (`time=<UNIX_TIMESTAMP>,sig1=<HEX_SIGNATURE>`), constructing the HMAC-SHA256 source string (`{time}.{body}`), computing the expected signature, and performing constant-time comparison. The signing secret is loaded from secure configuration (Azure Key Vault via app settings).

This feature intentionally limits scope to receiving, validating, and logging webhook notifications. Persisting video status, updating records, and triggering downstream actions are deferred to the next feature.

## Technical Context

**Language/Version**: C# / .NET 10.0
**Primary Dependencies**: Azure Functions Worker v4, Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore 2.1.0, System.Security.Cryptography (HMAC-SHA256 signature verification)
**Storage**: N/A — this feature only logs notifications; persistence is deferred
**Testing**: xUnit 2.9.2, Moq 4.20.72
**Target Platform**: Azure Functions Flex Consumption (FC1, Linux, .NET 10 isolated worker)
**Project Type**: Serverless functions / cloud API
**Performance Goals**: <5s response time per webhook request (SC-004) to avoid Cloudflare treating delivery as failed
**Constraints**: Must verify webhook signatures using HMAC-SHA256 with constant-time comparison; must fail closed when signing secret is missing; must handle duplicate deliveries gracefully
**Scale/Scope**: Single Function App, single webhook endpoint, ~1 notification per video transcoded

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Ship Often | PASS | Feature is scoped to receive, validate, and log webhook notifications only. Persistence, status updates, and downstream actions are explicitly out of scope and deferred to next feature. |
| II. Keep Quality High | PASS | TDD workflow for new CloudflareWebhook function and WebhookSignatureService. xUnit + Moq. Follows established patterns from ProcessVideo function. |
| III. Solicit Feedback | PASS | Structured logging of every webhook notification (accepted and rejected) provides operational visibility. Lays groundwork for future status tracking. |
| IV. Security by Default | PASS | HMAC-SHA256 signature verification with constant-time comparison. Signing secret stored in Azure Key Vault, accessed via app settings. Fail-closed when secret is missing. Secret never logged or exposed in error messages. |
| V. Infrastructure as Code | PASS | No new Azure resources required. Signing secret added to Key Vault and Function App settings via existing Bicep modules. |
| VI. Conventional Commits | PASS | Standard commit workflow applies. |
| VII. Simplicity | PASS | One new function, one new service interface (signature verification). Reuses existing Cloudflare response models where applicable. Minimal new abstractions. |
| VIII. Accessibility | PASS | Backend-only feature — no direct UI changes. |

**Gate result: PASS** — no violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/004-cloudflare-webhook/
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
│   ├── CreateVideo.cs               # (existing)
│   ├── ProcessVideo.cs              # (existing)
│   └── CloudflareWebhook.cs         # (NEW) HTTP POST trigger — receives Cloudflare webhook notifications
├── Models/
│   ├── CloudflareStreamRequest.cs   # (existing)
│   ├── CloudflareStreamResponse.cs  # (existing) — reuse CloudflareStreamResult, CloudflareStreamStatus, CloudflarePlayback
│   ├── CloudflareWebhookPayload.cs  # (NEW) Webhook-specific payload model with meta, input, duration fields
│   ├── CreateVideoRequest.cs        # (existing)
│   ├── CreateVideoResponse.cs       # (existing)
│   └── ErrorResponse.cs             # (existing)
├── Services/
│   ├── ICloudflareStreamService.cs  # (existing)
│   ├── CloudflareStreamService.cs   # (existing)
│   ├── ISasUrlService.cs            # (existing)
│   ├── SasUrlService.cs             # (existing)
│   ├── IWebhookSignatureService.cs  # (NEW) Interface for webhook signature verification
│   └── WebhookSignatureService.cs   # (NEW) HMAC-SHA256 signature verification implementation
├── Program.cs                       # (MODIFIED) Register WebhookSignatureService
├── Api.csproj                       # (unchanged — no new packages needed)
└── Api.Tests/
    └── Functions/
        ├── CreateVideoTests.cs          # (existing)
        ├── ProcessVideoTests.cs         # (existing)
        └── CloudflareWebhookTests.cs    # (NEW) Unit tests for CloudflareWebhook function
    └── Services/
        └── WebhookSignatureServiceTests.cs  # (NEW) Unit tests for signature verification
```

**Structure Decision**: Extends the existing `api/` project structure. New files follow established conventions — one function per file in `Functions/`, service interface + implementation in `Services/`, models in `Models/`. No new packages required; `System.Security.Cryptography` is part of the .NET BCL. No new Azure infrastructure resources — the webhook function runs in the existing Function App and the signing secret is added to existing Key Vault and app settings configuration.

## Complexity Tracking

No constitution violations — no entries required.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | — | — |

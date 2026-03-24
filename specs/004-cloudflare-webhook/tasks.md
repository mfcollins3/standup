# Tasks: Cloudflare Stream Webhook Endpoint

**Generated**: 2026-03-23
**Feature Spec**: [spec.md](spec.md)
**Implementation Plan**: [plan.md](plan.md)
**Data Model**: [data-model.md](data-model.md)
**API Contract**: [contracts/cloudflare-webhook.md](contracts/cloudflare-webhook.md)
**Research**: [research.md](research.md)
**Quickstart**: [quickstart.md](quickstart.md)

---

## Phase 1: Setup

> Verify the project is ready for feature development. No new NuGet
> packages are required — all cryptographic primitives are in the .NET
> BCL (`System.Security.Cryptography`).

- [ ] T001 Verify existing project builds and tests pass in `api/`

### T001 Details

Before adding any new code, confirm the project is in a clean state:

1. `cd api && dotnet build` — must succeed with no errors
2. `cd api/Api.Tests && dotnet test` — all existing tests must pass

No new packages are needed for this feature. `System.Security.Cryptography`
(HMAC-SHA256, `CryptographicOperations.FixedTimeEquals`) is part of the
.NET BCL and already available.

**Checkpoint**: Project builds and existing tests pass. Ready to
implement the webhook feature.

---

## Phase 2: Foundational — Infrastructure Configuration (BLOCKS all user stories)

> Add the webhook signing secret to Azure Key Vault and Function App
> configuration via existing Bicep modules. This must be in place
> before the webhook function can verify signatures in deployed
> environments.

- [ ] T002 [P] Add webhook signing secret to Key Vault in `infra/modules/key-vault.bicep`
- [ ] T003 [P] Add webhook signing secret app setting to Function App in `infra/modules/function-app.bicep`

### T002 Details

Modify `infra/modules/key-vault.bicep` to add a new secret for the
Cloudflare webhook signing secret:

1. Add a new `@secure()` parameter:
   ```bicep
   @secure()
   param cloudflareWebhookSigningSecret string = ''
   ```
2. Add a new secret resource:
   ```bicep
   resource webhookSigningSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(cloudflareWebhookSigningSecret)) {
     parent: keyVault
     name: 'CloudflareWebhookSigningSecret'
     properties: {
       value: cloudflareWebhookSigningSecret
     }
   }
   ```

This follows the same pattern used for the existing `CloudflareApiToken`
and `CloudflareAccountId` secrets (added in Feature 003).

See R-004 in research.md for the Key Vault reference pattern.

### T003 Details

Modify `infra/modules/function-app.bicep` to add a new application
setting that references the Key Vault secret:

```bicep
CLOUDFLARE_WEBHOOK_SIGNING_SECRET: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=CloudflareWebhookSigningSecret)'
```

Add this to the existing `appSettings` object alongside the other
`CLOUDFLARE_*` settings.

**Checkpoint**: Infrastructure configuration is ready. The signing
secret will be available to the Function App via Key Vault references
when deployed. For local development, the secret is configured directly
in `local.settings.json` (see quickstart.md section 1).

---

## Phase 3: US-2 — Validate Webhook Authenticity via Signature Verification (P1)

**Goal**: Implement the HMAC-SHA256 signature verification service that
validates incoming webhook requests are authentically from Cloudflare
and have not been tampered with.

**Independent Test**: Call `IWebhookSignatureService.VerifySignature()`
with valid and invalid signatures. Verify valid signatures return `true`,
invalid/missing/malformed signatures return `false`, and missing
configuration throws `InvalidOperationException`.

### Tests for US-2

- [ ] T004 [US2] Write signature verification tests in `api/Api.Tests/Services/WebhookSignatureServiceTests.cs`

### Implementation for US-2

- [ ] T005 [US2] Create signature verification interface in `api/Services/IWebhookSignatureService.cs`
- [ ] T006 [US2] Implement signature verification service in `api/Services/WebhookSignatureService.cs`

### T004 Details

Create `api/Api.Tests/Services/WebhookSignatureServiceTests.cs` with
xUnit tests for `WebhookSignatureService`. These tests are written
FIRST (TDD — RED phase). Create minimal stubs for
`IWebhookSignatureService` and `WebhookSignatureService` so the tests
compile but fail.

**Test Cases**:

- **Valid signature**: Compute a known HMAC-SHA256 signature using a
  test secret, timestamp, and body. Call `VerifySignature()` with the
  matching header. Assert returns `true`.
- **Invalid signature**: Use a valid header format but with an incorrect
  hex signature. Assert returns `false`.
- **Wrong secret**: Compute signature with one secret, configure service
  with a different secret. Assert returns `false`.
- **Missing signature header**: Pass `null` or empty string as the
  signature header. Assert returns `false`.
- **Malformed header — missing time**: Pass `sig1=abc123` (no `time=`
  component). Assert returns `false`.
- **Malformed header — missing sig1**: Pass `time=1230811200` (no
  `sig1=` component). Assert returns `false`.
- **Empty request body**: Pass empty string as body with a valid-format
  header. Assert returns `false`.
- **Missing configuration**: Create `WebhookSignatureService` without
  `CLOUDFLARE_WEBHOOK_SIGNING_SECRET` in configuration. Assert
  constructor throws `InvalidOperationException` (FR-011).

Use `Microsoft.Extensions.Configuration` with in-memory configuration
for test setup:

```csharp
var config = new ConfigurationBuilder()
    .AddInMemoryCollection(new Dictionary<string, string?>
    {
        ["CLOUDFLARE_WEBHOOK_SIGNING_SECRET"] = "test-secret"
    })
    .Build();
var service = new WebhookSignatureService(config);
```

To compute expected signatures in tests, use the same algorithm:

```csharp
using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes("test-secret"));
var hash = hmac.ComputeHash(
    Encoding.UTF8.GetBytes($"{timestamp}.{body}"));
var expectedSig = Convert.ToHexStringLower(hash);
```

### T005 Details

Create `api/Services/IWebhookSignatureService.cs`:

```csharp
// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

namespace Api.Services;

public interface IWebhookSignatureService
{
    bool VerifySignature(string? signatureHeader, string requestBody);
}
```

The interface accepts a nullable `signatureHeader` so the function does
not need to check for null before calling the service. The service
returns `false` for null/empty headers.

See data-model.md `IWebhookSignatureService` section for the interface
specification.

### T006 Details

Create `api/Services/WebhookSignatureService.cs` implementing
`IWebhookSignatureService`.

**Constructor**:

```csharp
public WebhookSignatureService(IConfiguration configuration)
{
    _secret = configuration["CLOUDFLARE_WEBHOOK_SIGNING_SECRET"]
        ?? throw new InvalidOperationException(
            "Required configuration setting "
            + "'CLOUDFLARE_WEBHOOK_SIGNING_SECRET' is missing.");
}
```

Fail-closed per FR-011: if the signing secret is not configured, the
constructor throws and the Function App will not start.

**VerifySignature Algorithm** (from R-001 in research.md):

1. Return `false` if `signatureHeader` is null or empty
2. Return `false` if `requestBody` is empty
3. Parse header: split on `,`, extract `time` and `sig1` values
4. Return `false` if either `time` or `sig1` is missing
5. Build source string: `$"{time}.{requestBody}"`
6. Compute HMAC-SHA256: `new HMACSHA256(Encoding.UTF8.GetBytes(_secret))`
7. Hex-encode: `Convert.ToHexStringLower(hash)`
8. Constant-time comparison:
   `CryptographicOperations.FixedTimeEquals(expected, actual)`

Use `CryptographicOperations.FixedTimeEquals` to prevent timing attacks
(FR-002, SC-002). Never use `==` or `string.Equals` for signature
comparison.

This task should make all T004 tests pass (GREEN).

**Checkpoint**: Signature verification service is complete and fully
tested. All T004 tests pass. The service correctly verifies valid
signatures, rejects invalid/missing/malformed signatures, and
fails closed when the secret is not configured.

---

## Phase 4: US-1 — Receive Cloudflare Webhook Notification (P1) 🎯 MVP

**Goal**: When Cloudflare Stream finishes processing a video, it sends
an HTTP POST webhook notification. The system receives the request,
verifies the signature, parses the payload, logs the notification
details (video UID, status, metadata), and returns an appropriate HTTP
response.

**Independent Test**: Send a properly signed HTTP POST request to
`/api/webhooks/cloudflare/stream` with a Cloudflare Stream webhook
payload. Verify the endpoint returns HTTP 200 and logs the video UID and
processing status. Send unsigned or tampered requests and verify HTTP
401. Send empty or malformed body and verify HTTP 400.

### Tests for US-1

- [ ] T007 [US1] Write webhook function tests in `api/Api.Tests/Functions/CloudflareWebhookTests.cs`

### Implementation for US-1

- [ ] T008 [P] [US1] Create webhook payload model in `api/Models/CloudflareWebhookPayload.cs`
- [ ] T009 [US1] Implement webhook function in `api/Functions/CloudflareWebhook.cs`
- [ ] T010 [US1] Register WebhookSignatureService in `api/Program.cs`

### T007 Details

Create `api/Api.Tests/Functions/CloudflareWebhookTests.cs` with xUnit
tests for the `CloudflareWebhook` function. Tests are written FIRST
(TDD — RED phase). Create a minimal stub for `CloudflareWebhook` so
tests compile but fail.

Mock `IWebhookSignatureService` and `ILogger<CloudflareWebhook>` using
Moq:

```csharp
var mockSignatureService = new Mock<IWebhookSignatureService>();
var mockLogger = new Mock<ILogger<CloudflareWebhook>>();
var function = new CloudflareWebhook(
    mockLogger.Object,
    mockSignatureService.Object);
```

**Test Cases**:

- **Valid signature, success notification**: Mock
  `VerifySignature` → `true`. Send request with success payload
  (`readyToStream: true`, `state: "ready"`). Assert HTTP 200. Verify
  logger was called with video UID and ready status (FR-004, FR-005,
  FR-007).
- **Valid signature, error notification**: Mock
  `VerifySignature` → `true`. Send request with error payload
  (`readyToStream: false`, `state: "error"`,
  `errorReasonCode: "ERR_NON_VIDEO"`). Assert HTTP 200. Verify logger
  was called with video UID, error state, and error reason code
  (FR-004, FR-007).
- **Missing signature header**: Mock `VerifySignature` → `false`.
  Send request without `Webhook-Signature` header. Assert HTTP 401
  (FR-003, SC-002).
- **Invalid signature**: Mock `VerifySignature` → `false`. Send
  request with invalid signature header. Assert HTTP 401 (FR-003,
  SC-002).
- **Empty request body**: Send request with empty body. Assert HTTP 400
  (FR-006).
- **Malformed JSON body**: Send request with `"not json"` body and
  valid signature. Assert HTTP 400 (FR-006).
- **Missing UID in payload**: Send valid JSON with `uid: null`. Mock
  `VerifySignature` → `true`. Assert HTTP 200 (accept gracefully per
  FR-010, log warning).
- **Duplicate notification**: Send the same valid request twice. Mock
  `VerifySignature` → `true`. Assert both return HTTP 200 (FR-010).
- **Rejected request logging**: Verify that rejected requests (401,
  400) log sufficient detail for troubleshooting without exposing the
  signing secret (FR-008, SC-006).

Use `DefaultHttpContext` to create mock `HttpRequest` objects:

```csharp
var context = new DefaultHttpContext();
var request = context.Request;
request.Method = "POST";
request.ContentType = "application/json";
request.Headers["Webhook-Signature"] = "time=123,sig1=abc";
request.Body = new MemoryStream(
    Encoding.UTF8.GetBytes(jsonBody));
```

### T008 Details

Create `api/Models/CloudflareWebhookPayload.cs` containing two record
types based on data-model.md:

**CloudflareWebhookPayload**:

```csharp
public record CloudflareWebhookPayload(
    [property: JsonPropertyName("uid")] string? Uid,
    [property: JsonPropertyName("readyToStream")] bool ReadyToStream,
    [property: JsonPropertyName("status")] CloudflareStreamStatus? Status,
    [property: JsonPropertyName("meta")] Dictionary<string, object>? Meta,
    [property: JsonPropertyName("duration")] double? Duration,
    [property: JsonPropertyName("input")] CloudflareVideoInput? Input,
    [property: JsonPropertyName("playback")] CloudflarePlayback? Playback,
    [property: JsonPropertyName("thumbnail")] string? Thumbnail,
    [property: JsonPropertyName("created")] string? Created,
    [property: JsonPropertyName("modified")] string? Modified,
    [property: JsonPropertyName("size")] long? Size,
    [property: JsonPropertyName("preview")] string? Preview);
```

**CloudflareVideoInput**:

```csharp
public record CloudflareVideoInput(
    [property: JsonPropertyName("width")] int? Width,
    [property: JsonPropertyName("height")] int? Height);
```

This model reuses `CloudflareStreamStatus` and `CloudflarePlayback`
from the existing `CloudflareStreamResponse.cs` — do NOT duplicate
those records. Add the appropriate `using` statement if needed.

See data-model.md for field descriptions and contracts/cloudflare-webhook.md
for example JSON payloads.

This task is marked `[P]` because it has no dependency on T007 (tests
use inline JSON, not the model directly) and can be implemented in
parallel.

### T009 Details

Create `api/Functions/CloudflareWebhook.cs` — the HTTP POST-triggered
Azure Function that receives Cloudflare Stream webhook notifications.

**Function Skeleton**:

```csharp
public class CloudflareWebhook(
    ILogger<CloudflareWebhook> logger,
    IWebhookSignatureService signatureService)
{
    [Function(nameof(CloudflareWebhook))]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post",
            Route = "webhooks/cloudflare/stream")]
        HttpRequest request)
    {
        // Implementation
    }
}
```

**Processing Flow**:

1. **Read raw body**: `await new StreamReader(request.Body).ReadToEndAsync()`
   — must read the raw body BEFORE any JSON deserialization for signature
   verification (every byte must remain unaltered).
2. **Validate body not empty**: If body is null or whitespace, return
   `BadRequestObjectResult` with `ErrorResponse("Request body is required")`
   and log warning (FR-006, FR-008).
3. **Get signature header**: `request.Headers["Webhook-Signature"].ToString()`
4. **Verify signature**: Call `signatureService.VerifySignature(signatureHeader, body)`.
   If `false`:
   - Log warning with detail about missing vs. invalid signature
     (FR-008, SC-006) — do NOT log the signing secret or the expected
     signature value
   - Return `UnauthorizedObjectResult` with appropriate error message
     (FR-003)
5. **Deserialize payload**: `JsonSerializer.Deserialize<CloudflareWebhookPayload>(body)`.
   If deserialization fails (returns null or throws `JsonException`):
   - Log warning (FR-008)
   - Return `BadRequestObjectResult` with `ErrorResponse("Invalid JSON payload")`
     (FR-006)
6. **Log notification details** using structured logging (FR-007):
   - If `ReadyToStream` is `true`:
     ```csharp
     logger.LogInformation(
         "Video {VideoUid} is ready to stream. "
         + "Duration={Duration}s, Size={Size}",
         payload.Uid, payload.Duration, payload.Size);
     ```
   - If `ReadyToStream` is `false` and status state is `"error"`:
     ```csharp
     logger.LogWarning(
         "Video {VideoUid} processing failed. "
         + "ErrorCode={ErrorCode}, ErrorText={ErrorText}",
         payload.Uid,
         payload.Status?.ErrorReasonCode,
         payload.Status?.ErrorReasonText);
     ```
   - Log metadata if present (`meta.blobpath`, `meta.filename`)
7. **Return HTTP 200**: `OkResult()` to acknowledge receipt (FR-005).

Use the existing `ErrorResponse` model from `api/Models/ErrorResponse.cs`
for error response bodies. Follow the same constructor DI and structured
logging patterns established in `ProcessVideo.cs`.

See contracts/cloudflare-webhook.md for the endpoint specification and
R-003 in research.md for HTTP trigger details and response codes.

This task should make all T007 tests pass (GREEN).

### T010 Details

Modify `api/Program.cs` to register `WebhookSignatureService`:

```csharp
services.AddSingleton<IWebhookSignatureService, WebhookSignatureService>();
```

Add this line inside the existing `.ConfigureServices(services => { ... })`
block, alongside the other service registrations.

Singleton lifetime is appropriate because the signing secret is read
once from configuration in the constructor and cached for the lifetime
of the application.

**Checkpoint**: US-1 is fully functional. The webhook endpoint receives
Cloudflare notifications, verifies signatures, parses payloads, logs
notification details, and returns appropriate HTTP responses. All unit
tests pass.

---

## Phase 5: Polish & Cross-Cutting Concerns

> Final validation, documentation, and cleanup.

- [ ] T011 [P] Run quickstart.md local validation (build, curl tests, unit tests)
- [ ] T012 [P] Verify all functional requirements are addressed

### T011 Details

Follow quickstart.md to validate the complete implementation locally:

1. Configure `CLOUDFLARE_WEBHOOK_SIGNING_SECRET` in
   `local.settings.json` (section 1)
2. Build and run: `cd api && dotnet build && func start` (section 2)
3. Test valid signature with success payload using the bash script
   (section 3) — expect HTTP 200
4. Test error notification payload (section 4) — expect HTTP 200 with
   failure logged
5. Test missing signature (section 5) — expect HTTP 401
6. Test invalid signature (section 6) — expect HTTP 401
7. Test empty body (section 7) — expect HTTP 400
8. Run all unit tests: `cd api/Api.Tests && dotnet test` (section 8)
   — all tests pass

All eight quickstart steps must succeed.

### T012 Details

Verify every functional requirement from spec.md is addressed by at
least one task:

| Requirement | Task(s) | Verification |
|-------------|---------|-------------|
| FR-001: HTTP POST endpoint | T009 | Function route `webhooks/cloudflare/stream`, POST only |
| FR-002: Signature verification | T005, T006 | `IWebhookSignatureService.VerifySignature()` |
| FR-003: Reject invalid signatures | T006, T009 | 401 Unauthorized response |
| FR-004: Parse JSON payload | T008, T009 | `CloudflareWebhookPayload` model, `JsonSerializer.Deserialize` |
| FR-005: Return success response | T009 | HTTP 200 OK |
| FR-006: Bad request for malformed body | T009 | HTTP 400 for empty/invalid JSON |
| FR-007: Log accepted notifications | T009 | Structured logging of UID, status, metadata |
| FR-008: Log rejected requests | T009 | Warning logs for 401/400 responses |
| FR-009: Secure secret storage | T002, T003 | Key Vault secret + app setting reference |
| FR-010: Handle duplicates gracefully | T009 | Stateless endpoint — duplicates are idempotent |
| FR-011: Fail closed on missing secret | T006 | Constructor throws `InvalidOperationException` |

All 11 functional requirements are covered.

---

## Dependencies

```
T001 (Setup)
  │
  ├──▶ T002 [P] Infrastructure: Key Vault secret
  ├──▶ T003 [P] Infrastructure: App setting
  │
  └──▶ T004 (US-2 Tests)
         │
         ├──▶ T005 (US-2 Interface)
         └──▶ T006 (US-2 Implementation) ──depends on──▶ T005
                │
                └──▶ T007 (US-1 Tests)
                       │
                       ├──▶ T008 [P] (US-1 Model) ──no dependency on T007
                       ├──▶ T009 (US-1 Function) ──depends on──▶ T006, T008
                       └──▶ T010 (US-1 DI Registration) ──depends on──▶ T006
                              │
                              └──▶ T011 [P], T012 [P] (Polish)
```

## Parallel Execution Opportunities

**Phase 2**: T002 and T003 can be implemented in parallel (different
Bicep files, no dependencies).

**Phase 4**: T008 (model) can be implemented in parallel with T007
(tests) since the tests use raw JSON strings, not the model type.

**Phase 5**: T011 and T012 can be executed in parallel (independent
validation activities).

## Implementation Strategy

**MVP**: Phases 1–4 (T001–T010). After completing Phase 4, the
webhook endpoint is fully operational — it receives Cloudflare
notifications, verifies signatures, parses payloads, and logs results.

**Incremental Delivery**:

1. **Phase 1**: Verify clean build (1 task)
2. **Phase 2**: Infrastructure configuration (2 tasks)
3. **Phase 3**: Signature verification with full test coverage (3 tasks)
4. **Phase 4**: Webhook function with full test coverage (4 tasks)
5. **Phase 5**: Validation and verification (2 tasks)

Each phase produces a testable increment. Phase 3 can be validated
independently with unit tests before building the HTTP function in
Phase 4.

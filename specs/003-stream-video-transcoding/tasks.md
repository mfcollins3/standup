# Tasks: Stream Video Transcoding via Cloudflare Stream

**Generated**: 2026-03-23
**Feature Spec**: [spec.md](spec.md)
**Implementation Plan**: [plan.md](plan.md)
**Data Model**: [data-model.md](data-model.md)
**API Contracts**: [contracts/cloudflare-stream-api.md](contracts/cloudflare-stream-api.md), [contracts/event-grid-trigger.md](contracts/event-grid-trigger.md)
**Research**: [research.md](research.md)
**Quickstart**: [quickstart.md](quickstart.md)

---

## Phase 1: Setup

> Add the Event Grid trigger extension package to the Azure Functions project.

- [x] T001 Add EventGrid trigger package to `api/Api.csproj`

### T001 Details

Add `Microsoft.Azure.Functions.Worker.Extensions.EventGrid` version 3.6.0 to `api/Api.csproj`.

This is the .NET isolated worker extension for Event Grid triggers. Do NOT use `Microsoft.Azure.WebJobs.Extensions.EventGrid` (in-process model only).

See R-001 in research.md for package selection rationale.

---

## Phase 2: Foundational — Infrastructure (BLOCKS all user stories)

> Deploy Azure infrastructure changes required before any function code can
> operate: Event Grid event delivery, Cloudflare credential storage, and
> application configuration. All user stories depend on this phase.

- [x] T002 [P] Create Event Grid Bicep module in `infra/modules/event-grid.bicep`
- [x] T003 [P] Modify Key Vault module to add Cloudflare secrets in `infra/modules/key-vault.bicep`
- [x] T004 [P] Modify Function App module to add Cloudflare app settings in `infra/modules/function-app.bicep`
- [x] T005 [P] Remove commented-out Event Grid resources from `infra/modules/storage.bicep`
- [x] T006 Wire Event Grid module and enableEventGrid parameter in `infra/main.bicep`

### T002 Details

Create `infra/modules/event-grid.bicep` as a new module (per R-003 in research.md).

Resources:

- **System Topic** (`Microsoft.EventGrid/systemTopics`): Source type
  `Microsoft.Storage.StorageAccounts`, linked to the storage account.
- **Event Subscription** (`Microsoft.EventGrid/systemTopics/eventSubscriptions`):
  - Filter: `Microsoft.Storage.BlobCreated` events only
  - Subject begins with:
    `/blobServices/default/containers/status-videos/blobs/uploads/`
  - Webhook endpoint:
    `https://{functionAppHostName}/runtime/webhooks/eventgrid?functionName=ProcessVideo&code={systemKey}`
  - System key: obtained via
    `listKeys('${functionAppId}/host/default', '2024-04-01').systemKeys.eventgrid_extension`
  - Retry policy: `maxDeliveryAttempts` = 30,
    `eventTimeToLiveInMinutes` = 1440
  - Dead-letter: blob container `status-videos`, prefix `deadletter/`

Parameters: `name` (string), `location` (string), `tags` (object),
`storageAccountId` (string), `storageAccountName` (string),
`functionAppId` (string), `functionAppHostName` (string),
`enableEventGrid` (bool, default: false).

All resources conditionally deployed: `if (enableEventGrid)`.

See contracts/event-grid-trigger.md for subscription configuration and
R-003 for deployment ordering rationale (Event Grid must be in its own
module to avoid circular dependencies with storage.bicep).

### T003 Details

Modify `infra/modules/key-vault.bicep` to add two new secrets:

- `CloudflareApiToken`: Cloudflare API token with Stream Write
  permission (parameter with `@secure()` decorator)
- `CloudflareAccountId`: Cloudflare account identifier

Grant the Function App managed identity `Key Vault Secrets User` role
for these secrets (if not already granted at the vault level).

### T004 Details

Modify `infra/modules/function-app.bicep` to add application settings
that reference Key Vault secrets:

- `CLOUDFLARE_ACCOUNT_ID`:
  `@Microsoft.KeyVault(VaultName={vaultName};SecretName=CloudflareAccountId)`
- `CLOUDFLARE_API_TOKEN`:
  `@Microsoft.KeyVault(VaultName={vaultName};SecretName=CloudflareApiToken)`

Add a new parameter `keyVaultName` (string) to receive the Key Vault
name from the orchestrator.

See quickstart.md section 1 for local development equivalents in
`local.settings.json`.

### T005 Details

Remove the commented-out Event Grid system topic and event subscription
resources from `infra/modules/storage.bicep`. These resources have been
extracted into the dedicated `infra/modules/event-grid.bicep` module
(T002) to resolve the deployment ordering issue described in R-003.

No new resources are added to this file — just cleanup.

### T006 Details

Modify `infra/main.bicep`:

1. Add parameter: `enableEventGrid` (bool, default: false) with
   description explaining the two-pass bootstrap requirement
2. Add the `event-grid` module reference:
   - Depends on: `storage` module and `functionApp` module
   - Pass required parameters: storage account ID/name, Function App
     ID/hostname, enableEventGrid flag
3. Update module dependency order:
   ```
   monitoring → (no deps)
   storage → (no deps)
   functionApp → storage, monitoring
   eventGrid → storage, functionApp      ← NEW
   keyVault → functionApp
   apim → functionApp
   ```
4. Pass `keyVaultName` output from keyVault module to functionApp
   module for Key Vault reference app settings (T004)

See R-003 for the two-pass bootstrap strategy and quickstart.md
section 6 for deployment commands.

**Checkpoint**: Infrastructure is ready. All Bicep modules can be
deployed (with `enableEventGrid=false` for first deployment). Proceed
to user story implementation.

---

## Phase 3: US-4 — Enable Event Grid Infrastructure (P1)

**Goal**: Deploy Event Grid system topic and event subscription so that
blob upload events are reliably delivered to the processing function
endpoint.

**Independent Test**: Deploy updated infrastructure, upload a blob to
`status-videos/uploads/`, verify the Event Grid event is delivered to
the function endpoint. Deployment completes without errors in all
environments.

### Implementation for US-4

- [x] T007 [US4] Execute two-pass bootstrap deployment for Event Grid infrastructure

### T007 Details

Deploy the infrastructure using the two-pass bootstrap strategy from
R-003 and quickstart.md section 6:

1. **First pass** — deploy with `enableEventGrid=false`:
   ```bash
   azd provision
   ```
   This deploys all resources except the Event Grid subscription. The
   Function App must exist and have code deployed before the Event Grid
   subscription can be created (webhook validation handshake).

2. **Deploy function code**:
   ```bash
   azd deploy
   ```
   The Functions runtime starts, loads the EventGrid extension, and
   creates the `eventgrid_extension` system key.

3. **Second pass** — deploy with `enableEventGrid=true`:
   ```bash
   azd provision --parameter enableEventGrid=true
   ```
   The Event Grid subscription is created with a valid webhook URL
   containing the system key. The webhook validation handshake succeeds
   because the Function App is running.

Verify (FR-012, FR-013, FR-014, FR-015, FR-016, SC-007):

- Event Grid system topic exists on the storage account
- Event subscription filters to `uploads/` prefix in `status-videos`
- Webhook endpoint URL is valid and reachable
- Retry policy: 30 attempts, 1440 min TTL
- Dead-letter destination: `status-videos/deadletter/`
- Deployment completed without errors

**Checkpoint**: Event Grid infrastructure is live. BlobCreated events
in the `uploads/` path will be delivered to the ProcessVideo function
endpoint.

---

## Phase 4: US-1 — Automatically Transcode Uploaded Video (P1) 🎯 MVP

**Goal**: When a video blob is created in `status-videos/uploads/`, the
system detects the event, generates a read SAS URL, and submits it to
Cloudflare Stream for transcoding.

**Independent Test**: Upload a video to the `status-videos/uploads/`
path, verify the Event Grid trigger fires, a read SAS URL is generated,
and the video is submitted to Cloudflare Stream. Cloudflare returns a
video UID and begins processing.

### Tests for US-1 ⚠️

> **NOTE: Write these tests FIRST. Create minimal model/interface stubs
> to allow compilation, then write test cases. Tests should FAIL until
> ProcessVideo is implemented in T015.**

- [x] T008 [US1] Write unit tests for ProcessVideo function in `api/Api.Tests/Functions/ProcessVideoTests.cs`

### Implementation for US-1

- [x] T009 [P] [US1] Create CloudflareStreamRequest model in `api/Models/CloudflareStreamRequest.cs`
- [x] T010 [P] [US1] Create CloudflareStreamResponse models in `api/Models/CloudflareStreamResponse.cs`
- [x] T011 [P] [US1] Extend ISasUrlService with read SAS method in `api/Services/ISasUrlService.cs`
- [x] T012 [US1] Create ICloudflareStreamService interface in `api/Services/ICloudflareStreamService.cs`
- [x] T013 [P] [US1] Implement read SAS URL generation in `api/Services/SasUrlService.cs`
- [x] T014 [US1] Implement CloudflareStreamService in `api/Services/CloudflareStreamService.cs`
- [x] T015 [US1] Create ProcessVideo Event Grid trigger function in `api/Functions/ProcessVideo.cs`
- [x] T016 [US1] Register services and configure HttpClient in `api/Program.cs`

### T008 Details

Write xUnit tests for the ProcessVideo function BEFORE implementation
(TDD). Mock `ISasUrlService` and `ICloudflareStreamService` using Moq.

As a first step, create minimal interface and model stubs so the test
file compiles:

- `ICloudflareStreamService` with `SubmitForTranscodingAsync` signature
- `CloudflareStreamResponse` and `CloudflareStreamRequest` as empty records
- `ISasUrlService.GenerateReadSasUrlAsync` method signature

Then write these test cases (all should fail — RED):

- **Valid video**: BlobCreated event with `video/mp4` content type and
  valid size → generates read SAS URL → submits to Cloudflare → succeeds
- **Valid QuickTime video**: Event with `video/quicktime` → processes
  normally
- **Unsupported content type**: Event with `text/plain` or `image/png`
  → acknowledged without submission, logs skip
- **Zero-size blob**: Event with `contentLength` = 0 → acknowledged
  without submission
- **Oversized blob**: Event with `contentLength` > 52,428,800 (50 MB)
  → acknowledged without submission
- **Wrong path prefix**: Blob URL not under `uploads/` → acknowledged
  without submission
- **Duplicate event (idempotency)**: Same eTag delivered twice → second
  event does not trigger duplicate Cloudflare submission
- **SAS URL generation**: Verify `GenerateReadSasUrlAsync` is called
  with correct blob path
- **Cloudflare submission**: Verify `SubmitForTranscodingAsync` is called
  with the generated SAS URL
- **Transient failure**: Cloudflare service throws → exception propagates
  (triggers Event Grid retry)
- **Permanent failure**: Cloudflare service indicates 400 → acknowledged,
  no exception thrown

Mock `EventGridEvent` with `Data` containing serialized
`StorageBlobCreatedEventData` JSON. See R-001 for event schema.

### T009 Details

Create `api/Models/CloudflareStreamRequest.cs` with JSON serialization:

```csharp
public record CloudflareStreamRequest(
    [property: JsonPropertyName("url")] string Url,
    [property: JsonPropertyName("meta")] Dictionary<string, string>? Meta = null,
    [property: JsonPropertyName("requireSignedURLs")] bool? RequireSignedURLs = null
);
```

See data-model.md `CloudflareStreamRequest` entity for field definitions.

### T010 Details

Create `api/Models/CloudflareStreamResponse.cs` with all Cloudflare v4
API envelope types as records:

- `CloudflareStreamResponse` — top-level: `Success` (bool), `Result`
  (`CloudflareStreamResult?`), `Errors` (`List<CloudflareError>`),
  `Messages` (`List<CloudflareMessage>`)
- `CloudflareStreamResult` — `Uid` (string), `ReadyToStream` (bool),
  `Status` (`CloudflareStatus`), `Playback` (`CloudflarePlayback?`)
- `CloudflareStatus` — `State` (string), `PctComplete` (string?),
  `ErrorReasonCode` (string?), `ErrorReasonText` (string?)
- `CloudflarePlayback` — `Hls` (string?), `Dash` (string?)
- `CloudflareError` — `Code` (int), `Message` (string)
- `CloudflareMessage` — `Code` (int), `Message` (string)

All properties should use `[JsonPropertyName]` attributes for camelCase
JSON mapping.

See data-model.md for complete field definitions and
contracts/cloudflare-stream-api.md for response examples.

### T011 Details

Extend the existing `ISasUrlService` interface with a new method:

```csharp
Task<SasUrlResult> GenerateReadSasUrlAsync(
    string blobPath,
    CancellationToken cancellationToken = default);
```

This method generates a read-only SAS URL for an existing blob. The
existing `GenerateSasUrlAsync` method (write+create) remains unchanged.

See R-004 in research.md for design rationale.

### T012 Details

Create `api/Services/ICloudflareStreamService.cs`:

```csharp
public interface ICloudflareStreamService
{
    Task<CloudflareStreamResponse> SubmitForTranscodingAsync(
        Uri videoReadUrl,
        string blobPath,
        CancellationToken cancellationToken = default);
}
```

The method accepts the read SAS URL and blob path (for metadata tracing),
returns the Cloudflare response with the video UID.

Depends on T009 and T010 (model types used in the interface signature).

### T013 Details

Implement `GenerateReadSasUrlAsync` in `api/Services/SasUrlService.cs`:

- Follow the same user delegation key pattern as the existing
  `GenerateSasUrlAsync` method
- Use `BlobSasPermissions.Read` (not Write+Create)
- Set expiry to 60 minutes (per FR-003)
- Scope to the specific blob path
- Protocol: `SasProtocol.Https` only
- Return `SasUrlResult` with the generated URI and expiration timestamp

See R-004 in research.md for implementation approach. The existing
`BlobServiceClient` registration is reused — no additional DI changes.

### T014 Details

Implement `api/Services/CloudflareStreamService.cs`:

- Accept `HttpClient` via constructor (typed HttpClient pattern for DI)
- Read `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` from
  `IConfiguration`
- `SubmitForTranscodingAsync` implementation:
  1. Build `CloudflareStreamRequest` with the SAS URL and metadata
     (`blobPath` in `meta` dictionary)
  2. Set `Authorization: Bearer {apiToken}` header
  3. POST to `accounts/{account_id}/stream/copy`
  4. Deserialize response as `CloudflareStreamResponse`
  5. On success (`response.Success == true`): return response
  6. On HTTP 429 (rate limit): throw to trigger Event Grid retry
  7. On HTTP 5xx: throw to trigger Event Grid retry
  8. On HTTP 400/401: throw specific exception indicating permanent
     failure (caller decides whether to acknowledge or rethrow)

See contracts/cloudflare-stream-api.md for request/response schemas
and error codes (10000, 10001, 10004, 10005).
See R-002 for rate limit details (120 concurrent, ~1200 req/5 min).

### T015 Details

Create `api/Functions/ProcessVideo.cs` — Event Grid triggered function:

```csharp
[Function(nameof(ProcessVideo))]
public async Task Run(
    [EventGridTrigger] EventGridEvent eventGridEvent)
```

Constructor DI: `ILogger<ProcessVideo>`, `ISasUrlService`,
`ICloudflareStreamService`.

Implementation flow (see contracts/event-grid-trigger.md and
data-model.md event flow diagram):

1. Deserialize event data:
   `eventGridEvent.Data.ToObjectFromJson<StorageBlobCreatedEventData>()`
   (R-001)
2. Parse blob path from `blobData.Url` — extract relative path after
   the container name
3. **Validate path prefix**: Must start with `uploads/` (FR-013). If
   not, log and return (acknowledge).
4. **Validate content type**: Must be `video/mp4` or `video/quicktime`
   (FR-010). If not, log skip and return.
5. **Validate size**: `contentLength > 0` and
   `contentLength <= 52_428_800` (50 MB). If invalid, log and return.
6. **Idempotency check**: Use `blobData.ETag` to detect duplicate
   events (FR-008). Log and return if already processed.
7. **Generate read SAS URL**: Call
   `ISasUrlService.GenerateReadSasUrlAsync(blobPath)` (FR-002, FR-003)
8. **Submit to Cloudflare**: Call
   `ICloudflareStreamService.SubmitForTranscodingAsync(sasUrl, blobPath)`
   (FR-004, FR-005)
9. **Log success**: Log blob path and Cloudflare video UID
   (FR-009, FR-011)
10. **Error handling**: Transient errors throw to trigger Event Grid
    retry (FR-007). Permanent errors log and return.

This task should make all T008 tests pass (GREEN).

### T016 Details

Modify `api/Program.cs` to register new services:

1. Register `ICloudflareStreamService` / `CloudflareStreamService`
   with a typed `HttpClient`:
   ```csharp
   builder.Services
       .AddHttpClient<ICloudflareStreamService, CloudflareStreamService>(
           client =>
           {
               client.BaseAddress = new Uri(
                   "https://api.cloudflare.com/client/v4/");
           });
   ```
2. Verify `ISasUrlService` / `SasUrlService` registration already
   exists (from Feature 002). No changes needed if already registered.

**Checkpoint**: US-1 is fully functional. Uploading a video to
`status-videos/uploads/` triggers the Event Grid function, generates
a read SAS URL, and submits it to Cloudflare Stream. All unit tests
pass.

---

## Phase 5: US-2 — Recover from Transcoding Submission Failure (P1)

**Goal**: Transient failures submitting to Cloudflare Stream are
automatically retried via Event Grid retry policy. Permanent failures
are logged and acknowledged. Events exhausting all retries are
dead-lettered.

**Independent Test**: Simulate a transient Cloudflare failure (5xx),
verify the function throws an exception, Event Grid retries delivery,
and the video is eventually submitted. Simulate permanent failure,
verify the event is acknowledged and logged without retry. Verify
dead-letter delivery after max retries.

### Tests for US-2 ⚠️

- [x] T017 [US2] Write failure and retry behavior tests in `api/Api.Tests/Functions/ProcessVideoTests.cs`

### Implementation for US-2

- [x] T018 [US2] Implement error classification in `api/Functions/ProcessVideo.cs`

### T017 Details

Add test cases to `ProcessVideoTests.cs` for failure recovery scenarios:

- **Transient 503**: Cloudflare returns HTTP 503 → function throws
  exception (Event Grid will retry)
- **Transient 429**: Cloudflare returns HTTP 429 (rate limit) →
  function throws exception
- **Transient timeout**: HttpClient throws `TaskCanceledException` →
  function throws (not swallowed)
- **Network failure**: `HttpRequestException` → function throws
- **Permanent 400**: Cloudflare returns 400 (bad request) → function
  logs error and returns normally (acknowledged, no retry)
- **Permanent 401**: Cloudflare returns 401 (invalid auth) → function
  logs error and returns normally
- **SAS URL generation failure**: `ISasUrlService` throws → function
  throws (triggers retry — storage may be transiently unavailable)
- **Comprehensive logging**: Verify failure logs include blob path,
  content type, content length, error details, and failure classification
  (FR-009, SC-006)

### T018 Details

Refine error handling in `ProcessVideo.cs` to classify errors:

**Transient (throw → Event Grid retries)**:

- HTTP 429 (rate limit exceeded)
- HTTP 5xx (server error)
- `HttpRequestException` (network failure)
- `TaskCanceledException` (timeout)
- SAS URL generation failures

**Permanent (acknowledge → no retry)**:

- HTTP 400 with Cloudflare error code 10005 (validation)
- HTTP 401 with Cloudflare error code 10000 (authentication — requires
  operator intervention, not retry)
- Content type validation failure
- Size validation failure

Log all failures with: blob path, content type, content length,
error details, and classification (transient vs. permanent).

If T015 already includes basic error handling, this task refines the
classification and ensures comprehensive structured logging for all
failure paths.

**Checkpoint**: US-2 is complete. Transient Cloudflare failures trigger
Event Grid retries (30 attempts, 1440 min TTL). Permanent failures are
acknowledged and logged. Dead-lettering is configured in the Event Grid
subscription (Phase 2, T002).

---

## Phase 6: US-3 — Track Video Processing Status (P2)

**Goal**: After successful submission to Cloudflare Stream, the system
records the video UID and logs structured information for processing
status tracking by downstream features.

**Independent Test**: Submit a video for transcoding, verify the
Cloudflare video UID is logged and associated with the blob path.
Verify structured logs contain blob path, content type, size, and
video UID and are queryable in Application Insights.

### Implementation for US-3

- [x] T019 [US3] Implement structured logging for processing status in `api/Functions/ProcessVideo.cs`
- [x] T020 [US3] Record Cloudflare video UID on successful submission in `api/Functions/ProcessVideo.cs`

### T019 Details

Enhance structured logging in `ProcessVideo.cs` using
`ILogger<ProcessVideo>`:

Log on each processing stage:

1. **Event received**: Log blob path, content type, content length, eTag
2. **Validation skipped**: Log reason (unsupported content type, invalid
   size, wrong path prefix, duplicate event)
3. **SAS URL generated**: Log blob path, SAS expiry timestamp
4. **Submission success**: Log blob path, Cloudflare video UID, initial
   processing state
5. **Submission failure**: Log blob path, HTTP status code, Cloudflare
   error code/message, failure classification

Use structured log templates with named parameters for Application
Insights queryability:

```csharp
_logger.LogInformation(
    "Video submitted for transcoding. BlobPath={BlobPath}, "
    + "VideoUid={VideoUid}, State={State}",
    blobPath, response.Result?.Uid, response.Result?.Status?.State);
```

Satisfies FR-009 and SC-006.

### T020 Details

After a successful Cloudflare Stream submission in `ProcessVideo.cs`:

1. Extract `result.uid` from the `CloudflareStreamResponse`
2. Log the association: blob path → video UID (FR-011)
3. The video UID is the identifier that downstream features will use
   to check transcoding status and retrieve playback URLs

**Note**: Persistent storage of the blob-path-to-UID mapping is out of
scope for this feature (no database exists yet). The video UID is
captured in structured logs and can be queried via Application Insights.
A future feature may introduce a database for this mapping.

**Checkpoint**: US-3 is complete. All processing events are logged with
structured data. Video UIDs are recorded and queryable.

---

## Phase 7: Polish & Cross-Cutting Concerns

> Final validation, documentation, and cleanup.

- [x] T021 [P] Run quickstart.md local validation (build, curl test, dotnet test)
- [x] T022 [P] Verify all 16 functional requirements are addressed
- [x] T023 Update local.settings.json with Cloudflare development credentials in `api/local.settings.json`

### T021 Details

Follow quickstart.md to validate the complete implementation locally:

1. Add Cloudflare credentials to `local.settings.json` (section 1)
2. Build and run the function app:
   `cd api && dotnet build && func start` (section 2)
3. Send test curl request with BlobCreated event JSON (section 3)
4. Verify unsupported content type is rejected (section 4)
5. Run all unit tests:
   `cd api/Api.Tests && dotnet test` (section 5)

All tests should pass. The local function should process the test event
and log the expected output.

### T022 Details

Cross-reference all 16 functional requirements against implemented tasks:

| FR | Description | Covered By |
|----|-------------|------------|
| FR-001 | Detect BlobCreated events | T002, T015 |
| FR-002 | Generate time-limited read URL | T011, T013 |
| FR-003 | Read URL ~1 hour expiry | T013 |
| FR-004 | Submit to transcoding service | T014, T015 |
| FR-005 | Include auth credentials | T003, T004, T014 |
| FR-006 | Secure credential storage (Key Vault) | T003 |
| FR-007 | Auto-retry transient failures | T002, T018 |
| FR-008 | Idempotent duplicate handling | T015 |
| FR-009 | Structured logging | T019 |
| FR-010 | Validate content type | T015 |
| FR-011 | Record transcoding job ID | T020 |
| FR-012 | Deploy Event Grid system topic | T002 |
| FR-013 | Filter to uploads/ path | T002, T015 |
| FR-014 | Deliver to function endpoint | T002 |
| FR-015 | Retry policy + dead-letter | T002 |
| FR-016 | Deployment succeeds | T007 |

All FRs must have at least one covering task. Flag any gaps.

### T023 Details

Update `api/local.settings.json` to include Cloudflare development
credentials:

```json
{
  "Values": {
    "CLOUDFLARE_ACCOUNT_ID": "<your-account-id>",
    "CLOUDFLARE_API_TOKEN": "<your-api-token>"
  }
}
```

These are local development values only. Production values are stored
in Key Vault (T003).

Ensure `local.settings.json` remains in `.gitignore` to prevent
credential leakage.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US-4 (Phase 3)**: Depends on Phase 2 — infrastructure deployment validation
- **US-1 (Phase 4)**: Depends on Phase 2 — can start in parallel with
  Phase 3 (code development does not require deployed infrastructure)
- **US-2 (Phase 5)**: Depends on Phase 4 — extends ProcessVideo error
  handling
- **US-3 (Phase 6)**: Depends on Phase 4 — extends ProcessVideo logging
- **Polish (Phase 7)**: Depends on all previous phases

### User Story Dependencies

- **US-4 (P1)**: Can start after Foundational — no code dependencies
- **US-1 (P1) 🎯 MVP**: Can start after Foundational — core pipeline,
  no dependencies on US-4 deployment (develop and test locally)
- **US-2 (P1)**: Extends US-1 error handling — depends on US-1
- **US-3 (P2)**: Extends US-1 logging — depends on US-1
- **US-2 and US-3**: Can run in parallel with each other once US-1
  is complete (they modify different concerns in ProcessVideo.cs)

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD)
- Models before service interfaces
- Service interfaces before implementations
- Services before function
- Function before Program.cs registration

### Parallel Opportunities

- **Phase 2**: T002, T003, T004, T005 can all run in parallel (different
  Bicep files, no interdependency). T006 depends on all of them.
- **Phase 4**: T009, T010, T011 can run in parallel (different files)
- **Phase 4**: T013 can run in parallel with T012 (different services)
- **Phase 5 + Phase 6**: US-2 and US-3 can run in parallel after US-1
- **Phase 7**: T021 and T022 can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all independent models and interface extensions together:
Task: "Create CloudflareStreamRequest model in api/Models/CloudflareStreamRequest.cs"
Task: "Create CloudflareStreamResponse models in api/Models/CloudflareStreamResponse.cs"
Task: "Extend ISasUrlService with read SAS method in api/Services/ISasUrlService.cs"

# After models are ready, service work can proceed:
Task: "Implement read SAS in api/Services/SasUrlService.cs"
Task: "Create ICloudflareStreamService interface in api/Services/ICloudflareStreamService.cs"
```

---

## Implementation Strategy

### MVP First (US-4 + US-1)

1. Complete Phase 1: Setup (add EventGrid package)
2. Complete Phase 2: Foundational (all infrastructure Bicep)
3. Complete Phase 3: US-4 (deploy and validate Event Grid)
4. Complete Phase 4: US-1 (core pipeline — models, services, function)
5. **STOP and VALIDATE**: Test US-1 with local curl and unit tests
6. Deploy and verify video transcoding works end-to-end

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. US-4 (deploy) → Events flowing
3. US-1 (core) → Videos transcoded (MVP!)
4. US-2 (retry) → Failures recover automatically
5. US-3 (tracking) → Processing status logged
6. Each story adds reliability and observability without breaking
   previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US-4 (deployment) + US-1 (core pipeline)
   - Developer B: Review infrastructure, prepare test scenarios
3. After US-1 is complete:
   - Developer A: US-2 (failure recovery)
   - Developer B: US-3 (status tracking)
4. Both stories complete independently and integrate cleanly

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps tasks to specific user story for traceability
- Each user story should be independently testable at its checkpoint
- TDD: Write tests FIRST, ensure they FAIL, then implement
- Commit after each task using conventional commits
- Two-pass deployment (`enableEventGrid`): Required for Event Grid
  webhook validation handshake (R-003)
- Idempotency via eTag: Simple in-memory or log-based approach without
  external state store (Constitution VII — Simplicity)
- Local testing: POST to
  `/runtime/webhooks/EventGrid?functionName=ProcessVideo` with
  `aeg-event-type: Notification` header (R-001)

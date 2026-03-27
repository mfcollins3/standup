# Tasks: Signed Video URLs for Secure Streaming

**Input**: Design documents from `/specs/006-signed-video-urls/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Included — TDD is specified in the implementation plan (Constitution Check: "TDD for new `GetSignedStreamUrl` function and `ISignedUrlTokenService`").

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add new NuGet dependency and configuration values needed across all user stories

- [ ] T001 Add `System.IdentityModel.Tokens.Jwt` NuGet package to api/Api.csproj
- [ ] T002 [P] Add `CLOUDFLARE_SIGNING_KEY_ID`, `CLOUDFLARE_SIGNING_KEY_JWK`, and `CLOUDFLARE_CUSTOMER_CODE` entries to api/local.settings.json.example
- [ ] T003 [P] Create `StreamType` enum with `Hls` and `Dash` values in api/Models/StreamType.cs

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core service interface, implementation, and DI registration that MUST be complete before user story functions can be built

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Create `ISignedUrlTokenService` interface in api/Services/ISignedUrlTokenService.cs
- [ ] T005 Create `SignedUrlTokenService` compilable skeleton class (`throw NotImplementedException` for all methods) in api/Services/SignedUrlTokenService.cs — real implementation deferred to T010 to preserve TDD ordering
- [ ] T006 Register `ISignedUrlTokenService` as a singleton in DI in api/Program.cs
- [ ] T007 Create `GetSignedStreamUrlResponse` response record in api/Models/GetSignedStreamUrlResponse.cs

**Checkpoint**: Foundation ready — service layer, models, and DI are in place. User story implementation can now begin.

---

## Phase 3: User Story 1 — Retrieve Signed Streaming URL for a Video (Priority: P1) 🎯 MVP

**Goal**: Expose an API endpoint that accepts a video ID and stream type (HLS or DASH) and returns a time-limited signed streaming URL.

**Independent Test**: Call the API endpoint with a valid video ID and stream type "HLS". Verify the response contains a signed URL with the correct manifest path. Repeat with stream type "DASH" and verify a DASH manifest URL is returned. Verify error responses for missing video, not-ready video, and invalid stream type.

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T008 [P] [US1] Write unit tests for `SignedUrlTokenService` (valid token generation for HLS and DASH, correct JWT claims, correct expiration) in api/Api.Tests/Services/SignedUrlTokenServiceTests.cs
- [ ] T009 [P] [US1] Write unit tests for `GetSignedStreamUrl` function (200 OK with valid video, 404 for missing video, 409 for not-ready video, 400 for invalid stream type, error when video is Ready but `CloudflareVideoUid` is null) in api/Api.Tests/Functions/GetSignedStreamUrlTests.cs

### Implementation for User Story 1

- [ ] T010 [US1] Implement `SignedUrlTokenService.GenerateSignedUrlAsync` — load RSA key from configuration, create RS256 JWT with `sub` (video UID), `kid` (signing key ID), and `exp` (1 hour from now), construct manifest URL with token in api/Services/SignedUrlTokenService.cs. Ensure signing key material is never included in log output (Constitution IV).
- [ ] T011 [US1] Implement `GetSignedStreamUrl` Azure Function — HTTP GET `/video/{videoId}/stream`, parse `streamType` query parameter, look up video in database, validate status is Ready, call `ISignedUrlTokenService`, return `GetSignedStreamUrlResponse` or appropriate error response in api/Functions/GetSignedStreamUrl.cs
- [ ] T012 [US1] Verify all unit tests in T008 and T009 pass

**Checkpoint**: User Story 1 is fully functional. The API endpoint generates signed streaming URLs for ready videos.

---

## Phase 4: User Story 2 — Lock Down Videos to Require Signed URLs on Upload (Priority: P1)

**Goal**: Modify the `ProcessVideo` function to pass `requireSignedURLs: true` when submitting videos to Cloudflare, ensuring all videos are locked down from upload time.

**Independent Test**: Run the existing `ProcessVideo` unit tests and verify the Cloudflare request body includes `requireSignedURLs: true`. Upload a video through the pipeline and verify Cloudflare rejects public URL access.

### Tests for User Story 2 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T013 [US2] Write or update unit tests for `ProcessVideo` to verify `requireSignedURLs: true` is passed in the `CloudflareStreamRequest` when submitting a video for transcoding in api/Api.Tests/Functions/ProcessVideoTests.cs

### Implementation for User Story 2

- [ ] T014 [US2] Modify `CloudflareStreamService.SubmitForTranscodingAsync` to pass `RequireSignedURLs = true` in the `CloudflareStreamRequest` in api/Services/CloudflareStreamService.cs
- [ ] T015 [US2] Verify all unit tests in T013 pass

**Checkpoint**: User Story 2 is complete. All newly uploaded videos require signed URLs for streaming.

---

## Phase 5: User Story 3 — Signed URL Expiration (Priority: P2)

**Goal**: Ensure signed URLs include a limited expiration time (default 1 hour) and that the expiration is communicated to the client in the response.

**Independent Test**: Generate a signed URL and verify the JWT `exp` claim is set to approximately 1 hour from the current time. Verify the `expiresAt` field in the API response matches the token expiration.

### Tests for User Story 3 ⚠️

> **NOTE: These tests should already be covered by T008 and T009 expiration assertions. Add additional tests only if edge cases remain.**

- [ ] T016 [US3] Review and extend `SignedUrlTokenServiceTests` to verify the JWT `exp` claim is set to 1 hour from token creation time and that `expiresAt` in the response is accurate in api/Api.Tests/Services/SignedUrlTokenServiceTests.cs

### Implementation for User Story 3

- [ ] T017 [US3] Review `SignedUrlTokenService` implementation — confirm token expiration is set to 1 hour and `ExpiresAt` is returned accurately in api/Services/SignedUrlTokenService.cs
- [ ] T018 [US3] Verify all unit tests in T016 pass

**Checkpoint**: All three user stories are complete, independently testable, and verified.

---

## Phase 6: Infrastructure as Code

**Purpose**: Bicep updates for Key Vault secrets and APIM operation

- [ ] T019 [P] Add `cloudflareSigningKeyId` and `cloudflareSigningKeyJwk` secure parameters and corresponding Key Vault secret resources in infra/modules/key-vault.bicep
- [ ] T020 [P] Add `getSignedStreamUrl` APIM operation — `GET /video/{videoId}/stream` with `streamType` query parameter, following the existing `createVideoOperation` pattern in infra/modules/api-management.bicep
- [ ] T021 [P] Add `cloudflareSigningKeyId`, `cloudflareSigningKeyJwk`, and `cloudflareCustomerCode` parameters to infra/modules/function-app.bicep and add corresponding app settings using Key Vault references (following the existing `CLOUDFLARE_API_TOKEN` pattern)
- [ ] T022 Add new parameters (`cloudflareSigningKeyId`, `cloudflareSigningKeyJwk`, `cloudflareCustomerCode`) to the main Bicep template and wire them to the key-vault, function-app, and (where needed) other modules in infra/main.bicep and infra/main.bicepparam

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, quickstart validation, and final verification

- [ ] T023 [P] Create ADR for self-signed RS256 JWT token generation approach (documenting R1 decision: local signing over Cloudflare `/token` API) in docs/adrs/005-cloudflare-signed-url-token-generation.md
- [ ] T024 [P] Update quickstart.md with actual API output after end-to-end local testing in specs/006-signed-video-urls/quickstart.md
- [ ] T025 Run all unit tests (`dotnet test`) and verify zero failures
- [ ] T026 Run quickstart.md validation — start the Function App locally, create a video through the pipeline, request signed HLS and DASH URLs, verify responses match the contract

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion
- **User Story 2 (Phase 4)**: Depends on Foundational phase completion — NO dependency on User Story 1
- **User Story 3 (Phase 5)**: Depends on User Story 1 (extends token expiration behavior)
- **Infrastructure (Phase 6)**: Can start after Setup — independent of user story code changes
- **Polish (Phase 7)**: Depends on all user stories and infrastructure being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) — independent of User Story 1. Modifies different files (ProcessVideo/CloudflareStreamService vs. GetSignedStreamUrl/SignedUrlTokenService)
- **User Story 3 (P2)**: Depends on User Story 1 — extends and verifies the token expiration behavior established in US1

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Implementation tasks follow TDD cycle
- Verify tests pass after implementation

### Parallel Opportunities

- T002 and T003 (Setup) can run in parallel
- T008 and T009 (US1 tests) can run in parallel
- User Story 1 and User Story 2 can be worked on in parallel after Phase 2 (different files/services)
- T019, T020, and T021 (Bicep infra) can run in parallel with each other and with user story code changes
- T022 (main.bicep wiring) depends on T019, T020, and T021

---

## Parallel Example: User Story 1

```
# Launch US1 tests in parallel (write FIRST, expect failures):
Task T008: "Unit tests for SignedUrlTokenService in api/Api.Tests/Services/SignedUrlTokenServiceTests.cs"
Task T009: "Unit tests for GetSignedStreamUrl in api/Api.Tests/Functions/GetSignedStreamUrlTests.cs"

# Then implement sequentially:
Task T010: "Implement SignedUrlTokenService.GenerateSignedUrlAsync in api/Services/SignedUrlTokenService.cs"
Task T011: "Implement GetSignedStreamUrl function in api/Functions/GetSignedStreamUrl.cs"
Task T012: "Verify all US1 tests pass"
```
## Parallel Example: User Story 1 + User Story 2 (different developers)

```
# Developer A (US1):                        # Developer B (US2):
T008 — SignedUrlTokenService tests           T013 — ProcessVideo requireSignedURLs test
T009 — GetSignedStreamUrl tests              T014 — Modify CloudflareStreamService
T010 — Implement SignedUrlTokenService       T015 — Verify US2 tests pass
T011 — Implement GetSignedStreamUrl
T012 — Verify US1 tests pass
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1 (signed URL generation endpoint)
4. Complete Phase 4: User Story 2 (lock down videos on upload)
5. **STOP and VALIDATE**: Both stories together form the minimum viable security feature
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Signed URLs can be generated
3. Add User Story 2 → Test independently → Videos are locked down on upload
4. Add User Story 3 → Test independently → Expiration behavior verified
5. Infrastructure (Phase 6) → Deploy to Azure
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (signed URL endpoint)
   - Developer B: User Story 2 (lock down on upload) + Infrastructure (Phase 6)
3. Developer A continues with User Story 3 after US1 is complete
4. Final: Polish phase together

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- TDD: Write tests first, ensure they fail, then implement
- Commit after each task or logical group using Conventional Commits
- `CloudflareStreamRequest` already has `RequireSignedURLs` property — US2 only needs to pass `true`
- No database migration needed — `Video` entity already has all required fields
- Signing key provisioned from Cloudflare `/stream/key` endpoint (manual one-time step, see quickstart.md)

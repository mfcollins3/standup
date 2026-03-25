# Tasks: Video Tracking and Persistence

**Input**: Design documents from `/specs/005-video-tracking-persistence/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: FR-011 requires all new production code to have corresponding automated unit tests. Test tasks are included for all phases.

**Organization**: Tasks are grouped by user story. US2 (Store Cloudflare Playback URLs) and US3 (Placeholder User Identity) are tightly coupled with US1 — their implementation shares code paths in CloudflareWebhook and CreateVideo respectively. Each user story phase has focused tasks and test coverage for its specific acceptance criteria.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add NuGet dependencies and architectural documentation

- [X] T001 Add Npgsql.EntityFrameworkCore.PostgreSQL 10.0.1 and Microsoft.EntityFrameworkCore.Design 10.0.5 packages to api/Api.csproj
- [X] T002 [P] Add Microsoft.EntityFrameworkCore.Sqlite package to api/Api.Tests/Api.Tests.csproj
- [X] T003 [P] Create ADR-004 documenting the PostgreSQL decision in docs/adrs/004-postgresql-video-persistence.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Data model, DbContext, DI registration, migrations, and Azure infrastructure. MUST be complete before any user story work begins.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create VideoStatus enum (Created, Uploaded, Processing, Ready, Failed) in api/Data/VideoStatus.cs
- [X] T005 [P] Create VideoConstants with PlaceholderUserId constant in api/Data/VideoConstants.cs
- [X] T006 Create Video entity with all 17 fields and column name mappings in api/Data/Video.cs
- [X] T007 Create StandupDbContext with Video DbSet and fluent API configuration in api/Data/StandupDbContext.cs
- [X] T008 Register NpgsqlDataSource with Entra token provider and IDbContextFactory in api/Program.cs
- [X] T009 Create initial EF Core migration for Videos table in api/Data/Migrations/
- [X] T010 [P] Create PostgreSQL Flexible Server Bicep module with Entra-only auth in infra/modules/postgresql.bicep
- [X] T011 [P] Add postgreSqlFlexibleServer abbreviation to infra/abbreviations.json
- [X] T012 Update infra/main.bicep to add postgresql module and wire outputs to function-app module
- [X] T013 Update infra/modules/function-app.bicep to add POSTGRESQL_HOST, POSTGRESQL_DATABASE, and POSTGRESQL_USERNAME app settings

**Checkpoint**: Foundation ready — Video entity, DbContext, DI, migrations, and Azure infrastructure all in place. User story implementation can now begin.

---

## Phase 3: User Story 1 — Track Video Lifecycle Status (Priority: P1) 🎯 MVP

**Goal**: Track each video through status transitions (created → processing → ready/failed) across all three Azure Functions, with the video ID round-tripped through Cloudflare's meta dictionary.

**Independent Test**: Create a video via POST /api/video (status=created), simulate BlobCreated event through ProcessVideo (status→processing, Cloudflare UID stored), send a Cloudflare webhook for ready (status→ready) and for failed (status→failed with error details). Verify each status transition and the two-tier webhook lookup (meta.videoId primary, cloudflare_video_uid fallback).

**Note**: US3 (Placeholder User Identity) is co-implemented in T021 — CreateVideo uses VideoConstants.PlaceholderUserId when creating the Video record. US2 (Store Cloudflare Playback URLs) is partially co-implemented in T023 — the ready handler structure is established here, with URL field mapping completed in Phase 4.

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before implementation**

- [X] T014 [P] [US1] Write StandupDbContext configuration tests verifying Video entity mapping, indexes, and status string conversion in api/Api.Tests/Data/StandupDbContextTests.cs
- [X] T015 [P] [US1] Write CreateVideo tests asserting Video record creation with status=created, placeholder user ID, blob path, content type, file size, and videoId in response in api/Api.Tests/Functions/CreateVideoTests.cs
- [X] T016 [P] [US1] Write ProcessVideo tests asserting Video lookup by blob path, status update to processing, Cloudflare UID storage, videoId passed in meta, and edge cases (no matching video, Cloudflare failure) in api/Api.Tests/Functions/ProcessVideoTests.cs
- [X] T017 [P] [US1] Write CloudflareWebhook tests asserting two-tier Video lookup (meta.videoId then cloudflare_video_uid), status→ready transition, status→failed with error details, idempotent duplicate handling, and no-match warning in api/Api.Tests/Functions/CloudflareWebhookTests.cs

### Implementation for User Story 1

- [X] T018 [P] [US1] Add VideoId property to CreateVideoResponse record in api/Models/CreateVideoResponse.cs
- [X] T019 [P] [US1] Add Guid videoId parameter to SubmitForTranscodingAsync in api/Services/ICloudflareStreamService.cs
- [X] T020 [US1] Update SubmitForTranscodingAsync to accept videoId and include it in the Cloudflare meta dictionary alongside blobPath in api/Services/CloudflareStreamService.cs
- [X] T021 [US1] Modify CreateVideo to inject IDbContextFactory, create Video record with status=created and PlaceholderUserId, and return videoId in response in api/Functions/CreateVideo.cs
- [X] T022 [US1] Modify ProcessVideo to inject IDbContextFactory, look up Video by blob path, update status to processing, store Cloudflare video UID, and pass videoId in meta to SubmitForTranscodingAsync in api/Functions/ProcessVideo.cs
- [X] T023 [US1] Modify CloudflareWebhook to inject IDbContextFactory, implement two-tier Video lookup (meta.videoId primary, cloudflare_video_uid fallback), update status to ready or failed with error details, and handle edge cases in api/Functions/CloudflareWebhook.cs

**Checkpoint**: Video status lifecycle fully trackable end-to-end. CreateVideo creates records, ProcessVideo transitions to processing, CloudflareWebhook transitions to ready/failed. All status transitions verified by automated tests.

---

## Phase 4: User Story 2 — Store Cloudflare Playback URLs (Priority: P1)

**Goal**: Persist HLS and DASH streaming URLs, thumbnail URL, video duration, and input dimensions from the Cloudflare webhook payload on the Video record.

**Independent Test**: Send a Cloudflare webhook notification with all playback fields for a video in processing status. Verify the Video record stores HLS URL, DASH URL, thumbnail URL, duration, input width, and input height.

**Note**: The Video entity URL fields are defined in Phase 2 (T006). The CloudflareWebhook ready handler structure is established in T023 (US1). This phase completes the field mapping for playback metadata and adds focused test coverage.

### Tests for User Story 2

- [X] T024 [P] [US2] Write tests asserting HLS URL, DASH URL, thumbnail URL, duration, input width, and input height are persisted from webhook payload in ready handler in api/Api.Tests/Functions/CloudflareWebhookTests.cs

### Implementation for User Story 2

- [X] T025 [US2] Map playback URLs (HLS, DASH), thumbnail URL, duration, and input dimensions from CloudflareWebhookPayload to Video entity fields in the ready handler in api/Functions/CloudflareWebhook.cs

**Checkpoint**: Cloudflare playback URLs, thumbnail, duration, and dimensions persisted on video records. Verified by automated tests asserting each field is stored correctly.

---

## Phase 5: User Story 3 — Placeholder User Identity (Priority: P1)

**Goal**: All video records are assigned the constant placeholder user ID (00000000-0000-0000-0000-000000000001) so the schema includes user ownership from the start.

**Independent Test**: Create multiple video records and verify they all have the same constant placeholder user ID.

**Note**: VideoConstants.PlaceholderUserId is defined in Phase 2 (T005). Its usage in CreateVideo is co-implemented in T021 (US1). This phase adds explicit test coverage for the placeholder identity requirement.

### Tests for User Story 3

- [X] T026 [US3] Write tests asserting all created Video records have UserId set to VideoConstants.PlaceholderUserId in api/Api.Tests/Functions/CreateVideoTests.cs

**Checkpoint**: All video records confirmed to use the placeholder user ID. Schema ready for future authentication integration without migration.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validation, documentation, and final verification

- [X] T027 [P] Verify all unit tests pass with dotnet test in api/
- [X] T028 Run quickstart.md validation steps for local end-to-end verification
- [X] T029 [P] Review documentation and ensure ADR-004 cross-references are complete in docs/adrs/

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (NuGet packages must be installed) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 completion — the core feature implementation
- **US2 (Phase 4)**: Depends on T023 (CloudflareWebhook ready handler structure from US1)
- **US3 (Phase 5)**: Depends on T021 (CreateVideo implementation from US1) — test-only phase
- **Polish (Phase 6)**: Depends on all user story phases being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories. This is the MVP.
- **User Story 2 (P1)**: Depends on US1's CloudflareWebhook implementation (T023) for the ready handler structure. Cannot be fully parallelized with US1.
- **User Story 3 (P1)**: Depends on US1's CreateVideo implementation (T021) for test context. Cannot be fully parallelized with US1.

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models and interfaces before service implementations
- Service changes before function modifications
- CreateVideo before ProcessVideo (ProcessVideo depends on video records existing)
- ProcessVideo before CloudflareWebhook (CloudflareWebhook depends on Cloudflare UID stored by ProcessVideo)

### Critical Path

```
T001 → T004 → T006 → T007 → T008 → T009 → T021 → T022 → T023 → T025 → T027 → T028
```

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel with T001
- **Phase 2**: T010 and T011 can run in parallel with T004–T009 (Bicep and source code are independent)
- **Phase 3 Tests**: T014, T015, T016, T017 can all run in parallel (different test files)
- **Phase 3 Implementation**: T018 and T019 can run in parallel (different files, no dependencies)
- **Phase 4 and Phase 5**: T024 and T026 can run in parallel (different test files, after T023 and T021 respectively)

---

## Parallel Example: Phase 2 (Foundational)

```
# Parallel batch 1 — independent model files:
Task T004: Create VideoStatus enum in api/Data/VideoStatus.cs
Task T005: Create VideoConstants in api/Data/VideoConstants.cs
Task T010: Create postgresql.bicep in infra/modules/postgresql.bicep
Task T011: Add abbreviation to infra/abbreviations.json

# Sequential — depends on T004:
Task T006: Create Video entity in api/Data/Video.cs
Task T007: Create StandupDbContext in api/Data/StandupDbContext.cs
Task T008: Register DI in api/Program.cs
Task T009: Create EF Core migration

# Sequential — depends on T010, T011:
Task T012: Update main.bicep
Task T013: Update function-app.bicep
```

## Parallel Example: Phase 3 (User Story 1)

```
# All tests in parallel (write first, verify they fail):
Task T014: StandupDbContext tests
Task T015: CreateVideo tests
Task T016: ProcessVideo tests
Task T017: CloudflareWebhook tests

# Parallel implementation (independent files):
Task T018: CreateVideoResponse model
Task T019: ICloudflareStreamService interface

# Sequential implementation:
Task T020: CloudflareStreamService (depends on T019)
Task T021: CreateVideo function (depends on T018)
Task T022: ProcessVideo function (depends on T020)
Task T023: CloudflareWebhook function
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (NuGet packages, ADR)
2. Complete Phase 2: Foundational (entity, DbContext, DI, migrations, Bicep)
3. Complete Phase 3: User Story 1 (all status transitions across 3 functions)
4. **STOP and VALIDATE**: Run `dotnet test`, verify status lifecycle works end-to-end
5. Deploy/demo if ready — videos are tracked through their full lifecycle

### Incremental Delivery

1. Setup + Foundational → Data layer and infrastructure ready
2. Add User Story 1 → Status tracking works → Deploy/Demo (**MVP!**)
3. Add User Story 2 → Playback URLs stored → Deploy/Demo
4. Add User Story 3 → Placeholder identity verified → Deploy/Demo
5. Polish → Full validation and documentation

### Parallel Team Strategy

With multiple developers after Phase 2 is complete:

- **Developer A**: User Story 1 (Phase 3) — core status lifecycle
- **Developer B**: Bicep review and local PostgreSQL setup (from quickstart.md)
- After US1 is complete, US2 and US3 can be picked up in parallel by different developers

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- US2 and US3 are tightly coupled with US1's implementation — they share code paths in CloudflareWebhook and CreateVideo
- Test tasks modify existing test files (CreateVideoTests.cs, ProcessVideoTests.cs, CloudflareWebhookTests.cs) — update mocks to accommodate IDbContextFactory dependency and new ICloudflareStreamService signature
- ProcessVideo transitions directly from created → processing (the uploaded status is reserved for a future blob-upload-confirmed event)
- Commit after each task or logical group using Conventional Commits format
- Stop at any checkpoint to validate independently

# Tasks: Video Playback Screen

**Input**: Design documents from `specs/007-video-playback-screen/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Required per Constitution Principle II (Keep Quality High).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Create the `Playback/` feature directory to house the new playback screen source files.

- [X] T001 Create `Playback/` directory at `Apple/Projects/Standup/Sources/Playback/`

---

## Phase 2: User Story 1 - Watch a Status Report Video (Priority: P1) MVP

**Goal**: Add a "Play Status Report" navigation link to the main screen and implement a dedicated video playback screen that streams an HLS video with standard playback controls and proper lifecycle cleanup.

**Independent Test**: Tap "Play Status Report" on main screen, verify the video player loads, video plays with controls (play, pause, scrub), and navigating back stops playback and returns to a functional main screen.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T002 [P] [US1] Write test that VideoPlaybackScreen initializes AVPlayer with the provided URL in `Apple/Projects/Standup/Tests/Playback/VideoPlaybackScreenTests.swift`

### Implementation for User Story 1

- [X] T004 [US1] Create VideoPlaybackScreen view with AVKit VideoPlayer, loading indicator, auto-play on appear, and `.onDisappear` cleanup in `Apple/Projects/Standup/Sources/Playback/VideoPlaybackScreen.swift`
- [X] T005 [US1] Add "Play Status Report" NavigationLink (using `String(localized:)` for the label) to MainView that navigates to VideoPlaybackScreen with hardcoded HLS URL `https://customer-j8jlsnmsytg4ne2z.cloudflarestream.com/2916cde874951283bc3cc8b7f3f9a9ba/manifest/video.m3u8` in `Apple/Projects/Standup/Sources/MainView.swift`
- [X] T006 [US1] Add SwiftUI Preview for VideoPlaybackScreen in `Apple/Projects/Standup/Sources/Playback/VideoPlaybackScreen.swift`

**Checkpoint**: User Story 1 is fully functional — user can navigate to playback screen, watch HLS video with controls, and navigate back cleanly.

---

## Phase 3: User Story 2 - Playback Resilience (Priority: P2)

**Goal**: Display a clear error message when the video fails to load or the URL is unreachable, so users understand what went wrong.

**Independent Test**: Simulate an unreachable video URL and verify a meaningful error message is shown instead of a blank or frozen player. Navigate back and confirm the app remains stable.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T007 [P] [US2] Write test that VideoPlaybackScreen displays error message when AVPlayerItem status transitions to `.failed` in `Apple/Projects/Standup/Tests/Playback/VideoPlaybackScreenTests.swift`
- [X] T008 [P] [US2] Write test that VideoPlaybackScreen remains in stable state after error and navigation back in `Apple/Projects/Standup/Tests/Playback/VideoPlaybackScreenTests.swift`
- [X] T003 [P] [US2] Write test that VideoPlaybackScreen transitions to error state when given an invalid URL in `Apple/Projects/Standup/Tests/Playback/VideoPlaybackScreenTests.swift`

### Implementation for User Story 2

- [X] T009 [US2] Add Combine observation of AVPlayerItem.status to detect `.failed` state and extract error description in `Apple/Projects/Standup/Sources/Playback/VideoPlaybackScreen.swift`
- [X] T010 [US2] Add error state UI overlay that displays user-facing error message when playback fails in `Apple/Projects/Standup/Sources/Playback/VideoPlaybackScreen.swift`

**Checkpoint**: User Story 2 is complete — unreachable URLs show a clear error message; navigating back returns to a stable main screen.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and accessibility verification.

- [X] T011 Verify VoiceOver accessibility labels are present on the playback screen navigation link and error message in `Apple/Projects/Standup/Sources/Playback/VideoPlaybackScreen.swift`
- [ ] T012 Run quickstart.md validation — confirm all described behaviors work end-to-end on device or simulator
- [ ] T013 Verify that AVKit VideoPlayer renders caption/subtitle tracks when present in the HLS manifest (manual test on device/simulator with a captioned stream)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **User Story 1 (Phase 2)**: Depends on Phase 1 (directory exists)
- **User Story 2 (Phase 3)**: Depends on Phase 2 (VideoPlaybackScreen exists to add error handling to)
- **Polish (Phase 4)**: Depends on Phases 2 and 3

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 1 — no dependencies on other stories
- **User Story 2 (P2)**: Depends on User Story 1 — adds error handling to the VideoPlaybackScreen created in US1

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- View implementation before navigation integration
- Core playback before error handling
- Story complete before moving to next priority

### Parallel Opportunities

- T002 and T003 can run in parallel (both are test tasks writing to the same test file but different test cases)
- T007 and T008 can run in parallel (same reasoning)
- T002/T003 are independent of T007/T008 but should execute in phase order

---

## Parallel Example: User Story 1

```bash
# Write tests in parallel:
Task T002: "Test VideoPlaybackScreen initializes AVPlayer"
Task T003: "Test VideoPlaybackScreen transitions to error state"

# Then implement sequentially:
Task T004: "Create VideoPlaybackScreen view"
Task T005: "Add NavigationLink to MainView"
Task T006: "Add SwiftUI Preview"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (create directory)
2. Complete Phase 2: User Story 1 (tests + implementation)
3. **STOP and VALIDATE**: Test User Story 1 independently on device/simulator
4. Deploy/demo if ready — video playback works end-to-end

### Incremental Delivery

1. Phase 1: Setup → Directory ready
2. Phase 2: User Story 1 → Test independently → Working video playback (MVP!)
3. Phase 3: User Story 2 → Test independently → Resilient error handling
4. Phase 4: Polish → Accessibility verified, quickstart validated
5. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files or independent test cases, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- The hardcoded HLS URL is `https://customer-j8jlsnmsytg4ne2z.cloudflarestream.com/2916cde874951283bc3cc8b7f3f9a9ba/manifest/video.m3u8`
- Existing `VideoPlayerView` in `Recording/` is NOT modified (per research.md R-003)

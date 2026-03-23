# Architectural Decision Records

An Architectural Decision Record (ADR) captures an important architectural decision made during the
development of Naked Standup, along with the context that led to the decision and its consequences.

ADRs are written at the time the decision is made so that future contributors can understand not
just *what* was decided, but *why* — including the alternatives that were considered and the
trade-offs that were accepted. This prevents revisiting settled questions and helps new team members
get up to speed quickly.

## ADR Lifecycle

Each ADR moves through the following statuses:

| Status | Meaning |
|--------|---------|
| **Proposed** | The decision is under discussion and has not yet been accepted. |
| **Accepted** | The decision has been agreed upon and is in effect. |
| **Deprecated** | The decision was once accepted but is no longer recommended. |
| **Superseded** | The decision has been replaced by a newer ADR (which is linked). |

Once an ADR is accepted and published it is not modified, except to update its status. To revise a
decision, create a new ADR and link it back to the one it replaces.

## Creating a New ADR

1. Copy the title format `NNN-short-hyphenated-title.md` using the next available number.
2. Set the status to **Proposed**.
3. Fill in the **Context**, **Decision**, **Consequences**, and any supporting diagrams or code
   samples.
4. Open a pull request. The ADR is accepted when the pull request is merged.

## Index

| # | Title | Status |
|---|-------|--------|
| 001 | [Use AVFoundation for Video Capture](001-avfoundation-recording-architecture.md) | Proposed |
| 002 | [Direct-to-Blob Upload via SAS URL](002-video-upload-architecture.md) | Proposed |
| 003 | [Use Application Insights for Backend Observability](003-application-insights-monitoring.md) | Proposed |

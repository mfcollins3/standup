<!--
Sync Impact Report
- Version change: 0.0.0 → 1.0.0
- Bump rationale: MAJOR — initial ratification of project constitution
- Added principles:
  - I. Ship Often
  - II. Keep Quality High
  - III. Solicit and Respond to Feedback
  - IV. Security by Default
  - V. Infrastructure as Code
  - VI. Conventional Commits
  - VII. Simplicity
  - VIII. Accessibility and Inclusivity
- Added sections:
  - Technology Stack (new section)
  - Development Workflow (new section)
  - Governance (populated from template)
- Removed sections: none
- Templates requiring updates:
  - .specify/templates/plan-template.md ✅ no updates needed (Constitution
    Check section is dynamically filled per feature)
  - .specify/templates/spec-template.md ✅ no updates needed (requirements
    and success criteria are feature-scoped)
  - .specify/templates/tasks-template.md ✅ no updates needed (task phases
    are feature-scoped; testing tasks align with Principle II)
  - .specify/templates/checklist-template.md ✅ no updates needed (generated
    per feature by /speckit.checklist)
- Follow-up TODOs: none
-->

# Naked Standup Constitution

## Core Principles

### I. Ship Often

Naked Standup delivers value through frequent, incremental releases.
Every change MUST be scoped to the smallest deliverable unit that
provides meaningful value to users.

- Features and improvements MUST be broken into small, independently
  shippable increments.
- Each increment MUST be deployable on its own without requiring
  unfinished work to be completed first.
- Long-lived feature branches MUST be avoided. Prefer short-lived
  branches merged frequently into `main`.
- Work-in-progress that cannot ship independently MUST be gated behind
  feature flags or equivalent mechanisms rather than blocking the
  release pipeline.

**Rationale**: Small, frequent releases reduce risk, shorten feedback
loops, and ensure customers receive continuous value. Large batches
increase integration risk, delay feedback, and make rollback harder.

### II. Keep Quality High

Quality is non-negotiable. Automated testing and test-driven
development are primary instruments for maintaining quality across the
Naked Standup codebase.

- All new production code MUST have corresponding automated tests
  (unit, integration, or both as appropriate).
- Test-driven development (TDD) MUST be the default workflow:
  write tests first, verify they fail, then implement until they pass.
- Code that is difficult to test MUST be refactored to become testable
  unless no viable alternative exists. Untestable code MUST be
  discussed and justified with the team before merging.
- Important architectural decisions MUST be captured as Architectural
  Decision Records (ADRs) stored in `docs/adrs/`. ADRs MUST be created
  in the `Proposed` status and MUST NOT be modified after acceptance
  except to update their status. Decisions are revised or superseded by
  creating a new ADR that references the original. Mermaid diagrams and
  sample source SHOULD be included where they aid understanding.

**Rationale**: Automated tests catch regressions before they reach
users. TDD produces focused, well-designed code with high coverage by
default. ADRs preserve the reasoning behind decisions so the team can
evolve the architecture confidently without repeating past mistakes.

### III. Solicit and Respond to Feedback

Naked Standup is built for its users. The team MUST actively seek,
capture, and act on feedback from customers, stakeholders, and
teammates.

- Every shipped increment SHOULD include a mechanism or process for
  collecting user feedback (e.g., in-app prompts, analytics, or
  direct outreach).
- Feedback MUST be triaged, prioritized, and tracked alongside other
  work items. Feedback that affects product direction MUST be visible
  to the entire team.
- Retrospectives and post-release reviews MUST be conducted regularly
  to evaluate what is working and what is not.
- Customer-reported issues MUST be acknowledged promptly and resolved
  according to their severity.

**Rationale**: Building the right product requires continuous validation
with real users. Ignoring feedback leads to wasted effort on features
no one needs and erodes user trust.

### IV. Security by Default

Naked Standup handles user-generated video content and personal data
in a cloud environment. Security MUST be a first-class concern at every
layer of the system.

- All data in transit MUST be encrypted using TLS 1.2 or later. All
  data at rest MUST be encrypted using platform-provided or equivalent
  encryption.
- Authentication and authorization MUST follow the principle of least
  privilege. Secrets MUST be stored in Azure Key Vault and MUST NOT
  appear in source code, configuration files, or logs.
- All code MUST be free from vulnerabilities listed in the OWASP Top 10
  (injection, broken access control, cryptographic failures, etc.).
- Dependencies MUST be kept up to date. Known vulnerable dependencies
  MUST be patched or replaced promptly.
- Security-sensitive changes MUST be reviewed by at least one other
  team member before merging.

**Rationale**: Users trust Naked Standup with their video recordings and
personal information. A security breach undermines that trust and can
have legal and reputational consequences that are difficult to recover
from.

### V. Infrastructure as Code

All Azure infrastructure for Naked Standup MUST be defined and managed
through code. Manual changes to cloud resources are prohibited.

- Azure resources MUST be provisioned using Bicep templates stored in
  the repository.
- Infrastructure changes MUST go through the same review and approval
  process as application code changes.
- Every environment (development, staging, production) MUST be
  reproducible from the infrastructure code in the repository.
- Drift between deployed infrastructure and the code definition MUST
  be detected and corrected.

**Rationale**: Infrastructure as Code ensures environments are
reproducible, auditable, and version-controlled. Manual changes create
undocumented drift that leads to environment-specific bugs and makes
disaster recovery unreliable.

### VI. Conventional Commits

All commit messages in the Naked Standup repository MUST follow the
Conventional Commits specification as defined in the project's
`copilot-instructions.md`.

- Every commit MUST use a valid type prefix (`feat`, `fix`, `docs`,
  `build`, `ci`, `test`, `refactor`, `security`, `perf`, `style`,
  `chore`, `change`, `deprecate`, `remove`, `revert`).
- The first line of the commit message MUST NOT exceed 52 characters.
- The body of the commit message MUST wrap at 72 columns.
- The commit description MUST start with a lowercase letter and use
  present or future tense.

**Rationale**: Consistent, structured commit messages enable automated
changelog generation, make repository history searchable, and
communicate intent clearly to every contributor—present and future.

### VII. Simplicity

Naked Standup favors the simplest solution that meets current
requirements. Complexity MUST be justified.

- Code MUST NOT be written for hypothetical future requirements
  (YAGNI—You Aren't Gonna Need It).
- Abstractions, helper utilities, and indirection layers MUST only be
  introduced when there is a concrete, present need.
- When multiple approaches satisfy the same requirement, the approach
  with fewer moving parts MUST be preferred unless a measurable benefit
  justifies the additional complexity.
- Over-engineering MUST be called out during code review and simplified
  before merging.

**Rationale**: Unnecessary complexity slows development, increases the
surface area for bugs, and makes onboarding harder. Shipping often
requires keeping the codebase lean and understandable.

### VIII. Accessibility and Inclusivity

Naked Standup is a collaboration tool for globally distributed teams.
The product MUST be usable by people of all abilities and backgrounds.

- iOS and iPadOS applications MUST support VoiceOver and Dynamic Type.
- Video content MUST support captions or transcription to ensure
  updates are accessible to team members who are deaf or hard of
  hearing, or who are in environments where audio is not practical.
- The user interface MUST meet WCAG 2.1 Level AA contrast and
  interaction guidelines where applicable to the platform.
- Internationalization considerations MUST be accounted for in UI
  layout and string handling, even if localization is deferred to a
  later phase.

**Rationale**: A product built for global, distributed teams fails its
mission if it excludes team members due to disability, language, or
situational constraints. Accessibility built in from the start is far
less costly than retrofitting later.

## Technology Stack

The following technology choices are authoritative for Naked Standup.
Deviations MUST be proposed and recorded as an ADR before adoption.

- **Frontend**: iOS/iPadOS 26.0+ using Swift and SwiftUI
- **Backend**: Azure Functions
- **API Gateway**: Azure API Management
- **CDN/Ingress**: Azure Front Door
- **Storage**: Azure Blob Storage
- **Secrets Management**: Azure Key Vault
- **Infrastructure Provisioning**: Bicep templates
- **Source Control**: Git hosted on GitHub (`mfcollins3/standup`)

## Development Workflow

- All production work MUST occur on short-lived branches created from
  `main`.
- Pull requests MUST be reviewed by at least one team member before
  merging.
- Automated tests MUST pass before a pull request can be merged.
- The `main` branch MUST always be in a deployable state.
- Each source file MUST include the standard copyright and license
  header as defined in `copilot-instructions.md`.

## Governance

This constitution is the highest-authority document governing the
development practices of Naked Standup. It supersedes conflicting
guidance found in other project documents.

- **Amendments**: Any team member may propose an amendment. Amendments
  MUST be documented, reviewed, and approved before taking effect. Each
  amendment MUST include a migration plan if it changes existing
  workflows or principles.
- **Versioning**: The constitution follows semantic versioning. MAJOR
  increments for backward-incompatible governance changes (principle
  removals or redefinitions). MINOR increments for new principles or
  materially expanded guidance. PATCH increments for clarifications,
  wording, and non-semantic refinements.
- **Compliance**: All pull requests and code reviews MUST verify
  adherence to these principles. Violations MUST be resolved before
  merging. The constitution SHOULD be reviewed quarterly to ensure it
  remains aligned with the team's evolving needs.

**Version**: 1.0.0 | **Ratified**: 2026-03-20 | **Last Amended**: 2026-03-20

# PRD: Naked Standup

- [1. Product overview](#1-product-overview)
- [2. User personas](#2-user-personas)
- [3. Principles & constraints](#3-principles--constraints)
- [4. Release plan (high level)](#4-release-plan-high-level)
- [5. Current version: v1.0.0 requirements](#5-current-version-v100-requirements)
  - [5.1 Authentication and identity](#51-authentication-and-identity)
  - [5.2 Workspaces, projects and access](#52-workspaces-projects-and-access)
  - [5.3 Recording](#53-recording)
  - [5.4 Upload and transcoding](#54-upload-and-transcoding)
  - [5.5 Playback, browsing and sharing](#55-playback-browsing-and-sharing)
  - [5.6 AI transcripts, summaries and conversation](#56-ai-transcripts-summaries-and-conversation)
  - [5.7 Retention and data management](#57-retention-and-data-management)
  - [5.8 Billing and subscriptions](#58-billing-and-subscriptions)
  - [5.9 Security, privacy and compliance](#59-security-privacy-and-compliance)
  - [5.10 Developer platform and API](#510-developer-platform-and-api)
- [6. Non-functional requirements](#6-non-functional-requirements)
- [7. Open questions](#7-open-questions)
- [8. Decisions log](#8-decisions-log)

## 1. Product overview

Naked Standup is a subscription Software-as-a-Service (SaaS) product that lets people record short status report videos for their daily standups. The service also gives customers an open REST API, webhooks and an MCP server so they can reach their own data and build on the product. The service uploads and transcodes each video for on-demand streaming, so stakeholders and managers can watch, replay and share reports whenever it suits them. Release v1.0.0 delivers recording, upload, transcoding and playback on the web, iOS (iPhone and iPad) and Android, along with the account, billing, retention and AI features needed to sell the product.

### 1.1 Problem statement

Live standup meetings are hard to sustain for distributed teams. Team members in different time zones or on different working hours cannot attend at the same time. Managers and stakeholders who cannot attend lose visibility into what is happening on their projects. The target customers are individual developers, freelancers, consultants, small software teams, and enterprises with geographically distributed or Agile teams. Asynchronous video status reports let everyone take part at their own time without a meeting, and let stakeholders catch up quickly with transcripts and AI summaries.

### 1.2 Product vision

Naked Standup becomes the system of record for what teams are doing, day by day, in a form people actually enjoy watching and searching. Video, transcripts and AI retrieval turn daily updates into a searchable history that anyone with access can query in plain language.

### 1.3 Success criteria

These targets are proposed and need confirmation (see Open questions).

- 95% of 30-second reports are ready to stream within 3 minutes of upload completion.
- At least 99% of started uploads complete successfully, including retries and deferred mobile uploads.
- Video playback starts within 2 seconds at the 75th percentile on broadband.
- Transcripts are available within 5 minutes of a report being ready for 95% of reports.
- At least 60% of new workspaces record 3 or more reports in their first 7 days.
- At least 25% of 7-day trials convert to a paid subscription.
- 99% of webhook events are delivered within 1 minute of occurring.
- Usage-based charges reconcile with the internal usage ledger with no unexplained difference above 0.5% per billing cycle.

## 2. User personas

**Team member (reporter).** A developer, freelancer, consultant or engineer who records a daily update. They want recording to take seconds, work on a phone or laptop, and keep working with poor connectivity. Their pain points are meetings at inconvenient hours and repeating the same update to several people.

**Stakeholder or manager (viewer).** A project manager, engineering manager, product owner or client who follows one or more projects. They want to catch up quickly, search past updates, and share a report with others without making them create an account. Their pain points are missing standups and not knowing what changed.

**Workspace or enterprise administrator.** A team lead, IT administrator or security owner who manages people, sign-in, retention and billing. They want single sign-on, role control, audit logs, cost visibility, and compliance with privacy requirements.

## 3. Principles & constraints

### 3.1 Design principles

1. Never lose a recording: a video stays on the device until the server confirms it.
2. Customers own their data: everything a user can do or see in the apps should be reachable through the API, and customers can export it.
3. Recording and watching must take as few steps as possible, and a 30-second report is the typical case.
4. Asynchronous first: everything works regardless of the viewer's time zone or schedule.
5. Secure and private by default: access is checked on every request, and public access happens only through explicit share links.
6. Cost transparency: every billable resource is metered, attributed and visible to the customer.
7. Simplicity over flexibility: ship the core record, process and play loop first.

### 3.2 Technical constraints

- **Platforms:** web browser app (latest versions of Google Chrome, Microsoft Edge and Apple Safari), native iOS app for iPhone and iPad built with Swift and SwiftUI (minimum iOS 27), and native Android app built with Kotlin and Jetpack Compose (minimum version to be decided; target a very recent version that still reaches most Android users).
- **Hosting:** Microsoft Azure, initially in a United States region. The design must allow later deployments to Europe, Asia and other regions.
- **Identity:** Keycloak provides users, authentication, groups and organizations. Methods are email and password with TOTP, WebAuthn passkeys, Google, Microsoft and Apple sign-in, and enterprise SSO (OIDC and SAML) with SCIM provisioning. The minimum user age is 13.
- **Video ingestion:** clients upload directly to Azure Blob Storage using short-lived SAS URLs generated by the API. Originals stay in Azure Blob Storage for downloads, transcription and reprocessing. After upload, the service starts a transcoding job with the Cloudflare Stream API.
- **Video playback:** adaptive on-demand streaming from Cloudflare Stream using signed playback tokens.
- **Billing:** Stripe, with a fixed monthly per-user fee plus usage-based charges (AI tokens, video storage, streaming and on-demand downloads, compute time and other consumption costs).
- **AI:** transcription, summaries, embeddings and conversational answers through Microsoft Foundry on Azure, with usage metered. Transcripts are searchable with Azure AI Search, and vectors for retrieval are stored in Azure AI Search and PostgreSQL.
- **Notifications and email:** APNs and FCM directly for mobile push, Web Push for browsers, and SendGrid for platform email. Enterprises can configure their own SMTP server or SendGrid account.
- **API:** standard REST API with OpenAPI documentation, OAuth 2.0 and OpenID Connect (Authorization Code and Client Credentials flows), signed webhooks, OAuth 2.0 token exchange (RFC 8693) to swap an enterprise SSO token for an API token, and a remote MCP server for AI agents.
- **Performance:** see Non-functional requirements.
- **Security and compliance:** encryption in transit and at rest, least-privilege access, secret management in Azure Key Vault, and alignment with applicable privacy and security frameworks (see Non-functional requirements).

### 3.3 Out of scope

- Screen recording, screen sharing, live video, meetings or video calls.
- Video editing, trimming, filters or effects.
- Comments, reactions or replies on reports.
- First-party integrations with Slack, Microsoft Teams, Jira, GitHub or calendars (customers can build their own with the API, webhooks and MCP server).
- GraphQL APIs and official client SDKs.
- An internal console for enterprise plans and trials (handled manually in v1.0.0).
- Soft delete and restore of deleted videos.
- Daily recording reminders.
- Limits on video storage on a device (planned for a future release).
- Google Play Instant / Android Instant Apps.
- Desktop applications and browser extensions.
- Deployments outside the United States (the design is region-aware, but no other region ships in v1.0.0).
- Self-hosted or on-premises deployment.
- Custom branding and white-labelling.
- Languages other than English for transcripts, summaries and the user interface.

## 4. Release plan (high level)

### v1.0.0 - Date not set, ship as soon as possible - Record, transcode and stream

Done means a customer can sign up (or join through SSO and SCIM), subscribe through Stripe, record a status report of up to 5 minutes on web, iOS or Android (including offline on mobile), have it transcoded and streamed on demand, share it by link, receive transcripts, summaries, notifications and AI conversations, and use the REST API, webhooks and MCP server. Retention and usage billing, including Cloudflare Stream usage, work end to end. Must-have requirements are required for release. Should-have requirements are planned for v1.0.0 and can slip to v1.1.0 if needed to ship sooner. There are no Nice-to-have requirements at present.

### v1.1.0 - Tentative - AI conversation and reach

An internal console for enterprise provisioning, soft delete, daily recording reminders, on-device storage limits, additional languages, and anything deferred from v1.0.0.

### v2.0.0 - Tentative - Regions and integrations

Deployments in Europe and Asia, and integrations with chat and issue-tracking tools.

## 5. Current version: v1.0.0 requirements

Requirements are grouped by area. Each group has one table with one row per requirement. Each requirement is described in its own file in `features/`.

### 5.1 Authentication and identity

| ID | Feature | Priority |
| --- | --- | --- |
| NS-001 | [Email and password sign-up with TOTP](features/NS-001-email-and-password-sign-up-with-totp.md) | Must-have |
| NS-002 | [Passkey (WebAuthn) sign-in](features/NS-002-passkey-webauthn-sign-in.md) | Must-have |
| NS-003 | [Google, Microsoft and Apple sign-in](features/NS-003-google-microsoft-and-apple-sign-in.md) | Must-have |
| NS-004 | [Enterprise single sign-on](features/NS-004-enterprise-single-sign-on.md) | Must-have |
| NS-005 | [Account recovery and session management](features/NS-005-account-recovery-and-session-management.md) | Must-have |

### 5.2 Workspaces, projects and access

| ID | Feature | Priority |
| --- | --- | --- |
| NS-006 | [Workspaces and projects](features/NS-006-workspaces-and-projects.md) | Must-have |
| NS-007 | [Roles and permissions](features/NS-007-roles-and-permissions.md) | Must-have |
| NS-008 | [Invite and manage members](features/NS-008-invite-and-manage-members.md) | Must-have |
| NS-009 | [Enterprise organization administration](features/NS-009-enterprise-organization-administration.md) | Must-have |
| NS-043 | [SCIM provisioning for enterprises](features/NS-043-scim-provisioning-for-enterprises.md) | Must-have |

### 5.3 Recording

| ID | Feature | Priority |
| --- | --- | --- |
| NS-010 | [Record a status report in the web app](features/NS-010-record-a-status-report-in-the-web-app.md) | Must-have |
| NS-011 | [Record a status report on iOS](features/NS-011-record-a-status-report-on-ios.md) | Must-have |
| NS-012 | [Record a status report on Android](features/NS-012-record-a-status-report-on-android.md) | Must-have |
| NS-013 | [Offline recording and deferred upload](features/NS-013-offline-recording-and-deferred-upload.md) | Must-have |
| NS-014 | [Recording limits and quality](features/NS-014-recording-limits-and-quality.md) | Must-have |
| NS-053 | [Overdue upload notification](features/NS-053-overdue-upload-notification.md) | Must-have |

### 5.4 Upload and transcoding

| ID | Feature | Priority |
| --- | --- | --- |
| NS-015 | [Direct upload with SAS URLs](features/NS-015-direct-upload-with-sas-urls.md) | Must-have |
| NS-016 | [Start transcoding with Cloudflare Stream](features/NS-016-start-transcoding-with-cloudflare-stream.md) | Must-have |
| NS-017 | [Processing status and failure handling](features/NS-017-processing-status-and-failure-handling.md) | Must-have |

### 5.5 Playback, browsing and sharing

| ID | Feature | Priority |
| --- | --- | --- |
| NS-018 | [On-demand video playback](features/NS-018-on-demand-video-playback.md) | Must-have |
| NS-019 | [Standup feed and browsing](features/NS-019-standup-feed-and-browsing.md) | Must-have |
| NS-020 | [Public share links](features/NS-020-public-share-links.md) | Must-have |
| NS-021 | [Share link expiration and revocation](features/NS-021-share-link-expiration-and-revocation.md) | Must-have |
| NS-022 | [Push notifications for new reports](features/NS-022-push-notifications-for-new-reports.md) | Must-have |
| NS-023 | [iOS App Clip for playback](features/NS-023-ios-app-clip-for-playback.md) | Should-have |
| NS-024 | [Android deep-link playback](features/NS-024-android-deep-link-playback.md) | Should-have |
| NS-044 | [Enterprise SSO guest viewing](features/NS-044-enterprise-sso-guest-viewing.md) | Should-have |
| NS-045 | [Require sign-in to view reports](features/NS-045-require-sign-in-to-view-reports.md) | Must-have |
| NS-046 | [Web push notifications](features/NS-046-web-push-notifications.md) | Should-have |

### 5.6 AI transcripts, summaries and conversation

| ID | Feature | Priority |
| --- | --- | --- |
| NS-025 | [Automatic transcription](features/NS-025-automatic-transcription.md) | Must-have |
| NS-026 | [AI summary for each report](features/NS-026-ai-summary-for-each-report.md) | Should-have |
| NS-027 | [Combined summary email](features/NS-027-combined-summary-email.md) | Should-have |
| NS-028 | [Transcript full-text search](features/NS-028-transcript-full-text-search.md) | Should-have |
| NS-029 | [Transcript chunking and vector indexing](features/NS-029-transcript-chunking-and-vector-indexing.md) | Should-have |
| NS-030 | [Conversational Q&A on a project or standup](features/NS-030-conversational-q-a-on-a-project-or-standup.md) | Should-have |

### 5.7 Retention and data management

| ID | Feature | Priority |
| --- | --- | --- |
| NS-031 | [Configurable retention](features/NS-031-configurable-retention.md) | Must-have |
| NS-032 | [Automatic deletion and purge](features/NS-032-automatic-deletion-and-purge.md) | Must-have |
| NS-033 | [Download original video](features/NS-033-download-original-video.md) | Should-have |

### 5.8 Billing and subscriptions

| ID | Feature | Priority |
| --- | --- | --- |
| NS-034 | [Per-user subscription through Stripe](features/NS-034-per-user-subscription-through-stripe.md) | Must-have |
| NS-035 | [Seven-day free trial for individuals](features/NS-035-seven-day-free-trial-for-individuals.md) | Must-have |
| NS-036 | [Usage metering and overage billing](features/NS-036-usage-metering-and-overage-billing.md) | Must-have |
| NS-037 | [Enterprise plans](features/NS-037-enterprise-plans.md) | Must-have |
| NS-038 | [Billing management, usage dashboard and alerts](features/NS-038-billing-management-usage-dashboard-and-alerts.md) | Should-have |
| NS-052 | [Cloudflare Stream usage tracking](features/NS-052-cloudflare-stream-usage-tracking.md) | Must-have |
| NS-054 | [Conversation entitlement](features/NS-054-conversation-entitlement.md) | Must-have |

### 5.9 Security, privacy and compliance

| ID | Feature | Priority |
| --- | --- | --- |
| NS-039 | [Audit log](features/NS-039-audit-log.md) | Should-have |
| NS-040 | [Privacy rights: export and deletion](features/NS-040-privacy-rights-export-and-deletion.md) | Must-have |
| NS-041 | [Security baseline](features/NS-041-security-baseline.md) | Must-have |
| NS-042 | [Region-aware architecture](features/NS-042-region-aware-architecture.md) | Should-have |
| NS-047 | [Enterprise email configuration](features/NS-047-enterprise-email-configuration.md) | Should-have |

### 5.10 Developer platform and API

| ID | Feature | Priority |
| --- | --- | --- |
| NS-048 | [Public REST API](features/NS-048-public-rest-api.md) | Must-have |
| NS-049 | [API authentication with OAuth 2.0 and OpenID Connect](features/NS-049-api-authentication-with-oauth-2-0-and-openid-connect.md) | Must-have |
| NS-050 | [Webhook notifications](features/NS-050-webhook-notifications.md) | Must-have |
| NS-051 | [Developer documentation and community](features/NS-051-developer-documentation-and-community.md) | Should-have |
| NS-055 | [MCP server](features/NS-055-mcp-server.md) | Must-have |
| NS-056 | [OAuth 2.0 token exchange](features/NS-056-oauth-2-0-token-exchange.md) | Must-have |

## 6. Non-functional requirements

- **Availability:** 99.9% monthly availability for the API and playback entry points. Recording clients keep working offline.
- **Performance:** API responses at the 95th percentile within 500 ms for reads and 1 second for writes. Playback starts within 2 seconds at the 75th percentile. Feed first page loads within 2 seconds.
- **Scalability:** supports 10,000 concurrent viewers and 1,000 concurrent uploads in v1.0.0 without architecture changes, scaling by configuration.
- **Security:** TLS 1.2 or newer, encryption at rest, Key Vault for secrets, managed identities, private storage, short-lived tokens for every video access, OWASP Top 10 controls, and dependency scanning. The controls are chosen to support a SOC 2 Type II audit.
- **Privacy and compliance:** use SOC 2 Type II as the main security framework, and meet GDPR and CCPA/CPRA requirements as far as possible with US-only hosting, including data subject requests, a documented list of sub-processors (Azure, Cloudflare, Stripe, SendGrid), data processing agreements, and a data retention policy. Video of faces and voices may be biometric-adjacent data, so legal review of laws such as Illinois BIPA is needed before launch.
- **Accessibility:** web and mobile apps meet WCAG 2.2 AA. Captions come from transcripts, and all controls work with a keyboard and screen readers.
- **Error handling:** errors are shown in plain language with a next action. Server operations are idempotent and retried with backoff. Failed jobs go to a dead-letter queue and raise an alert. Nothing a user recorded is discarded without confirmation.
- **Observability:** structured logs with correlation IDs, distributed tracing (OpenTelemetry) and metrics in Azure Monitor and Application Insights. Dashboards and alerts for upload success, transcoding latency, playback errors, AI cost, webhook failures and billing reconciliation. Personal data and video tokens are never logged.
- **API:** 99.9% availability, versioned with at least 12 months' notice before removing a version, and a default rate limit of 600 read requests per minute per client (see NS-048).
- **Cost control:** every billable resource has a usage meter, budget alerts, and per-workspace attribution.
- **Compatibility:** the latest versions of Chrome, Edge and Safari; iOS 27 or later; Android minimum version to be decided.

## 7. Open questions

1. **Cloudflare Stream compliance:** confirm Cloudflare's certifications, data processing agreement, and where Stream stores and serves data, and document it as a sub-processor.
2. **Pricing:** per-user monthly price, usage rates, margins, tax handling (Stripe Tax) and currencies. Also confirm the trial AI cap (proposed $10 of tokens) and whether a card is required up front.
3. **Compliance targets:** confirm the recommended path (SOC 2 Type II first, GDPR and CCPA/CPRA alignment, annual penetration tests, ISO 27001 later, and no HIPAA or PCI scope because Stripe handles cards).
4. **Biometric and privacy law:** legal review of video of faces and voices under laws such as Illinois BIPA, and of age rules (minimum age 13 is the US COPPA threshold; some EU countries require 16 for consent).
5. **MCP scope:** which tools ship in v1.0.0 beyond the list in NS-055, whether any write tools beyond share links are exposed, and whether clients can register dynamically or only through admins.

## 8. Decisions log

| Date | Decision | Rationale | Made By |
| --- | --- | --- | --- |
| 2026-11-05 | Hosting on Microsoft Azure, United States first, region-aware design | Meets the launch market while allowing later expansion | Michael Collins |
| 2026-11-05 | Use Keycloak for identity, with email and password plus TOTP, passkeys, Google, Microsoft and Apple sign-in | Broad sign-in options while the identity layer stays standard and enterprise-ready | Michael Collins |
| 2026-11-05 | Enterprise customers manage their own users and can use SSO | Required by the enterprise target market | Michael Collins |
| 2026-11-05 | Anyone with a share link can view a report without an account | Lowest friction for stakeholders | Michael Collins |
| 2026-11-05 | iOS App Clip for playback and playback from push notification, with the closest Android equivalent | Quick viewing without installing the app | Michael Collins |
| 2026-11-05 | AI transcription, summaries, combined summary emails, full-text search and vector indexing for RAG | Makes reports searchable and quick to consume | Michael Collins |
| 2026-11-05 | Maximum report length of 5 minutes, camera-only recording, offline recording on mobile | Typical report is 30 seconds; controls cost and scope | Michael Collins |
| 2026-11-05 | Default video retention of 30 days, configurable by user, project and enterprise | Controls storage cost and supports compliance | Michael Collins |
| 2026-11-05 | Per-user monthly fee for individuals and small teams, negotiated flat rates for enterprises, plus usage charges, billed by Stripe | Predictable base revenue plus consumption pricing | Michael Collins |
| 2026-11-05 | 7-day free trial for individuals only; enterprise trials through sales | Self-service for individuals; sales-led for enterprises | Michael Collins |
| 2026-11-05 | Upload to Azure Blob Storage with SAS URLs, then transcode and stream with Cloudflare Stream | Direct uploads scale and Stream avoids building a video pipeline | Michael Collins |
| 2026-11-05 | Ship v1.0.0 as soon as possible, with no fixed date | Speed to market | Michael Collins |
| 2026-11-05 | Do not use Google Play Instant; use App Links, notification deep links and the web player on Android | Instant Apps availability is uncertain | Michael Collins |
| 2026-11-05 | Native apps: Swift and SwiftUI for iOS (minimum iOS 27), Kotlin and Jetpack Compose for Android | Best platform capabilities for camera and background upload | Michael Collins |
| 2026-11-05 | Web support for the latest Chrome, Edge and Safari | Narrow test matrix and fast delivery | Michael Collins |
| 2026-11-05 | Keep originals in Azure Blob Storage for downloads, transcription and reprocessing | Enables downloads and AI without depending on Stream | Michael Collins |
| 2026-11-05 | Track Cloudflare Stream storage, transcoding and playback usage per user and enterprise | Needed for fair usage-based billing | Michael Collins |
| 2026-11-05 | Use Microsoft Foundry for AI; Azure AI Search and PostgreSQL for vectors | Keeps AI in the Azure tenant | Michael Collins |
| 2026-11-05 | Keep conversational Q&A in v1.0.0 | Key differentiator | Michael Collins |
| 2026-11-05 | Trial includes up to 30 minutes of stored video and a capped amount of AI use (proposed $10 of tokens) | Limits cost of free trials | Michael Collins |
| 2026-11-05 | Viewers do not use a paid seat for playback but do for AI features | Stakeholders watch free; AI has a real cost | Michael Collins |
| 2026-11-05 | Projects only, with no Teams layer in v1.0.0 | Simplicity | Michael Collins |
| 2026-11-05 | Minimum retention 7 days, no maximum; most restrictive level wins; transcripts, summaries and vectors are deleted with the video | Customers pay for storage; privacy | Michael Collins |
| 2026-11-05 | Share links may expire; users and enterprises can require sign-in to view | Control over sharing | Michael Collins |
| 2026-11-05 | Minimum user age is 13; SCIM included for enterprises in v1.0.0 | Meets US requirements and enterprise needs | Michael Collins |
| 2026-11-05 | Enterprise trials are set up through an internal console used by administrators and sales | Sales-led onboarding | Michael Collins |
| 2026-11-05 | APNs and FCM directly, plus web notifications; SendGrid for platform email, with enterprise SMTP or SendGrid configuration | Control and enterprise flexibility | Michael Collins |
| 2026-11-05 | Reminders, non-English languages and on-device storage limits are not in v1.0.0; notify users if an upload has not completed after 24 hours | Scope control | Michael Collins |
| 2026-11-05 | Provide a REST API with OAuth 2.0 and OpenID Connect (Authorization Code and Client Credentials flows) and webhooks | Customer data access and community building | Michael Collins |
| 2026-11-05 | Keep storage in both Azure Blob Storage and Cloudflare Stream | Simplicity and independence from Stream; cost accepted | Michael Collins |
| 2026-11-05 | Android minimum version is Android 10 (API 29) | Good reach with modern features | Michael Collins |
| 2026-11-05 | Enterprise SSO guest viewing without a user account is included | Frictionless internal sharing | Michael Collins |
| 2026-11-05 | PostgreSQL holds metadata and chunked text; Azure AI Search provides hybrid retrieval | Clear split of responsibilities | Michael Collins |
| 2026-11-05 | Only conversational Q&A needs an AI seat; transcription, summaries and indexing are charged to the recording user | Simple cost attribution | Michael Collins |
| 2026-11-05 | No soft delete in v1.0.0 | Simplicity and privacy | Michael Collins |
| 2026-11-05 | Internal enterprise console is out of scope for v1.0.0 | Handle manually initially | Michael Collins |
| 2026-11-05 | Expose an MCP server and support OAuth 2.0 token exchange (RFC 8693) for SSO-to-API tokens | Lets customers use agents and their own applications | Michael Collins |
| 2026-11-05 | Adopt the proposed API rate limits, quotas and webhook retry policy as v1.0.0 defaults | Reasonable starting point; tune with real traffic | Michael Collins |
| 2026-11-05 | Token exchange accepts ID tokens, SAML assertions and JWT access tokens issued for Naked Standup | Covers common enterprise identity provider setups safely | Michael Collins |

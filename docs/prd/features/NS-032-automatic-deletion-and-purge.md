# NS-032: Automatic deletion and purge

[Back to the PRD](../README.md)

**Requirement ID:** NS-032

**User Story:** As a workspace administrator, I want to have expired and deleted content removed completely so that data does not linger after it should be gone.

**Acceptance Criteria:**

- [ ] A scheduled job deletes reports past their retention date from Azure Blob Storage (originals), Cloudflare Stream, the transcript store, the search index and the vector stores (Azure AI Search and PostgreSQL).
- [ ] Transcripts and summaries are deleted with the video.
- [ ] Users can delete their own reports at any time, and admins can delete any report in their scope.
- [ ] Deleted reports stop playing immediately, including through share links.
- [ ] Deletion is logged with who or what triggered it.
- [ ] Deletions are confirmed complete in all stores within 24 hours.
- [ ] Deletion is permanent: there is no soft delete or restore in v1.0.0, and the deletion confirmation says so.

**Technical Notes:** Verify Stream deletion through the API. Storage in both Azure Blob Storage and Cloudflare Stream is expected; both copies are deleted.

**Priority:** Must-have

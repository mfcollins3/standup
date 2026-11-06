# NS-029: Transcript chunking and vector indexing

[Back to the PRD](../README.md)

**Requirement ID:** NS-029

**User Story:** As a stakeholder, I want to have transcripts prepared for AI retrieval so that I can ask questions about my project.

**Acceptance Criteria:**

- [ ] Transcripts are split into overlapping chunks that carry project, author, date and timestamp metadata.
- [ ] Each chunk is converted to an embedding and stored in a vector index.
- [ ] Deleting a report or applying retention removes its chunks and vectors.
- [ ] Embedding usage is metered for billing.
- [ ] Re-indexing can be run when the embedding model changes.
- [ ] Chunks and vectors are removed when the source video is deleted, with no orphaned data in Azure AI Search or PostgreSQL.

**Technical Notes:** Embeddings produced with Microsoft Foundry models. PostgreSQL holds chunk metadata and chunked text; Azure AI Search provides hybrid (keyword plus vector) retrieval. An ADR records the split and how the two stores stay in sync.

**Priority:** Should-have

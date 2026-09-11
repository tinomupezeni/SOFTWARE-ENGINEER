# Duplicate Empty-Shell Practice Papers from Two Uncoordinated Replication Paths

**Date:** 2026-08-19
**Project:** HBEC
**Environment:** Staging and Production
**Severity:** High
**Status:** Resolved

## Summary
Following the Harness upload-pipeline fix (see the companion log entry), a student clicking into a specific "Mathematics Paper 1" practice paper landed on an empty, question-less version of it — while a second, real, 136-question version of the exact same paper existed under a different id. Three such duplicate empty shells existed on production, and the underlying cause would have kept producing more of them for every future specimen_paper/past_paper upload.

## Symptoms
- Frontend console: `Harness paper detail failed, falling back to student backend: Error: Request failed: 404 - {"detail":"Paper not found"}` — designed-in, non-fatal fallback behavior, which is why this looked harmless at first
- The "successful" fallback response itself had `"questions": []` — the student would have seen a paper with zero questions and no error message at all

## Environment Details
- **Server/Host:** VPS (staging and production)
- **Services Affected:** `hbec-admin-backend`, `hbec-student-backend`, `hbec-harness`
- **Related Components:** `ADMIN/adminBackend/apps/replication/signals.py` (`on_content_save`), `ADMIN/adminBackend/apps/replication/tasks.py` (`extract_content_paper_via_harness`), `AGENTIC_HARNESS/app/admin/schemas.py` (`PaperUploadRequest`)
- **Time First Observed:** 2026-08-19

## Investigation Steps

### 1. Initial Diagnosis
Traced the specific paper id the student hit: it belonged to a `practice.Paper` row with `harness_paper_id=None` and zero related `PaperQuestion` rows. A **second** `Paper` row existed with the same title, `harness_paper_id` set, and 136 real questions.

### 2. Root Cause Analysis
`on_content_save` (fired whenever an admin `curriculum.Content` record is published) does two independent things for `specimen_paper`/`past_paper` content with a file attached:
1. Immediately queues a `StreamOutbox` `"paper_published"` event with a **hardcoded empty** `"questions": []`, so students can browse the paper right away
2. Kicks off `extract_content_paper_via_harness.delay(...)`, an async Celery task that sends the PDF to the Harness for real extraction, landing the real questions **under the Harness's own paper id** via a separate endpoint (`SyncPaperView`) once extraction finishes

Nothing ever linked or deduplicated these two rows — the "placeholder" was never meant to be permanent, but nothing replaced or removed it once the real extraction landed.

### 3. Key Findings
- 3 confirmed empty-shell duplicates on production, all from one batch of specimen_paper uploads the day before, discovered via `Paper.objects.annotate(qc=Count('questions')).filter(qc=0, harness_paper_id__isnull=True)`
- Not all 3 were simple duplicates on closer inspection:
  - **Mathematics Paper 1**: a true duplicate — real paper existed elsewhere with 136 questions
  - **Mathematics Paper 2**: its `Content.metadata` had `paperNumber: '1'` (a data-entry mistake — should have been `'2'`), which made the Harness's own duplicate-detection correctly conclude it was the same paper as Paper 1 and refuse to extract it separately; its real content had genuinely never been extracted at all
  - **Chishona Paper 1** (both environments): `harness_paper_id` was `None` in the admin metadata — extraction had never completed, for reasons unrecoverable after container log rotation, but re-triggering it (now that the Harness's upload endpoint actually worked) succeeded immediately
- Manually re-triggering Chishona's extraction surfaced a **fourth**, separate bug: `PaperUploadRequest.subject` was validated against `^[A-Za-z0-9\s\-_]+$`, which rejects parentheses, slashes, commas, and `&` — but at least 8 real curriculum subject names use one of those characters ("Indigenous Language (Shona/Ndebele)", "Agriculture, Science & Technology", etc.), so every one of those subjects' uploads had been silently 422ing

## Root Cause
`on_content_save` fires an immediate empty-questions placeholder and an async Harness extraction for the same content, with nothing linking the two rows together afterward — plus a too-strict subject-name validation regex on the Harness side rejecting real curriculum subject names outright.

## Solution

### Immediate Fix
`signals.py`: skip the placeholder `StreamOutbox` event entirely when the content will be Harness-extracted (`past_paper`/`specimen_paper` with a file) — the extraction path becomes the sole source of that Paper row. `mark_scheme`/`examiner_report` (never Harness-extracted as their own paper) keep the placeholder unchanged, since it's their only route to the student backend.
`schemas.py`: broadened `subject`'s pattern to `^[A-Za-z0-9\s\-_(),/&]+$`, verified against every real subject name currently in the curriculum.

### Long-term Fix / Data Cleanup
Rehearsed fully on staging before touching production data:
1. Deleted the one true duplicate (Math Paper 1's empty shell)
2. Re-triggered Chishona's extraction (both environments) — succeeded, 44 real questions, empty shell deleted
3. Corrected Math Paper 2's `paperNumber` metadata and cleared its incorrectly-inherited `harness_paper_id`, re-triggered extraction — succeeded, 23 real questions with the correct `paper_number=2`, empty shell deleted

Committed as `6a67b318` (`fix(admin): stop double-publishing past_paper/specimen_paper content`, with a 4-test regression suite) and `0683c9e5` (`fix(harness): allow real curriculum punctuation in paper upload subject`, with a parametrized regression test against the real subject list). Verified zero empty-shell papers remain on either environment after cleanup.

## Prevention
- [x] Code changes required (committed, with regression tests)
- [x] Data cleanup completed on both environments
- [ ] Consider validating new subject/content metadata against the Harness's actual acceptance rules *at admin-upload time*, not just discovering the mismatch when extraction later fails

## References
- Companion incident: `2026-08-19-harness-upload-pipeline-syntax-error-bad-merge.md` (the pipeline had to be un-broken before any of this could even be tested)

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~2 hours (investigation, fix, staging rehearsal, production remediation)

# Unpublishing or deleting an exam paper never told the student backend

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
`ExamBoard`, `Grade`, `Subject`, `Topic` and `Content` all have a
`post_delete` (and, for `Content`, a status-transition retraction) signal
that tells the student backend to remove its copy. `exam_papers.ExamPaper`
had neither. A paper rejected, archived, or hard-deleted on admin stayed
visible to students forever, with nothing anywhere saying so — discovered
today when unpublishing OCR-broken Mathematics papers required manually
updating both the admin and student databases by hand, because the
admin-side status change alone propagated nowhere.

## Symptoms
Unpublishing a paper on admin (`status = "published"` → `"rejected"`) had
no effect on the student backend's copy; it stayed `published` and visible
until manually corrected there too.

## Root Cause
`on_exam_paper_save` (`ADMIN/adminBackend/apps/replication/signals.py`)
returned early on any non-`"published"` status with no retraction, and no
`post_delete` receiver existed for `exam_papers.ExamPaper` at all — the one
model in the replication signal module missing what every sibling model
already has.

## Prevention / Rule
**Guardrail:** the existing regression tests
(`test_exam_paper_retraction_signals.py`) pin the transition semantics —
unpublish retracts, delete retracts, a draft-to-draft save emits nothing,
republishing emits nothing — the same discipline
`test_content_retraction_signals.py` already established for `Content`.

## Solution
Added `remember_exam_paper_status` (`pre_save`, mirrors
`remember_content_status`) so `post_save` can distinguish "was published,
now isn't" from "never published," and a `post_delete` receiver for the
hard-delete path `post_save` cannot cover. Both funnel through one
`_retract_exam_paper` body — same "one body for archival and deletion"
reasoning `_emit_content_retraction` already documents for `Content`.
Verified live on staging: unpublished a real Chemistry paper via `.save()`
(not a manual dual-database update) and confirmed it disappeared from the
student backend automatically after the outbox drained — no manual
student-side step needed, for the first time.

## Prevention
- [x] Fix applied, deployed, and verified live on staging
- [x] Regression tests added (6 new, mirroring the `Content` pattern)
- [ ] Same fix needs verifying works correctly if/when promoted to production

## Related Issues
- `Backend_and_API/HBEC-2026-09-21-zimsec-math-papers-unusable-without-ocr.md` — the unpublish action that surfaced this gap

## References
- `ADMIN/adminBackend/apps/replication/signals.py`
- `ADMIN/adminBackend/apps/replication/tests/test_exam_paper_retraction_signals.py`

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~25 minutes

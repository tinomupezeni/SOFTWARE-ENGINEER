# Bulk-PDF Papers With No Inferable Year Were Permanently Stuck as Untouched Drafts

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Fixed, deployed to staging

## Summary
Direct follow-up to
`2026-09-11-bulk-pdf-import-blocked-by-nginx-and-django-upload-limits.md`.
After fixing the nginx/Django upload limits, the user bulk-imported a real
18-file folder. Investigating why two of them permanently failed with
`HarnessExtractionError('Extraction failed: {"detail":"Invalid paper
metadata: year=0"}')` led to a fix earlier the same session
(`launch_ingestion_pipeline` now refuses to dispatch extraction for a
paper with no year at all, rather than burning all 3 retries on a
guaranteed failure — `extract_questions_via_harness` sends `paper.year or
0`, and the harness hard-rejects `year=0`).

That fix was correct but incomplete for the bulk-PDF path specifically:
it stopped the wasted retries, but left a paper like
`DOC-20240926-WA0001 [mkscges].pdf` (a WhatsApp-scan filename with no
real date in it — `infer_paper_fields_from_filename` legitimately can't
find a year) as an untouched draft with its file attached and nothing
happening. Functionally correct (no more silent retry-looping) but not
useful — a curator who bulk-imports 18 files and gets one permanently
stuck with no automatic path forward has to notice it, open it, and
manually re-trigger extraction themselves.

## Solution

### Immediate Fix
`ADMIN/adminBackend/apps/exam_papers/bulk_import.py`:
- Added `UNKNOWN_YEAR = 1900` — a sentinel chosen because it predates
  ZIMSEC's existence by decades, so it can never collide with a real exam
  year, while still being a real positive integer that passes the
  harness's `year > 0` check.
- `infer_paper_fields_from_filename` now returns `UNKNOWN_YEAR` instead
  of `None` when no year can be found, and appends `" (year unknown)"` to
  the title — visible directly in the paper list without anyone needing
  to know what 1900 means.

Net effect: a file with no parseable year now gets ingested immediately
like every other file in the batch, flagged in its own title for a
curator to fix the real year later, instead of sitting untouched.
`launch_ingestion_pipeline`'s year-guard (the previous fix) stays in
place as a safety net for any other path that might still produce a
genuinely `None` year (a hand-written CSV/JSON/ZIP row that omits the
column).

Updated the existing unparseable-filename test to assert the sentinel
year and title suffix, and that extraction now actually dispatches
(previously asserted `year is None` with dispatch mocked out and
untested either way). 135/135 passing across `apps/exam_papers/`, ruff
clean.

Manually fixed and re-dispatched the one paper from the user's real
18-file batch that was already stuck from before this fix shipped
(`Doc 20240926 Wa0001 [Mkscges]` → year set to 1900, title updated,
`launch_ingestion_pipeline` re-run).

### Long-term Fix
None needed — this closes the loop the previous fix opened.

## Prevention
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a, self-documenting via the title suffix
- [ ] Code changes required — done

## Related Issues
- Direct continuation of the two immediately-preceding entries from the
  same real-world bulk-import test:
  `2026-09-11-bulk-pdf-import-blocked-by-nginx-and-django-upload-limits.md`
  and the `launch_ingestion_pipeline` year-guard fix (same session, same
  investigation, logged together in that entry rather than separately at
  the time).

## References
- `ADMIN/adminBackend/apps/exam_papers/bulk_import.py`
  (`UNKNOWN_YEAR`, `infer_paper_fields_from_filename`)
- `ADMIN/adminBackend/apps/exam_papers/tasks.py::launch_ingestion_pipeline`
  (unchanged in this fix, still the safety net)
- `ADMIN/adminBackend/apps/exam_papers/tests/test_bulk_import.py::TestPdfFolderImport::test_an_unparseable_filename_still_imports_with_defaults`

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery

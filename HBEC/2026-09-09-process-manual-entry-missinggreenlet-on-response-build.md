# process_manual_entry Crashed Building Its Own Response (MissingGreenlet)

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The third bug found in immediate succession along the admin paper save
path: generation and save both succeeded, but the request crashed one step
later building the response, with a SQLAlchemy async lazy-load error. The
exact same failure class had already been diagnosed and fixed elsewhere in
the same file — this function just never got the same fix applied.

## Symptoms
- `pydantic_core.ValidationError: ... MissingGreenlet: greenlet_spawn has
  not been called; can't call await_only() here` immediately after a
  successful generation and save.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Agentic Harness (`app/admin/services/upload_pipeline.py`)
- **Time First Observed:** 2026-09-09, immediately after the previous two fixes in this session

## Investigation Steps

### 1. Initial Diagnosis
The crash was in `PaperResponse.model_validate(paper)` — `PaperResponse.questions`
is a lazy SQLAlchemy relationship, and the `paper` object `store_paper()`
returns doesn't have it eager-loaded. Pydantic's synchronous validation
tripped a lazy-load outside any active async/greenlet context.

### 2. Root Cause Analysis
Grepped the same file for this exact failure class and found it already
fixed once, in the main upload pipeline (`upload_paper`'s code path, ~20
lines above `process_manual_entry`): a comment reading "Re-query with eager
loading to avoid async lazy-load issues", using a helper
`_paper_eager_options()`. `process_manual_entry` was added later and never
got the same treatment.

### 3. Key Findings
- This wasn't a new failure class to solve — it was a known, already-fixed
  bug pattern in the same file that simply hadn't been applied consistently
  to every function that needed it.

## Root Cause
`process_manual_entry` built its response from the ORM object
`store_paper()` returned, without re-querying with eager-loaded
relationships first — unlike the main upload pipeline function right above
it, which already has this exact fix.

## Solution

### Immediate Fix
None separate from the long-term fix.

### Long-term Fix
Copied the identical pattern already used in the main upload pipeline:
re-query the paper with `_paper_eager_options()` before building
`PaperResponse`, rather than inventing a new fix for an already-solved
problem.

## Prevention
- [ ] Consider extracting "load a paper the way responses need it loaded"
      into one shared helper so this can't drift between callers again
- [x] Confirmed live: this was the last bug in the save chain — the next
      retry produced a real, saved paper with correctly graded questions

## Related Issues
- Companion: nonexistent `_save_extracted_paper` function
- Companion: wrong `LLMQuestion` field mapping
- Both found and fixed in the same debugging session, same request path

## References
- `AGENTIC_HARNESS/app/admin/services/upload_pipeline.py`
- Commit `69194fff`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session

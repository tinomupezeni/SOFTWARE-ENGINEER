# Admin AI Paper Generation Crashed on Save With an ImportError for a Function That Never Existed

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** Critical
**Status:** Resolved

## Summary
Every admin AI-generated paper that successfully finished generation still
crashed immediately afterward, on save, because the code imported
`_save_extracted_paper` from `upload_pipeline.py` — a function that never
existed anywhere in that module. This is very likely why the admin AI
paper-generation feature has never actually produced a real paper with
questions since it was first built.

## Symptoms
- Papers showed `Draft`/`0 questions` in the admin UI even after the LLM
  call itself completed and logged a successful response.
- Harness logs: `ImportError: cannot import name '_save_extracted_paper' from 'app.admin.services.upload_pipeline'`.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Agentic Harness (`app/admin/router.py`)
- **Related Components:** `app/admin/services/upload_pipeline.py`
- **Time First Observed:** 2026-09-09, retrying a real stuck admin paper after fixing the GPU-timeout issues

## Investigation Steps

### 1. Initial Diagnosis
Confirmed via harness logs that generation itself succeeded
(`llm_call_success`, real token counts) but the request still crashed one
step later, inside the same endpoint.

### 2. Root Cause Analysis
Grepped `upload_pipeline.py` for `_save_extracted_paper` — no definition
anywhere. The sibling `/papers/manual` endpoint, doing the same
"save a fully-formed paper" job, calls a real function:
`process_manual_entry(data, admin_id, db) -> UploadResult`.

### 3. Key Findings
- This code path had apparently never been exercised end-to-end
  successfully before — a broken import at this exact spot would have
  crashed every single admin generation regardless of any other fix.
- The correct function already existed and was already proven working via
  the manual-entry endpoint; this wasn't missing functionality, just a
  wrong reference.

## Root Cause
`app/admin/router.py::generate_admin_paper` called a function that was
never defined in `upload_pipeline.py`.

## Solution

### Immediate Fix
None separate from the long-term fix.

### Long-term Fix
Swapped the call to the real `process_manual_entry(entry, admin_id, db)`,
which already returns a complete `UploadResult` — also removed the
now-redundant manual `(paper, q_count, mp_count)` unpacking and
`UploadResult` construction that existed around the broken call.

## Prevention
- [ ] Add an integration test that exercises `/papers/generate` end-to-end
      against a real (or realistically mocked) DB, so a broken import in
      this path fails CI instead of only failing in production traffic
- [x] Immediate live retry against staging confirmed the fix (see companion
      entries — this was the first of several bugs found in immediate
      succession along the same save path)

## Related Issues
- Companion: wrong `LLMQuestion` field mapping (the very next bug hit,
  same request path)
- Companion: `process_manual_entry` `MissingGreenlet` crash (the bug after that)

## References
- `AGENTIC_HARNESS/app/admin/router.py`
- `AGENTIC_HARNESS/app/admin/services/upload_pipeline.py`
- Commit `c5bbc7b5`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session

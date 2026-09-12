# Harness Admin Paper Upload Was 500ing on Every Single Call Since a Bad Merge

**Date:** 2026-08-19
**Project:** HBEC
**Environment:** Staging and Production
**Severity:** Critical
**Status:** Resolved

## Summary
The Agentic Harness's admin paper-upload/extraction endpoint (`POST /api/v1/admin/papers/upload`) has been returning a hard 500 on **every single call**, on both staging and production, since a bad merge on 2026-08-18. The root cause was a genuine Python `SyntaxError` in a committed source file — meaning the module could never even be imported, and the same merge silently reverted two other functions to broken pre-fix states without anyone noticing, because the whole file failing to import masked their test failures as collection errors instead of visible red tests.

## Symptoms
- Started as a much smaller-looking investigation: a student's console showed `[examService] Harness paper detail failed, falling back to student backend: Error: Request failed: 404`, with the fallback appearing to work
- Root-causing that "harmless fallback" led to: a specific specimen_paper upload's extraction had never completed (`harness_paper_id` was `null` in its metadata, meaning the harness upload endpoint had never successfully processed it)
- Manually re-triggering the extraction task reproduced a real, hard failure: `HTTP/1.1 500 Internal Server Error` from `POST http://harness:8080/api/v1/admin/papers/upload`, with the harness container's own logs showing an ASGI exception group ending in `SyntaxError: invalid character '—' (U+2014)` inside `upload_pipeline.py`

## Environment Details
- **Server/Host:** VPS (staging, then confirmed identical on production before/after promotion)
- **Services Affected:** `hbec-harness`, `hbec-admin-worker` (the Celery task calling into it)
- **Related Components:** `AGENTIC_HARNESS/app/admin/services/upload_pipeline.py`
- **Time First Observed:** Introduced 2026-08-18 09:34 (commit `3af9350`'s history via a merge), discovered 2026-08-19

## Investigation Steps

### 1. Initial Diagnosis
`docker logs hbec-harness-staging --since 5m | grep -A 30 'papers/upload'` showed a full ASGI exception group. The reported `SyntaxError` line (a stray em-dash inside what looked like a docstring) shouldn't be possible in real Python 3 — any Unicode character is legal inside a triple-quoted string. That mismatch was the tell that something upstream of that line had already broken string/code tokenization.

### 2. Root Cause Analysis
```bash
grep -n '"""' app/admin/services/upload_pipeline.py   # 39 occurrences — an ODD count
```
An odd triple-quote count meant an unterminated string somewhere. Found it directly: `_render_pages` was defined **twice**, back to back —
```python
def _render_pages(path: str) -> list[bytes]:
    """Render every page to a PNG for OCR.
                                              # <- opening quote never closes here
def _render_pages(path: str) -> list[bytes]:
    """Render every page to a PNG for OCR."""
```
The first, incomplete copy's docstring never closed, so everything from that `"""` onward — including the second `def` line and its own opening `"""` — was consumed as string content until the *next* `"""` the tokenizer found, several lines later. That garbled state is what eventually surfaced as an "invalid character" error at an unrelated line further down.
`git blame` on the surrounding lines showed the two fragments came from **different commits** (2026-08-17 and 2026-08-18), confirming this was a botched merge/rebase conflict resolution, not a typo.

### 3. Key Findings
- `git show 3af9350 -- upload_pipeline.py` revealed the *intended*, fully-tested version of this file — that commit had correctly rewritten `spooled_upload` to chunk-read with a size ceiling, added a page-count ceiling to `_render_pages`, and added DOCX routing to `extract_text`
- The bad merge hadn't just left a stray docstring fragment — it had **reverted all three of those functions** to their pre-fix state while leaving one orphaned fragment of the new docstring behind:
  - `spooled_upload` no longer wrote any uploaded content to its temp file at all — every upload spooled to an **empty** file
  - `_render_pages` lost its `MAX_RENDER_PAGES` ceiling entirely
  - `extract_text` lost DOCX routing and the `ResourceLimitError` re-raise for OCR limits
- Running the harness's own test suite confirmed all of this: `tests/admin/` couldn't even be collected before the fix (`SyntaxError` on import — meaning these tests had been silently not-running since 2026-08-18); after fixing just the syntax, 6 of 261 tests failed for real, substantive reasons matching exactly the three reverted functions above

## Root Cause
A merge on 2026-08-18 mishandled a conflict in `upload_pipeline.py`, leaving a hard `SyntaxError` (via a duplicated, never-closed docstring) and silently reverting three functions to broken/incomplete pre-fix states. The file has never been importable since, meaning the admin paper-upload endpoint has been completely non-functional — not intermittent, total — for a full day before discovery.

## Prevention / Rule
**Guardrail:** a CI step that explicitly checks `pytest --collect-only`'s exit code and fails the whole build red on any collection error, instead of only reporting the pass/fail count of whatever tests *did* successfully collect.

This is the actual gap that let a full day of complete endpoint failure hide behind "6 tests didn't run" instead of an unmissable red build — the file's own Prevention list already names this as unchecked; this makes it the enforced rule.

## Solution

### Immediate Fix
Removed the duplicate/orphaned `_render_pages` fragment, then restored all three functions to their intended, tested form from `git show 3af9350`:
```python
# spooled_upload: chunked reads with limits.MAX_UPLOAD_BYTES ceiling
while chunk := await file.read(limits.UPLOAD_CHUNK_BYTES):
    ...
    if written > limits.MAX_UPLOAD_BYTES:
        raise limits.ResourceLimitError(...)

# _render_pages: MAX_RENDER_PAGES ceiling restored
if doc.page_count > limits.MAX_RENDER_PAGES:
    raise limits.ResourceLimitError(...)

# extract_text: DOCX routing restored
if docx_text.is_docx(tmp_path):
    return await asyncio.to_thread(docx_text.extract_text, tmp_path)
```

### Long-term Fix
Committed as `963ae8e1` (`fix(harness): restore upload_pipeline.py, broken since a bad merge on Aug 18`). Full harness suite: 2151 → 2154 passed (6 skipped) after the fix, versus a collection error before it. Rebuilt and verified on staging first (re-triggered a real stuck extraction and confirmed it now succeeds end-to-end with real questions extracted), then promoted the exact same, digest-verified images to production.

## Prevention
- [ ] CI must fail loudly, not silently, on a test-collection error — this bug hid behind "6 tests didn't run" for a full day when it should have been an unmissable red build
- [x] Full test suite run and confirmed green before promoting
- [ ] Consider a merge-conflict review checklist item specifically for files with async generators / multi-function diffs, since this class of silent revert is easy to miss in a fast conflict resolution

## References
- `git show 3af9350 -- AGENTIC_HARNESS/app/admin/services/upload_pipeline.py` (the original, correct diff this fix restores)

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~1.5 hours (from the original 404 report to full root cause and fix)

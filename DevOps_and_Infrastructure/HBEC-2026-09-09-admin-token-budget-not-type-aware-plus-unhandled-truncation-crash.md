# Admin Paper Generation Truncated on "Structured" Questions, Then Crashed Instead of Failing Cleanly

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
A flat per-question token-budget estimate for admin paper generation wasn't
enough for "structured" questions specifically, and the resulting truncated
LLM response crashed the ASGI application with an unhandled
`JSONDecodeError` instead of returning a clean, retryable error.

## Symptoms
- A real 10-question "structured" Economics admin request truncated
  mid-question on repeated retries, each time with a different raw
  `JSONDecodeError` (`Unterminated string...`, `Expecting ',' delimiter...`).
- Harness logs showed `Exception in ASGI application` — an unhandled crash,
  not a caught, logged failure.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Agentic Harness (`exam_practice` paper generation)
- **Related Components:** `app/exam_practice/services/paper_generator.py`
- **Time First Observed:** 2026-09-09, admin bulk-generation testing

## Investigation Steps

### 1. Initial Diagnosis
Harness logs showed `output_tokens` hitting exactly the configured
`max_tokens` ceiling on the failing calls, and the response was cut off
mid-question.

### 2. Root Cause Analysis
The token budget was `min(16000, 1200 + count * 320)` — a single flat
coefficient regardless of `question_type`. "Structured" questions carry full
M/A/B marking schemes with acceptable answers and keywords; an MCQ carries
four options. The flat 320/question coefficient was calibrated against
"mixed" and wasn't enough for a batch of purely structured questions.

Separately, `_extract_json()`'s fallback path (grab the outermost `{...}`
when a strict `json.loads()` fails) had an unguarded second `json.loads()`
call. For a genuinely truncated response, `rfind("}")` often lands on some
inner object's closing brace rather than the true outer one, so that slice
is itself invalid JSON — and the second `json.loads()` raised uncaught,
crashing the ASGI app rather than surfacing the same clean `ValueError`
every other failure path in this function already produces.

### 3. Key Findings
- Token-budget estimation needs to be type-aware, not a single flat number.
- A "best-effort JSON recovery" fallback needs its own recovery path too —
  it's not automatically safe just because it's already inside a `try/except`.

## Root Cause
1. Flat token-budget coefficient didn't account for `question_type`.
2. `_extract_json()`'s fallback `json.loads()` had no exception handling of
   its own.

## Solution

### Immediate Fix
None separate from the long-term fix.

### Long-term Fix
- Token budget is now type-aware: `{"mcq": 200, "mixed": 380, "structured": 550}`
  tokens/question, capped at 16000 total.
- `num_ctx` raised from 16384 to 24576 to keep headroom under the model's
  native 32768 context, matching the new higher ceiling.
- Wrapped `_extract_json()`'s fallback `json.loads()` in its own
  try/except, raising the same clean `ValueError` on failure instead of
  letting a raw `JSONDecodeError` escape.
- Added regression tests: structured questions get a bigger budget than
  MCQ for the same count; a truncated-but-braced response raises
  `ValueError`, not `JSONDecodeError`.

## Prevention
- [x] Type-aware token budget with test coverage
- [x] Guarded fallback JSON parse with test coverage
- [ ] Consider surfacing `finish_reason`/truncation detection explicitly
      from the LLM response rather than inferring it from a parse failure

## Related Issues
- Companion: `_save_extracted_paper` nonexistent function (surfaced right
  after this fix, one layer deeper in the same request path)

## References
- `AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py`
- `AGENTIC_HARNESS/tests/exam_practice/test_paper_generator.py`
- Commit `3e9bdd77`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session

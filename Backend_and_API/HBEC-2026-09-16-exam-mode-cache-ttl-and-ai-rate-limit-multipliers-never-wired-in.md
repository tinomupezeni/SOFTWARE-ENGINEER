# Exam Mode's Documented Cache-TTL and AI-Rate-Limit Effects Are Dead Code — Only the Toggle Itself Is Wired Up

**Date:** 2026-09-16
**Project:** HBEC
**Environment:** Development (found during a read-only caching-architecture research pass)
**Severity:** Medium (no incident yet — the feature simply doesn't do two of the
three things its own docstring says it does; an admin who enables Exam Mode
believing it stabilizes cache TTLs and tightens AI rate limits is getting
neither)
**Status:** Identified, not fixed (out of scope for the research task that found it)

## Summary
`STUDENT/hbec_backend/core/exam_mode.py`'s module docstring states Exam Mode
is "a system-wide toggle that affects: Cache TTLs (increased for stability),
Rate limits (stricter for non-critical endpoints), Admin throttling." The
module defines `get_cache_ttl_multiplier()` (returns 6x in exam mode, 1x
otherwise) and `get_ai_rate_limit()` (returns 2 in exam mode, 10 otherwise)
to implement two of those three claims. Neither function is called anywhere
else in the codebase. The only things actually wired to real behavior are
`enable_exam_mode`/`disable_exam_mode`/`get_exam_mode_status` (consumed by
`apps/governance/views.py`'s admin toggle endpoint and `core/health.py`'s
health-check surface) — flipping a Redis flag and reporting it back. Every
actual cache-TTL constant in the codebase
(`STUDENT/hbec_backend/apps/curriculum/views.py::CURRICULUM_CACHE_TTL_SECONDS`,
`apps/practice/artifact_content.py::CONTENT_TTL_SECONDS`/`SUMMARY_TTL_SECONDS`,
`apps/accounts/payments_client.py::AUTHORITY_CACHE_SECONDS`) is a bare
constant with no reference to `get_cache_ttl_multiplier()` at all, and no AI
endpoint's rate limiting reads `get_ai_rate_limit()` either.

## Symptoms
None yet reported by a user — this is a documentation/implementation drift
found by code inspection, not a live incident. The externally visible risk:
an admin (or a future engineer trusting the docstring) who enables Exam Mode
during a real exam period, expecting curriculum/practice caches to hold
6x longer and AI endpoints to throttle down to 2 req/min, gets neither —
cache TTLs and AI rate limits stay exactly as they are on a normal day, with
no error or signal that the "effect" didn't happen.

## Environment Details
- **Services Affected:** `STUDENT/hbec_backend` — `core/exam_mode.py`,
  `apps/curriculum/views.py`, `apps/practice/artifact_content.py`,
  `apps/accounts/payments_client.py`, `apps/governance/views.py`,
  `core/health.py`
- **Time First Observed:** 2026-09-16, during a read-only survey of every
  Redis/cache touchpoint in the monorepo for a caching-architecture scoping
  initiative (unrelated primary task).

## Investigation Steps

### 1. Initial Diagnosis
While cataloguing every cache-TTL constant in the Student Backend for the
survey, `core/exam_mode.py` surfaced via its own module docstring's claim
that Exam Mode affects cache TTLs system-wide — worth checking since the
survey's whole point was "what actually controls each cache's TTL."

### 2. Root Cause Analysis
```bash
grep -rn "get_cache_ttl_multiplier" STUDENT/hbec_backend --include="*.py"
# → only the definition itself, core/exam_mode.py:230

grep -rn "get_ai_rate_limit" STUDENT/hbec_backend --include="*.py"
# → only the definition itself, core/exam_mode.py:225 (plus its own
#   docstring/comment)

grep -rln "exam_mode\|is_exam_mode_enabled" STUDENT/hbec_backend --include="*.py" | grep -v test
# → apps/governance/views.py (enable/disable/status endpoint only)
# → core/health.py (status display only)
# → core/exam_mode.py (the module itself)
```
Confirmed both functions are unreferenced outside their own definitions, and
confirmed independently that none of the three real cache-TTL constants in
the codebase (`CURRICULUM_CACHE_TTL_SECONDS`,
`CONTENT_TTL_SECONDS`/`SUMMARY_TTL_SECONDS`, `AUTHORITY_CACHE_SECONDS`) or
any DRF throttle class reads `is_exam_mode_enabled()` or either multiplier
function.

### 3. Key Findings
- `enable_exam_mode`/`disable_exam_mode`/`get_exam_mode_status` are fully
  wired (admin toggle in `apps/governance/views.py`, surfaced in
  `core/health.py`'s health check) — only the two "effect" functions the
  docstring promises are unused.
- This is the caching-architecture-initiative equivalent of the dev-log's
  usual "two independent computations disagreeing" pattern, except here it's
  "one documented computation that nothing ever calls" — the contract the
  module promises (§ "8 questions every cached entity must answer": staleness
  tolerance changes in exam mode) doesn't hold for any real cache.

## Root Cause
`get_cache_ttl_multiplier()` and `get_ai_rate_limit()` were written as part
of `core/exam_mode.py`'s intended feature set but never actually plumbed
into any cache-TTL constant or rate-limit check elsewhere in the codebase —
an incomplete feature, not a regression (git blame not checked this session
to confirm whether the callers were ever written and later removed, or
never written at all).

## Prevention / Rule
**Guardrail:** A cache-TTL constant that is meant to vary with a runtime
condition (exam mode, load, etc.) should be a function call
(`get_curriculum_cache_ttl()`) rather than a bare module-level constant, so
"does this actually consult exam mode" is visible at the call site instead
of requiring a cross-file trace to discover it doesn't. Short of that, a
docstring that claims a system-wide effect should be treated the same as any
other testable contract — a smoke test that enables Exam Mode and asserts at
least one real cache/rate-limit value actually changed would have caught
this the moment it was written.

## Solution

### Immediate Fix
Not applied — this was found during a read-only research/scoping task with
an explicit no-code-changes constraint.

### Long-term Fix
Either wire `get_cache_ttl_multiplier()`/`get_ai_rate_limit()` into the real
cache-TTL constants and AI rate-limit checks they were written for, or —
if Exam Mode's cache/rate-limit effects are no longer wanted — update the
module docstring to state plainly that only the toggle and its status
reporting are implemented, so the next reader doesn't assume otherwise.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — `core/exam_mode.py`'s module docstring, to
      match actual behavior (or the code, to match the docstring)
- [ ] Code changes required — wire the two multiplier functions into real
      call sites, or remove/relabel them as not-yet-implemented

## Related Issues
- None yet filed.

## References
- `STUDENT/hbec_backend/core/exam_mode.py:1-9` (module docstring),
  `:225-232` (`get_ai_rate_limit`, `get_cache_ttl_multiplier`)
- `STUDENT/hbec_backend/apps/curriculum/views.py:32`
  (`CURRICULUM_CACHE_TTL_SECONDS`)
- `STUDENT/hbec_backend/apps/practice/artifact_content.py:16-17`
  (`CONTENT_TTL_SECONDS`, `SUMMARY_TTL_SECONDS`)
- `STUDENT/hbec_backend/apps/accounts/payments_client.py:26`
  (`AUTHORITY_CACHE_SECONDS`)
- `STUDENT/hbec_backend/apps/governance/views.py`,
  `STUDENT/hbec_backend/core/health.py` — the only real consumers of
  `core.exam_mode`

---

**Resolved By:** Not yet resolved — found by Claude Sonnet 5 during a
read-only caching-architecture research pass; fix deferred to a follow-up
session with code-change scope.
**Time to Resolution:** N/A (investigation only)

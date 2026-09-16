# Wired Exam Mode's Cache-TTL/AI-Rate-Limit Multipliers Into Real Enforcement, and Replaced Harness Cache's Assert Guards With RuntimeError

**Date:** 2026-09-16
**Project:** HBEC
**Environment:** Development, deployed to Staging
**Severity:** Medium (Exam Mode's two documented effects silently did nothing; the assert guards were a latent risk under `-O`, not an active bug)
**Status:** Resolved

## Summary
Two previously-logged, not-yet-fixed findings from the same day's
caching-architecture audit:

1. `STUDENT/hbec_backend/core/exam_mode.py`'s `get_cache_ttl_multiplier()`
   and `get_ai_rate_limit()` were fully implemented and correctly computed
   6x/2x values during Exam Mode, but had zero callers anywhere in the
   codebase — enabling Exam Mode never actually widened any cache TTL or
   tightened any AI rate limit, despite the module's own docstring claiming
   both.
2. `AGENTIC_HARNESS/app/shared/cache.py`'s four pipeline helpers guarded
   `_redis is not None` with a bare `assert`, which the project's own
   standing rule (`HBEC/CLAUDE.md`: "Replace `assert` with `RuntimeError` in
   production paths — assertions are stripped with `-O`") already flags as
   unsafe for a production path.

Rather than either wiring the two exam-mode functions in shallowly or
deleting them, investigated how much real enforcement work "wiring them in"
would actually take before choosing: cache-TTL wiring was a same-shape,
6-call-site change (multiply an existing constant at each `cache.set` call);
AI rate-limit enforcement turned out to be similarly small once found that
the AI-generation endpoints had no dedicated throttle at all (only the
generic 300/min default), and the codebase already had two working examples
of a custom `SimpleRateThrottle` subclass to copy the shape from
(`PasswordResetEmailThrottle`, `InternalServiceThrottle`).

## Symptoms
None live — both findings were identified by code inspection during the
caching-architecture audit, not a user report.

## Environment Details
- **Services Affected:** `STUDENT/hbec_backend` (`core/exam_mode.py`,
  `apps/curriculum/views.py`, `apps/practice/artifact_content.py`,
  `apps/ai_gateway/views.py`, new `apps/ai_gateway/throttles.py`),
  `AGENTIC_HARNESS` (`app/shared/cache.py`)
- **Time First Observed:** 2026-09-16 (both originally logged the same day
  by an earlier research pass; this entry covers the actual fix)

## Investigation Steps

### 1. Initial Diagnosis
Both findings were already fully root-caused in prior dev-log entries
(`HBEC-2026-09-16-exam-mode-cache-ttl-and-ai-rate-limit-multipliers-never-wired-in.md`
and `HBEC-2026-09-16-harness-cache-pipeline-helpers-use-assert-not-runtimeerror.md`) —
this session picked up the "not yet fixed" status on both.

### 2. Root Cause Analysis
Before wiring the AI rate limit in, checked whether AI endpoints had any
existing throttle infrastructure to hook into (`grep` across
`config/settings/base.py` and `apps/ai_gateway/views.py`): confirmed every
AI-generation view relied solely on the project-wide `UserRateThrottle`
default (300/min), with no AI-specific scope. Two existing custom
`SimpleRateThrottle` subclasses elsewhere in the codebase
(`apps/accounts/throttles.py::PasswordResetEmailThrottle`,
`apps/internal/views.py::InternalServiceThrottle`) confirmed the pattern for
a dynamic-rate throttle was already established, just never applied to AI
endpoints.

### 3. Key Findings
- Exam Mode's third documented effect ("Admin throttling — reduced writes
  to preserve IO for students") was never implemented anywhere at all, not
  even as dead code — confirmed via a repo-wide grep. Left explicitly
  unwired (a genuinely separate, cross-service feature — admin write
  throttling would need to live in `ADMIN/adminBackend`, not here) but
  corrected the module docstring to stop claiming it as an existing effect.
- DRF's `SimpleRateThrottle.__init__` calls `self.get_rate()` fresh on every
  request (a new throttle instance per request, per `APIView.get_throttles()`),
  so overriding `get_rate()` to consult `get_ai_rate_limit()` applies the
  current Exam Mode state on every single request with no caching/invalidation
  concern of its own — it delegates that entirely to `is_exam_mode_enabled()`'s
  existing Redis read.

## Root Cause
1. Exam Mode's cache-TTL and rate-limit "effects" were written as pure
   functions but never plumbed into any real cache-TTL constant or
   rate-limit enforcement point — an incomplete feature.
2. The harness cache guards used `assert`, which `python -O` strips
   entirely, silently turning a defensive "Redis not initialised" guard
   into no guard at all in that mode.

## Prevention / Rule
**Guardrail (exam mode):** A cache-TTL value meant to vary with a runtime
condition should be a function call visible at the call site
(`curriculum_cache_ttl()`), not a bare constant — matches the guardrail
already proposed in the original finding's dev-log entry. Applied to all
three affected TTL constants.

**Guardrail (assert):** Already-standing project rule; this closes the one
remaining violation found in the harness's cache module.

## Solution

### Immediate Fix
1. **`STUDENT/hbec_backend/apps/curriculum/views.py`** — added
   `curriculum_cache_ttl()`, replacing all 4 `cache.set(..., CURRICULUM_CACHE_TTL_SECONDS)`
   call sites with `cache.set(..., curriculum_cache_ttl())`.
2. **`STUDENT/hbec_backend/apps/practice/artifact_content.py`** — added
   `_content_ttl()`/`_summary_ttl()`, same pattern, 2 call sites.
3. **`STUDENT/hbec_backend/apps/ai_gateway/throttles.py`** (new) —
   `AIGenerationThrottle(UserRateThrottle)`, overrides `get_rate()` to
   return `f"{get_ai_rate_limit()}/min"`. Attached via `throttle_classes`
   to `GeneratePaperView`, `RemixPaperView`, `GenerateTargetedPaperView` —
   the three actual LLM-generation endpoints (left `SubmitMarkingView` on
   the generic default; marking wasn't part of Exam Mode's original claim
   and has a different cost/abuse profile).
4. **`STUDENT/hbec_backend/core/exam_mode.py`** — docstring corrected: names
   the two real consumers, and explicitly states admin write-throttling was
   never built rather than continuing to imply it exists.
5. **`AGENTIC_HARNESS/app/shared/cache.py`** — all four
   `assert _redis is not None, "..."` replaced with
   `if _redis is None: raise RuntimeError("...")`, same message, same
   condition, semantically identical under normal execution but no longer
   silently disabled under `-O`.
6. Tests: `apps/curriculum/tests/test_exam_mode_cache_ttl.py`,
   `apps/practice/tests/test_artifact_content_exam_mode.py`,
   `apps/ai_gateway/tests/test_throttles.py` (2 tests each, normal vs.
   Exam-Mode-enabled, mocking `core.exam_mode.is_exam_mode_enabled`). Full
   `apps/curriculum`, `apps/practice`, `apps/ai_gateway`, `apps/governance`
   suites (155 + 15 tests) re-run and passing.
7. Deployed to staging (`student-backend` + `harness` rebuilt, both healthy
   afterward); live-verified via Django shell: `get_cache_ttl_multiplier()`
   and `get_ai_rate_limit()` correctly flip from `1, 10` to `6, 2` while
   Exam Mode is enabled and back to `1, 10` once disabled, with staging left
   in its normal (disabled) state afterward.

### Long-term Fix
None needed — both fixes are complete for the scope found. Admin
write-throttling remains explicitly documented as not-yet-built rather than
silently mis-claimed.

## Prevention
- [x] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — `core/exam_mode.py` docstring corrected
- [x] Code changes required — done (see Solution)

## Related Issues
- `HBEC-2026-09-16-exam-mode-cache-ttl-and-ai-rate-limit-multipliers-never-wired-in.md`
  (original finding, now resolved by this entry)
- `HBEC-2026-09-16-harness-cache-pipeline-helpers-use-assert-not-runtimeerror.md`
  (original finding, now resolved by this entry)

## References
- `STUDENT/hbec_backend/apps/curriculum/views.py::curriculum_cache_ttl`
- `STUDENT/hbec_backend/apps/practice/artifact_content.py::_content_ttl,_summary_ttl`
- `STUDENT/hbec_backend/apps/ai_gateway/throttles.py::AIGenerationThrottle`
- `STUDENT/hbec_backend/core/exam_mode.py`
- `AGENTIC_HARNESS/app/shared/cache.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — fixed, tested, and deployed to
staging within the hour

# `make_verified_picture` let `RateLimitError` escape its own "never raises" contract

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (tier-2 picture engine, not yet in production)
**Severity:** Medium
**Status:** Resolved

## Summary
`make_verified_picture()`'s docstring guarantees "Never raises for a bad or
missing picture: the answer to 'no trustworthy picture' is no picture, and
the caller carries on without one." The function only caught
`ImageGenerationError` around its call to `call_image`, but `call_image` can
also raise `RateLimitError` (from `app/shared/rate_limiter.py`) when a
student is over their hourly image budget — before the provider loop even
starts. `RateLimitError` is not a subclass of `ImageGenerationError`, so it
propagated straight out of `make_verified_picture`, contradicting the
function's own stated contract and crashing any caller that didn't
separately handle it.

## Symptoms
Not yet observed in production — caught in code review of PR #156, before
this code path saw real traffic. Had it shipped, a student hitting their
hourly picture rate limit while a tier-2 (model-drawn) picture was requested
would have raised an unhandled exception instead of silently getting no
picture, which is what every other failure mode in this function already does.

## Environment Details
- **Server/Host:** Agentic Harness, `app/shared/verified_picture.py`
- **Services Affected:** tier-2 picture engine (`make_verified_picture`),
  called wherever a heritage scene or story picture is requested for a
  student
- **Related Components:** `app/shared/image_client.py` (`call_image`,
  raises both `ImageGenerationError` and lets `RateLimitError` propagate from
  `check_rate_limit`), `app/shared/rate_limiter.py` (`RateLimitError`)
- **Time First Observed:** 2026-11-18, during code review

## Investigation Steps

### 1. Initial Diagnosis
Code review traced every exception `call_image` can raise against what
`make_verified_picture` actually catches around it.

### 2. Root Cause Analysis
`call_image` calls `check_rate_limit` before attempting any provider; a
failed check raises `RateLimitError` directly, not wrapped in
`ImageGenerationError`. `make_verified_picture`'s `except ImageGenerationError`
clause therefore never matches it.

### 3. Key Findings
- `RateLimitError` and `ImageGenerationError` are unrelated exception classes
  (no shared base beyond `Exception`), so catching one does not catch the other.
- Every *other* failure path in `make_verified_picture` (an unreadable check,
  a refused verdict, exhausting `MAX_DRAWS`) already degrades to `None` —
  this was the one path that didn't.

## Root Cause
The except clause was written against the one exception type the author had
directly in mind (`ImageGenerationError`, from the drawing call itself)
without accounting for every exception type the same call can actually raise
(`RateLimitError`, from the rate-limit check that runs first inside it).

## Prevention / Rule
**Guardrail:** a function whose docstring promises "never raises" needs a test
that actually exercises every exception type its own dependencies can throw,
not just the one the author was thinking about. For this function
specifically, a unit test that mocks `call_image` to raise `RateLimitError`
and asserts `make_verified_picture` returns `None` (not an exception) closes
this permanently.

## Solution

### Immediate Fix
```python
from app.shared.rate_limiter import RateLimitError
...
except (ImageGenerationError, RateLimitError) as exc:
    logger.warning("verified_picture_draw_failed", draw=draw, error=str(exc)[:200])
    return None
```

### Long-term Fix
Add the unit test described in the guardrail above.

## Prevention
- [ ] Add a unit test mocking `call_image` to raise `RateLimitError` and
      asserting `make_verified_picture` returns `None`
- [x] Code changes required (done)

## Related Issues
- Found during code review of PR #156 (`feat/verified-pictures`), alongside a
  dangling doc reference to `research/semantic/picture_engine.md` — which
  turned out to already be resolved by PR #155 (`feat/picture-engine`)
  creating that exact file; no action needed there.

## References
- `app/shared/rate_limiter.py` (`RateLimitError`, `check_rate_limit`)
- `app/shared/image_client.py` (`call_image`)

---

**Resolved By:** Claude Sonnet 5 (agent session, on behalf of tinomupezeni)
**Time to Resolution:** Same session as discovery

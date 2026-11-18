# A transient LLM outage could starve a topic's picture for a week

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in `/code-review` of PR #158, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`cover_brief`/`question_brief` caught `(LLMUnavailableError, RateLimitError)`
and returned `None` - the exact same return value used when the model
genuinely judges a topic or question as having nothing worth drawing.
`picture_store._make` cannot tell the two apart, so an outage at the moment a
topic's cover (or a question's picture) is first requested got written as
`status="refused", reason="nothing worth drawing for this"` and then protected
by the 7-day `RETRY_REFUSED` no-retry window - even though the LLM might have
recovered seconds later.

## Symptoms
- No live incident; found by code review reading the exception handling
  against `picture_store`'s retry-timing comment ("a `refused` one is tried
  again only after `RETRY_REFUSED`").
- Would show as a topic or question with no picture for up to 7 days after a
  brief outage, indistinguishable in the stored `reason` from a genuine
  curator "no".

## Environment Details
- **Server/Host:** n/a (unit-level, harness backend)
- **Services Affected:** AGENTIC_HARNESS picture generation (covers,
  question pictures)
- **Related Components:** `app/shared/picture_briefs.py` (`cover_brief`,
  `question_brief`), `app/shared/picture_store.py` (`_make`)
- **Time First Observed:** 2026-11-18, code review

## Investigation Steps

### 1. Initial Diagnosis
Both functions' `except (LLMUnavailableError, RateLimitError)` blocks ended
in `return None`, same as the ordinary "the model said no" path a few lines
later in each function.

### 2. Root Cause Analysis
`picture_store._make` already has a generic `except Exception` handler that
records `reason=f"failed: {type(exc).__name__}"` - distinct from "nothing
worth drawing for this" - but it never saw this failure, because `None` was
returned instead of letting an exception propagate.

### 3. Key Findings
- The existing test (`test_no_model_means_no_picture_not_an_error`) actively
  asserted the old, wrong behaviour (`await _ask() is None` for an outage),
  so it had to be rewritten alongside the fix, not just extended.

## Root Cause
An infra failure and a genuine content judgement shared one return value
(`None`), so the caller downstream - which does have a separate, already-built
path for distinguishing failures (the generic exception handler) - never got
the chance to use it.

## Prevention / Rule
**Guardrail:** added `BriefUnavailableError`, raised (not returned) for the
outage case in both `cover_brief` and `question_brief`. `picture_store._make`
needed no change at all: its existing generic exception handler already
records a distinct `reason` (`failed: BriefUnavailableError`) the moment the
exception is allowed to reach it. The rule going forward: a brief-writing
function's "nothing to draw" and "could not even ask" paths must never share
a return value - one is content judgement (remembered for `RETRY_REFUSED`),
the other is infrastructure (an operator needs to tell them apart in logs).

## Solution

### Immediate Fix
Raise `BriefUnavailableError` instead of returning `None` in both functions'
outage handlers; updated both docstrings to say so. Rewrote the test that had
pinned the old behaviour into
`test_an_outage_is_distinguished_from_a_genuine_refusal`.

### Long-term Fix
Kept deliberately minimal per the review's own note: retry *timing* for the
distinguished outage case (e.g. retrying sooner than 7 days) was not changed,
since `picture_store`'s retry constants are shared load-bearing state this
fix did not need to touch to satisfy the actual report (an operator being
able to tell the difference in the stored `reason`). A follow-up could add a
shorter retry window keyed off this specific failure mode if it proves
needed in practice.

## Prevention
- [x] Code changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Found alongside 5 other picture-engine bugs in the same `/code-review` of
  PR #158 - see the sibling entries dated the same day.

## References
- `AGENTIC_HARNESS/app/shared/picture_briefs.py`
- `AGENTIC_HARNESS/app/shared/picture_store.py`
- `AGENTIC_HARNESS/tests/shared/test_picture_briefs.py`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session

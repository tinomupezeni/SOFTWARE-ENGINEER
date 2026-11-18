# A picture's rate-limit charge landed on every concurrent request, not just the one that started it

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in `/code-review` of PR #158, before merge)
**Severity:** High
**Status:** Resolved

## Summary
`picture_store.request_picture()` asked the caller's `may_start()` (the
student's 20/hour `picture` rate limit) *before* the compare-and-swap that
decides which of several concurrent requests actually gets to start drawing a
new picture. Two requests racing for the same brand-new or stale/offered
picture key (a React double-mount, two open tabs, a retried POST) could both
be charged against the quota even though only one of them ever started a
draw — the other's charge bought nothing.

## Symptoms
- No live incident; found by code review reading the ordering of
  `may_start()` against the CAS update / unique-key insert.
- Theoretical failure: a student on a flaky connection retrying the same
  request could see `limited` sooner than their real usage justified.

## Environment Details
- **Server/Host:** n/a (unit-level, harness backend)
- **Services Affected:** AGENTIC_HARNESS picture generation (covers,
  questions, conversation pictures - every caller of `request_picture`)
- **Related Components:** `app/shared/picture_store.py`
- **Time First Observed:** 2026-11-18, code review

## Investigation Steps

### 1. Initial Diagnosis
`request_picture` checked for an existing fresh row, then called
`await may_start()` unconditionally for any request that would attempt to
start one, and only *after* that attempted the CAS/insert that actually
decides the winner.

### 2. Root Cause Analysis
The CAS (`update ... where key=... and updated_at=row.updated_at`) and the
unique-key insert are the only things that decide which concurrent request
"wins" and gets to draw. Charging the rate limit before that point charges
every contender, not just the winner.

### 3. Key Findings
- The existing test `test_the_limit_is_asked_only_when_a_picture_would_start`
  only exercised the *sequential* case (one request, then a second against an
  already-"making" row that returns early with no `may_start` call at all) -
  it never exercised two requests racing for the *same brand-new* key, which
  is exactly where the double-charge happens.

## Root Cause
The rate-limit check ran before the race that determines the winner, so a
losing request was charged for a picture it never started.

## Prevention / Rule
**Guardrail:** `may_start()` is now called only after this request has
already won the CAS/insert; a losing request returns `"making"` (as before)
having never been charged at all. A request that wins the claim but then
fails the rate check explicitly reverts the row to its pre-claim state (or
deletes it, if newly inserted) before answering `"limited"`, so the claim
itself is never left stuck on a request that will not proceed.

Any future change to `request_picture`'s claim logic must keep the ordering
"claim first, charge the winner only" - a reviewer checking this file should
treat `may_start()` appearing before the CAS/insert as a regression.

## Solution

### Immediate Fix
Restructured `request_picture`: CAS/insert happens first; `may_start()` is
asked only for the request that wins it; a denial reverts the claim
(`UPDATE ... SET status=<previous>` or `DELETE`) before returning `limited`.

### Long-term Fix
None needed; this is the correct ordering for the invariant the function
already documented ("a rate limit belongs there, so a page polling for a
picture under way is never charged for asking" - extended to "and a page
that lost the race to start one too").

## Prevention
- [x] Code changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Found alongside 5 other picture-engine bugs in the same `/code-review` of
  PR #158 - see the sibling entries dated the same day.

## References
- `AGENTIC_HARNESS/app/shared/picture_store.py`
- `AGENTIC_HARNESS/tests/shared/test_picture_store.py`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session

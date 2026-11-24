# Editing a job's trade while MATCHED doesn't re-validate the matched worker

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Low
**Status:** Workaround Applied (flagged, not fixed — architectural)

## Summary
`UpdateJobRequestUseCase` allows changing a job's `trade` while it's in
`MATCHED` status without re-validating the already-matched worker
candidate's skill/trade eligibility, which is normally only checked later,
at booking time, by `BookJobUseCase`.

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- A job reaches `MATCHED` with a worker selected for its original trade;
  the buyer edits the job's trade while still `MATCHED`; the UI keeps
  showing the now-mismatched worker as matched until the buyer attempts to
  book, at which point booking fails with an unexplained
  `ValidationConflictError`.

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** `PATCH /jobs/{job_id}` while a job is `MATCHED`
- **Related Components:** `backend/app/apps/jobs/domain/services.py`
  (`UpdateJobRequestUseCase`, `BookJobUseCase`)
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 noted the edit use case permits trade
changes in `MATCHED` status without any eligibility re-check.

### 2. Root Cause Analysis
Confirmed `BookJobUseCase` is the only place that validates a worker's
trade/skill match, and it runs at booking time, not at edit time — so a
trade edit on a `MATCHED` job can silently invalidate the existing match
without surfacing anything until the buyer tries to book.

### 3. Key Findings
- This is a UX/consistency gap rather than a security or data-integrity
  bug: the eventual booking attempt does fail safely, just late and with
  an unhelpful error.

## Root Cause
Trade-change validation and match-eligibility validation live in two
different use cases that don't share logic, so editing in a state
(`MATCHED`) that depends on a preserved invariant doesn't re-check that
invariant.

## Prevention / Rule
**Guardrail:** this is left open for the team to decide the right shape —
either block trade edits once a job is `MATCHED` (revert to `REQUESTED`
first), or have the edit use case re-run the same trade/skill eligibility
check `BookJobUseCase` does and surface a clear error immediately.

Flagged as a PR review comment on #14 rather than fixed directly.

## Solution

### Immediate Fix
None — left as-is in PR #14; posted as a review comment.

### Long-term Fix
Pick one of the two options above and apply it consistently.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (pending author decision on PR #14)

## Related Issues
- GitHub PR Rest-creator/MARITCHO#14

## References
- PR review comment: https://github.com/Rest-creator/MARITCHO/pull/14#issuecomment-7132925942

---

**Resolved By:** Flagged by Claude Code (code review), left open pending team decision
**Time to Resolution:** N/A — open

# Switching pricing_mode away from AFTER_VISIT left a stale budget estimate

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Low
**Status:** Resolved

## Summary
`UpdateJobRequestUseCase`'s budget-clearing logic only cleared
`budget_amount` when a job's `pricing_mode` *was* (or became)
`AFTER_VISIT`. Switching a job that already carried an `AFTER_VISIT` on-site
estimate to `NEGOTIABLE` (or `FIXED` without supplying a new
`budget_amount`) left the stale estimate in place unexamined, so it
silently became the new budget under the new pricing mode.

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- A job created as `AFTER_VISIT` with an on-site estimate of $50, then
  PATCHed to `pricing_mode: "NEGOTIABLE"` without `budget_amount` in the
  body, would carry the $50 estimate over as the new negotiable budget
  shown to workers.

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** `PATCH /jobs/{job_id}`
- **Related Components:** `backend/app/apps/jobs/domain/services.py`
  (`UpdateJobRequestUseCase`)
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 flagged the `elif job.pricing_mode ==
AFTER_VISIT: job.budget_amount = None` branch as only covering the
"entering AFTER_VISIT" direction.

### 2. Root Cause Analysis
Traced the budget-clearing `if/elif` block: it keyed off the job's
*current* `pricing_mode` after the mutation, which only matches
`AFTER_VISIT`, so a transition out of `AFTER_VISIT` (where the stale value
is actually the problem) was never caught.

### 3. Key Findings
- The bug was one-directional: entering `AFTER_VISIT` correctly cleared the
  budget, but leaving it did not.

## Root Cause
The clearing condition checked the post-mutation pricing mode instead of
detecting the transition itself, so it only handled one of the two
directions where a stale budget value becomes misleading.

## Prevention / Rule
**Guardrail:** track whether `pricing_mode` actually changed in this patch
(`pricing_mode_changed`), and clear `budget_amount` whenever it changed and
no new `budget_amount` was supplied in the same request — regardless of
which direction the change went.

## Solution

### Immediate Fix
Added a `pricing_mode_changed` flag and extended the clearing condition to
`job.pricing_mode == AFTER_VISIT or pricing_mode_changed` in
`backend/app/apps/jobs/domain/services.py`.

### Long-term Fix
None further needed; covered by the immediate fix.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done, commit 319e337)

## Related Issues
- GitHub PR Rest-creator/MARITCHO#14

## References
- Commit 319e337 on branch `experimental`

---

**Resolved By:** Claude Code (code review + fix)
**Time to Resolution:** Same session

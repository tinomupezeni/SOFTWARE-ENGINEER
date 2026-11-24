# Job repository save() overwrites all fields with no optimistic lock

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Medium
**Status:** Workaround Applied (flagged, not fixed — architectural)

## Summary
PR #14 widened `SqlAlchemyJobRepository.save()` to unconditionally overwrite
every mutable `Job` field (trade, suburb, address, landmark_narrative,
latitude, longitude, problem_description, problem_photo_url, budget_amount,
needed_by, pricing_mode) from the in-memory entity, with no
optimistic-locking/version check. Several pre-existing use cases
(`BookJobUseCase`, `SubmitQuoteUseCase`, `CompleteJobUseCase`,
`RaiseDisputeUseCase`, `RespondToDisputeUseCase`) load a `Job` early in their
own transaction and only intend to change one or two status/money fields,
but their later `save()` call now re-persists their stale in-memory copy of
every other field too.

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- No test currently exercises the concurrent-edit race.

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** All Job mutation use cases that call `save()`
- **Related Components:** `backend/app/apps/jobs/infrastructure/repositories.py`,
  the five use cases listed above
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 flagged the widened `save()` as touching
every field rather than only the ones a given use case sets.

### 2. Root Cause Analysis
Read `save()`'s diff: it now assigns all mutable fields from the entity
unconditionally, rather than only the fields the calling use case changed.
Cross-referenced the five other use cases that call `save()` and confirmed
each loads the Job at the top of its transaction and could race with a
concurrent `PATCH /jobs/{id}`.

### 3. Key Findings
- A buyer's PATCH to suburb/budget_amount/pricing_mode can be silently
  reverted if another in-flight request (e.g. `BookJobUseCase`) loaded the
  same Job earlier and calls `save()` later with its stale snapshot.
- No error surfaces to either caller; the data loss is silent.

## Root Cause
`save()` was changed from a targeted field update to a full-entity
overwrite without adding any concurrency guard (version column, dirty-field
tracking, or compare-and-swap).

## Prevention / Rule
**Guardrail:** this is an open architectural decision, not a drop-in fix —
left for the team to choose between (a) `save()` diffing only fields the
calling use case actually changed, or (b) adding a `version`/`updated_at`
optimistic-lock column that `save()` checks and bumps, rejecting stale
writes.

Flagged as a PR review comment on #14 rather than fixed directly, since
either option is a cross-cutting repository-layer decision affecting six
use cases.

## Solution

### Immediate Fix
None — left as-is in PR #14; posted as a review comment asking the author
to pick a direction.

### Long-term Fix
Add optimistic locking (preferred, since it also protects future use
cases) or scope `save()` to only the fields the use case sets.

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

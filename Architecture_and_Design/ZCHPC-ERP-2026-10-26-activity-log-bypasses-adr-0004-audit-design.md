# PR #110 activity log reimplements the ADR-rejected app-level audit approach

**Date:** 2026-10-26
**Project:** ZCHPC-ERP
**Environment:** Development (PR, not merged)
**Severity:** Medium
**Status:** Investigating

## Summary
PR #110 ("Add activity log (audit trail)...") adds a custom, Django-ORM-level
`ActivityLog` model/service for recording business actions in the identity
module. The team had already decided (`docs/adr/0004-audit-trail.md`, on
`origin/master`) to use django-pghistory (Postgres triggers) plus an explicit
`BusinessEvent` table specifically *because* signal/ORM-level audit logging
can be bypassed by `queryset.update()`/bulk operations. PR #110's
`ActivityLog` has exactly that weakness, and this was not caught before an
existing reviewer comment on the PR flagged the ADR mismatch — the PR had
been retargeted/drafted in response to the base-branch/process part of that
comment, but the architecture conflict itself remains unaddressed in the
diff.

## Symptoms
- No runtime symptom yet (caught in code review, PR is still open/draft).
- Reviewer (richardmatsika-c) commented that the team "just decided on an
  approach for the audit trail" (ADR-0004: pghistory + BusinessEvent) and
  asked to discuss before review proceeds; the PR was retargeted from
  `main` to `master` and marked draft in response, but the model/service
  code itself was not reworked to match the ADR.

## Environment Details
- **Server/Host:** N/A (code review, local clone + GitHub PR)
- **Services Affected:** `erp_project/src/modules/identity` (new
  `ActivityLog` model/migration/service/view), consumed by
  `erp_project/src/modules/recruitment` (`job_service.py`,
  `application_service.py`)
- **Related Components:** `docs/adr/0004-audit-trail.md` (on
  `origin/master`, branch `mutsa`)
- **Time First Observed:** 2026-10-26, during requested review of PR #110

## Investigation Steps

### 1. Initial Diagnosis
Reviewed PR #110 diff and the one existing PR comment, which referenced an
ADR this repo state didn't show on `main`.

### 2. Root Cause Analysis
```bash
gh pr view 110 --json baseRefName,headRefName,isDraft,state,url
git show origin/master:docs/adr/0004-audit-trail.md
grep -ril "pghistory" --include="*.py" .   # no hits
```
Confirmed: ADR-0004 (status "Proposed", decided for Option C: pghistory +
BusinessEvent, explicitly rejecting Option A/B because "bypassed by
`queryset.update()`") exists on `origin/master`. No pghistory usage exists
anywhere in the codebase. PR #110's `ActivityLog` model
(`erp_project/src/modules/identity/infrastructure/persistence/models.py`)
overrides `save()`/`delete()` on the model instance to reject updates/
deletes, but a `ActivityLog.objects.filter(...).update(...)` or
`.filter(...).delete()` queryset call bypasses both overrides entirely —
there is no DB-level trigger or restricted role backing the "immutable"
claim in the model's docstring.

### 3. Key Findings
- The reviewer's architecture concern (ADR alignment) is unresolved in the
  current diff, even though the process concerns raised in the same comment
  (wrong base branch, needs draft status) were fixed.
- The implemented "append-only" guarantee is enforced only at the Python
  instance-method level, not at the database or queryset level — the same
  gap ADR-0004 used to rule out this class of design.
- No DB indexes exist for the query patterns the feature actually uses
  (`module`, `action`, `-timestamp` ordering), separate from but compounding
  the gap: this audit data path isn't shaped for the ADR's eventual
  retention/compliance query needs either.

## Root Cause
Feature work proceeded on an independent, ORM-level audit-log design before
confirming it matched the team's already-recorded architecture decision for
this exact capability (ADR-0004), so the PR reintroduced the specific
bypass weakness the ADR was written to avoid.

## Prevention / Rule
**Guardrail:** Before implementing any feature that already has an ADR in
`docs/adr/`, the PR description/checklist must link the relevant ADR and a
reviewer must verify the implementation satisfies that ADR's Decision
section — not just its surrounding process requirements (base branch,
draft status) — before the PR leaves draft.

This closes the gap because the root cause was treating the comment's
"retarget + add reviewer" instructions as satisfying the whole comment,
when the comment's substantive ask (ADR conformance) was the part that
actually needed code changes.

## Solution

### Immediate Fix
Filed PR review comment on #110 citing the ADR conflict, the bypassable
append-only guarantee, missing indexes, incomplete module wiring (identity's
own `user_service.py` create/update/delete are not logged despite the PR
title), and absence of tests. PR left open/draft pending author/reviewer
decision on whether to rework onto pghistory+BusinessEvent or keep this as
an interim mechanism.

### Long-term Fix
Pending team decision: either migrate `ActivityLog` onto django-pghistory +
`BusinessEvent` per ADR-0004, or formally amend the ADR if the simpler
approach is intentionally preferred for this subset of events.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update (PR review comment posted on #110)
- [ ] Code changes required (pending team decision on ADR vs. PR approach)

## Related Issues
- PR #110: https://github.com/tinomupezeni/ZCHPC-ERP/pull/110
- `docs/adr/0004-audit-trail.md` (origin/master)

## References
- https://github.com/tinomupezeni/ZCHPC-ERP/pull/110#issuecomment-6414917714

---

**Resolved By:** Reviewed by Claude (agent) for tinomupezeni
**Time to Resolution:** N/A — open, pending author/reviewer decision

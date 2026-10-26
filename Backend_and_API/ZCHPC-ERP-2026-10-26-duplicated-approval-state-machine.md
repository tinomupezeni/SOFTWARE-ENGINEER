# Same linear-approval state machine reimplemented 5+ times across modules

**Date:** 2026-10-26
**Project:** ZCHPC-ERP
**Environment:** Development (found during PR review, not yet merged)
**Severity:** Low
**Status:** Investigating

## Summary
PR #115 ("Feature/requisition and travel forms") adds `dsa_advance_review` and
`travel_expense_claim_review` as two near-verbatim ~85-line copy-pasted
stage-transition state machines in `portal/api/views.py`. The same
"linear approval chain" shape (validate current stage -> check actor
authorization -> transition status -> record reviewer/timestamp -> notify)
is independently reimplemented at least 5 times across the codebase:
`dsa_advance_review`, `travel_expense_claim_review`, `leave_request_review`,
`comparative_schedule_review`, and the procurement fuel/stores approval
functions. Authorization within each copy also relies on brittle
uppercase substring matching (e.g. `'DIRECTOR' in position`) rather than a
real role/permission lookup, duplicated the same way in at least 3 modules.

## Symptoms
- No functional bug observed yet — this is a maintainability/architecture
  finding from code review (guide 25: Continuous Codebase Simplification),
  not an incident.
- Risk: a future fix to the approval-chain logic (e.g. closing an
  authorization gap, changing notification behavior) has to be
  independently applied in 5+ places, and already has not been applied
  consistently (role checks differ slightly module to module).

## Environment Details
- **Server/Host:** N/A (pre-merge, PR #115 on branch
  `feature/requisition-and-travel-forms`)
- **Services Affected:** Django backend — `portal`, `procurement`, `hr`/leave
  modules
- **Related Components:** `portal/api/views.py` (`dsa_advance_review` ~line
  8751-8834, `travel_expense_claim_review` ~line 8921-9007),
  `leave_request_review`, `comparative_schedule_review`, procurement
  fuel/stores approve functions; `_approval_actor`/`_travel_actor` helpers
- **Time First Observed:** 2026-10-26, during PR #115 code review

## Investigation Steps

### 1. Initial Diagnosis
Guide-25 complexity/duplication pass on PR #115 (65 files, +9327/-994)
specifically looked for duplicated logic given the PR's size, per the
simplification discipline's instruction to seek concrete, cited evidence
rather than a generic "this looks big" complaint.

### 2. Root Cause Analysis
Diffed `dsa_advance_review` against `travel_expense_claim_review` in
`portal/api/views.py` and found both implement the same
validate -> authorize -> transition -> record -> notify shape almost
line-for-line, independently of `leave_request_review`,
`comparative_schedule_review`, and the procurement approve functions, which
follow the identical pattern again.

### 3. Key Findings
- 5+ independent copies of the same approval-chain shape across 3 modules
  (`portal`, `procurement`, `hr`/leave).
- Authorization checks in `_approval_actor`/`_travel_actor` and siblings use
  `'DIRECTOR' in position`-style uppercase substring matching on a free-text
  position/role string, duplicated across modules, instead of a real
  role/permission table lookup — brittle and a likely source of future
  authorization drift between copies.

## Root Cause
Each approval workflow (leave, comparative schedule, procurement fuel/stores,
DSA advance, travel expense) was built independently over time without
extracting the shared "staged approval chain" behavior into one reusable
service/mixin, so the same logic — and its authorization-check weaknesses —
had to be reinvented, and now drifts slightly, each time.

## Prevention / Rule
**Guardrail:** Before adding a new "staged approval" workflow, require (via
code-review checklist item, not tooling) that it extend a shared
`ApprovalChainService`/mixin rather than hand-roll validate/authorize/
transition/notify logic — and migrate the role/position authorization checks
off substring matching onto the existing capability/permission system already
used by `PayrollAuthorizationPolicy` (see
`erp_project/src/modules/payroll/application/authorization/policy.py`).

This directly targets the root cause: the duplication exists because there is
no shared abstraction to reach for, so each new workflow reinvents it instead
of extending one.

## Solution

### Immediate Fix
Not applied — flagged as a non-blocking `suggestion` comment on PR #115
(https://github.com/tinomupezeni/ZCHPC-ERP/pull/115) recommending
consolidation into a shared approval-chain abstraction, and recommending the
substring-based role checks be replaced with a real permission lookup.

### Long-term Fix
Extract a shared `ApprovalChainService` (or equivalent mixin) covering
validate -> authorize -> transition -> record -> notify, used by all five
current call sites, with authorization delegated to the existing
capability/permission system rather than string matching on position names.

## Prevention
- [ ] Configuration changes needed: none
- [ ] Monitoring/alerts to add: none
- [ ] Documentation to update: none yet — defer until consolidation is
      scheduled
- [ ] Code changes required: extract shared approval-chain service;
      replace substring role checks with permission-table lookups

## Related Issues
- PR #115 (https://github.com/tinomupezeni/ZCHPC-ERP/pull/115) — also has a
  migration default/choices bug logged separately:
  `Database_and_State/ZCHPC-ERP-2026-10-26-travel-authorisation-migration-invalid-status-default.md`

## References
- `erp_project/src/modules/portal/api/views.py` (`dsa_advance_review`,
  `travel_expense_claim_review`)
- `erp_project/src/modules/payroll/application/authorization/policy.py`
  (existing capability-based policy pattern to reuse)

---

**Resolved By:** Claude (code review agent)
**Time to Resolution:** N/A — found during review, consolidation deferred to
a follow-up

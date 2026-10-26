# Travel/DSA migration sets a model default outside the field's own choices

**Date:** 2026-10-26
**Project:** ZCHPC-ERP
**Environment:** Development (found during PR review, not yet merged/deployed)
**Severity:** Medium
**Status:** Investigating

## Summary
PR #115 ("Feature/requisition and travel forms") adds the Travel Authorisation /
DSA Advance workflow to the `portal` module. The migration that creates
`DSAAdvanceRequest` sets `status` to default `'PENDING_ACCOUNTING'`, a value
that is not present in that field's own `choices` list at the time the
migration was written. The mismatch is silently self-corrected two migrations
later, but the migration history itself carries a model/schema inconsistency.

## Symptoms
- No runtime failure observed yet (not deployed) — this is a static
  migration/model consistency defect found during code review, not an
  incident.
- Had it shipped as-is and a row been created before the corrective
  migration ran, `full_clean()`/admin/serializer validation against
  `choices` would reject the row's own default value.

## Environment Details
- **Server/Host:** N/A (pre-merge, PR #115 on branch
  `feature/requisition-and-travel-forms`)
- **Services Affected:** Django backend, `portal` module (Travel Authorisation
  / DSA Advance workflow)
- **Related Components:** `portal/migrations/0002_travelauthorisationrequest_dsaadvancerequest.py`,
  `portal/migrations/0003_...py`, `DSAAdvanceRequest` model
- **Time First Observed:** 2026-10-26, during PR #115 code review

## Investigation Steps

### 1. Initial Diagnosis
PR review (guide-24/25 pass) walked the new `portal` migrations added in
PR #115 for unsafe DDL and model/migration drift, per standard migration
review practice.

### 2. Root Cause Analysis
```bash
grep -n "PENDING_ACCOUNTING\|choices" erp_project/src/modules/portal/migrations/0002_travelauthorisationrequest_dsaadvancerequest.py
grep -n "PENDING_ACCOUNTING\|choices" erp_project/src/modules/portal/migrations/0003_*.py
```
- `0002_travelauthorisationrequest_dsaadvancerequest.py:19` sets
  `DSAAdvanceRequest.status`'s default to `'PENDING_ACCOUNTING'`, which is not
  one of the values declared in that field's `choices=` at that point in
  migration history.
- `0003_...py:16` corrects the field (adds the missing choice / fixes the
  default), but the intermediate migration state is internally inconsistent.

### 3. Key Findings
- The defect is in migration history, not the current model state — so
  `manage.py check` on current `HEAD` of the branch would not flag it.
- Indicates migrations were generated iteratively without squashing/cleanup
  before PR submission.

## Root Cause
A model field's `choices` list was extended/corrected after the initial
migration that set a default outside the original choices, and the two
migrations were never squashed, leaving an internally-inconsistent
intermediate migration state in history.

## Prevention / Rule
**Guardrail:** Add a CI check (e.g. a pytest step or `manage.py` management
command) that walks each migration's `AddField`/`AlterField`/`CreateModel`
operations and asserts any literal `default=` for a `choices`-bearing field
is a member of that same operation's `choices` list, failing the build if not.

This directly targets the root cause — a default/choices mismatch introduced
in a single migration file — rather than relying on reviewers to manually
diff model `choices` against migration defaults by hand.

## Solution

### Immediate Fix
Not yet applied — flagged as a non-blocking `issue` comment on PR #115
(https://github.com/tinomupezeni/ZCHPC-ERP/pull/115) for the author to
squash/clean the migration before merge.

### Long-term Fix
Squash migrations 0002-0006 in the `portal` module (or at minimum correct
0002's default inline) before merge, and add the CI guardrail above.

## Prevention
- [ ] Squash or correct the `portal` migrations before PR #115 merges
- [ ] Add CI check for default/choices consistency across migration history
- [ ] Documentation to update: none
- [ ] Code changes required: migration squash/fix (author's responsibility)

## Related Issues
- PR #115 (https://github.com/tinomupezeni/ZCHPC-ERP/pull/115) — also has a
  duplication finding logged separately:
  `Backend_and_API/ZCHPC-ERP-2026-10-26-duplicated-approval-state-machine.md`

## References
- `erp_project/src/modules/portal/migrations/0002_travelauthorisationrequest_dsaadvancerequest.py`
- `erp_project/src/modules/portal/migrations/0003_*.py`

---

**Resolved By:** Claude (code review agent)
**Time to Resolution:** N/A — found during review, fix pending author action

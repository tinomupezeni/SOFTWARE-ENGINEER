# UpdateJobRequestUseCase silently ignored explicit null for required fields

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Medium
**Status:** Resolved

## Summary
`UpdateJobRequestUseCase` guarded `suburb`/`address`/`problem_description`
updates with `"field" in fields_set and field is not None`, so an explicit
`{"suburb": null}` in a PATCH body was silently ignored instead of rejected,
even though these are non-nullable required fields (enforced strictly by
`JobRequestCreate` on job creation).

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- `PATCH /jobs/{id}` with `{"suburb": null}` returned 200 OK but left the
  job's suburb unchanged, silently diverging from the documented
  non-nullable OpenAPI schema for these fields.

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** `PATCH /jobs/{job_id}`
- **Related Components:** `backend/app/apps/jobs/domain/services.py`
  (`UpdateJobRequestUseCase`)
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 flagged the `and field is not None` guards
as silently swallowing explicit nulls rather than rejecting them.

### 2. Root Cause Analysis
Read the use case's field-update block: `suburb`, `address`, and
`problem_description` each only mutate the entity when the field is both
present in `fields_set` *and* not `None`, so a client explicitly sending
`null` for one of these took the `"field" in fields_set` branch but the
value never applied, with no error raised either.

### 3. Key Findings
- `latitude`/`longitude`/`landmark_narrative`/`problem_photo_url` are
  correctly nullable and don't have this problem.
- Only the genuinely-required string fields were affected.

## Root Cause
Treating "field present in the patch" and "field has a non-null value" as
equivalent conditions for required fields, instead of distinguishing
"omitted" (leave unchanged) from "explicitly nulled" (reject, since the
field can't be empty).

## Prevention / Rule
**Guardrail:** for any non-nullable PATCH field, require the use case to
raise on `field in fields_set and value is None`, not silently skip the
update. A test case per required PATCH field asserting
`{"field": null}` returns a 4xx, not 200, closes this class of bug.

## Solution

### Immediate Fix
Changed each of the three guards in
`backend/app/apps/jobs/domain/services.py` to raise
`ValidationConflictError("<Field> cannot be cleared")` when the field is in
`fields_set` but the value is `None`, instead of silently no-op'ing.

### Long-term Fix
Consider a schema-level ("Required" vs "Optional" patch field) helper so
this guard is generated rather than hand-written per field going forward.

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

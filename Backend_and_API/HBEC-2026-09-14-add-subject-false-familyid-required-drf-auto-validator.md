# "Add Subject" Always Failed With a False `familyId: This field is required.`

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging (admin frontend not yet promoted to production)
**Severity:** High
**Status:** Resolved — verified live on staging

## Summary
Admins reported every "Add Subject" submission failing with `familyId:
This field is required.`, even when typing a brand-new subject name
(which correctly sends `familyName`, not `familyId` — the two are
intentionally mutually exclusive per `SubjectWriteSerializer`'s own
design). Traced to a genuine DRF gotcha: `ModelSerializer`
auto-generates a validator from every multi-field `UniqueConstraint` on
the model, and that validator forces every field it covers to be present
on create — completely overriding the individual fields' own
`required=False`, and running *before* the serializer's own custom
`validate()` method (which resolves `family` from `familyName`) ever got
a chance to run.

## Symptoms
- Every "Add Subject" submission, including the intended "type a new
  name" flow, failed with `{"familyId": ["This field is required."]}` —
  DRF's generic default message, not `SubjectWriteSerializer.validate()`'s
  own more descriptive one (`"Provide familyId (existing subject) or
  familyName (new subject)."`), which was the tell that this wasn't
  reaching the custom validation logic at all.

## Environment Details
- **Server/Host:** `ADMIN/adminBackend`, `apps/curriculum`
- **Services Affected:** the Add Subject dialog (`/subjects` page) —
  affects both the "type a new subject" and, less obviously, would also
  affect "pick an existing subject" once `gradeId` (also forced required
  by the same mechanism) hit the legacy `gradeLevels`-only path
- **Time First Observed:** 2026-09-14 (reported by the user); root cause
  is as old as the `SubjectFamily` split itself — every Add Subject
  submission has failed since that feature shipped

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the field itself is correctly declared:
```python
familyId = serializers.PrimaryKeyRelatedField(
    source="family", queryset=SubjectFamily.objects.all(),
    required=False, allow_null=True,
)
```
`s.fields['familyId'].required` printed `False` from a live shell — yet
`s.is_valid()` on the exact same instance still produced the "required"
error. Manually stepping through `to_internal_value()` succeeded cleanly
with no errors; the failure only appeared when calling the fuller
`run_validation()` (which `is_valid()` calls internally).

### 2. Root Cause Analysis
```python
s.run_validation(data)
# Traceback:
#   File ".../rest_framework/validators.py", line 174, in __call__
#     self.enforce_required_fields(attrs, serializer)
#   File ".../rest_framework/validators.py", line 138, in enforce_required_fields
#     raise ValidationError(missing_items, code='required')
```
This is DRF's auto-generated `UniqueTogetherValidator`, derived from
`Subject.Meta.constraints`:
```python
constraints = [
    models.UniqueConstraint(fields=["family", "grade"], name="uniq_subject_family_grade"),
    models.UniqueConstraint(fields=["exam_board", "grade", "code"], name="uniq_subject_examboard_grade_code"),
]
```
`ModelSerializer` auto-derives one of these validators per multi-field
constraint, and — this is the documented-but-easy-to-forget DRF
behavior — `enforce_required_fields()` forces *every field the
constraint covers* to be treated as required on create, regardless of
each field's own `required=False`. Both constraints here cover `family`
(→ `familyId`) and/or `grade` (→ `gradeId`), which are exactly the two
fields this serializer was deliberately designed to make optional
(resolved via `familyName`/legacy `gradeLevels` instead).

### 3. Key Findings
- The error text itself (DRF's generic default vs. this serializer's own
  custom message) was the direct clue that the failure happened *before*
  `validate()` ran, not inside it.
- This bug has been present since the `SubjectFamily` split shipped
  (commit `30f19a69`) — every single Add Subject submission through this
  endpoint has failed, which is consistent with the user describing it as
  a total blocker rather than an edge case.

## Root Cause
DRF's `ModelSerializer` auto-generates a `UniqueTogetherValidator` from
every multi-field `UniqueConstraint` declared on the model, and that
validator overrides each covered field's own `required=False` for
create requests — a behavior distinct from, and evaluated before, the
serializer's own `validate()` method.

## Prevention / Rule
**Guardrail:** Any time a `ModelSerializer`'s fields are deliberately
made optional (via `required=False`) to support a "resolve one of
several alternatives inside `validate()`" pattern, check whether any of
those fields also participate in a multi-field `Meta.constraints`
`UniqueConstraint` on the model — if so, explicitly set
`Meta.validators = []` (or scope down to just the validators that don't
conflict) on the serializer, since DRF's auto-generated validator will
silently force those fields required regardless of the explicit
declaration. A quick way to catch this class of bug going forward: any
serializer with `required=False` fields that also appear in
`Meta.constraints` deserves a direct create-request integration test
(not just a unit test of the field declaration), since the bug only
surfaces at the full `is_valid()`/`run_validation()` level, never at the
individual field level.

This closes the gap because the actual failure mode is DRF's own
validator-generation machinery operating independently of, and silently
overriding, explicit per-field configuration — something no amount of
scrutinizing the field declaration alone would catch.

## Solution

### Immediate Fix
Added `Meta.validators = []` to `SubjectWriteSerializer`, disabling the
auto-generated validators. Genuine duplicates are no longer caught at
the validator layer — instead, `IntegrityError` from the real DB
constraint is now caught in `SubjectListCreateView.create()` and
`SubjectDetailView.update()`, translated into the same kind of clean,
actionable 400 message the disabled validator would have given (now
matched by constraint name: `uniq_subject_family_grade` →
"already offered at this grade", `uniq_subject_examboard_grade_code` /
the legacy `unique_together` → "already used ... in this exam board").

6 new regression tests in `apps/curriculum/tests/test_subject_create_api.py`
cover: creating with a new `familyName`, with a legacy `gradeLevels`-only
grade, attaching to an existing `familyId`, the "neither provided" case
(confirms the *custom* message is now reached), and both real duplicate
scenarios (confirms the DB constraint still catches them with a friendly
message, not a raw 500).

Verified live on staging: `SubjectWriteSerializer` now validates cleanly
for the exact previously-failing payload, and a full end-to-end
`POST /api/curriculum/subjects/` through the real view created a real
subject + auto-created family + queued replication, then was cleaned up.

### Long-term Fix
None needed beyond the guardrail above.

## Prevention
- [x] Configuration changes needed — done (`Meta.validators = []` +
      `IntegrityError` handling)
- [ ] Monitoring/alerts to add — none planned
- [ ] Documentation to update — none yet
- [x] Code changes required — done, plus 6 new regression tests

## Related Issues
- Same general architecture as `HBEC-2026-09-13-...` curriculum-restructuring
  work (SubjectFamily split) — this is the first bug found in that feature
  since it shipped, and the reason it went unnoticed for this long is that
  no create-request-level test existed for it until now.

## References
- `ADMIN/adminBackend/apps/curriculum/serializers.py` —
  `SubjectWriteSerializer`
- `ADMIN/adminBackend/apps/curriculum/views.py` —
  `SubjectListCreateView`, `SubjectDetailView`,
  `_subject_integrity_error_response`
- `ADMIN/adminBackend/apps/curriculum/models.py` — `Subject.Meta.constraints`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery (verified live on
staging; not yet promoted to production)

# Mutare Chishona labels appear in STEM because program and learning-area fields diverge

**Date:** 2026-11-07
**Project:** TESC
**Environment:** Production
**Severity:** High
**Status:** Workaround Applied

## Summary
Mutare Teachers College records that display `CHISHONA` on the STEM directory are not being classified as STEM because the stored learning area is Chishona. The STEM rule evaluates the separate `Student.learning_area` field, while the STEM directory displays `program_name`; the institution terminology then relabels that program column as “Learning Area.” This makes records with program name `CHISHONA` and STEM-valued `learning_area` appear to be Chishona STEM students.

## Symptoms
- Users see Mutare records labelled `CHISHONA` in the STEM directory.
- The same institution also contains rows where `learning_area=CHISHONA` but the program is `MATHEMATICS`.
- The displayed label and the field used for classification do not identify the same source value.

## Environment Details
- **Server/Host:** `tesc-prod`, green artifact `0a1a76d`
- **Services Affected:** STEM student directory and teacher-college student reporting
- **Related Components:** `academic.Student`, `academic.services.stem`, STEM endpoint, teacher-college terminology
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
Queried production data for Mutare Teachers College (`institution_id=82`) and compared the exact STEM predicate with `program_name`, `learning_area`, and `selected_category`.

### 2. Root Cause Analysis
```bash
docker exec backend-green python manage.py shell
```

### 3. Key Findings
- Mutare has 3,053 students matching the STEM endpoint predicate.
- Zero Mutare records with stored `learning_area` containing `SHONA` match that predicate.
- 591 STEM-matching rows have `program__name=CHISHONA`; their stored `learning_area` values are STEM subjects such as Mathematics, Computer Science, and Geography.
- Separately, 263 rows have stored `learning_area=CHISHONA`; those rows do not match the STEM predicate, but 80 are attached to a `MATHEMATICS` program, showing source-data field divergence.
- Production contains Mutare placeholder programs `CHISHONA (2YEAR)` and `MATHEMATICS (3YEAR)`, both created on 2026-09-12. The upload service explicitly documents that duration-like codes from Mutare created these programs and funnelled unrelated subjects onto them.
- `auto_stem_category()` classifies teachers-college rows from `Student.learning_area`, while `stem_students()` serializes `program_name`.
- The frontend teacher-college terminology maps “Program” to “Learning Area,” hiding the distinction.

## Root Cause
The Mutare upload used duration labels as program codes, so the importer created placeholder programs and attached unrelated rows to them. The teacher-college data model then compounded this with two competing subject-like fields: STEM classification uses `Student.learning_area`, but the STEM directory displays `program_name` and relabels it as “Learning Area.” The resulting contract mismatch presents a Chishona placeholder-program label as STEM when the STEM subject came from the separate learning-area field.

## Prevention / Rule
**Guardrail:** Define one canonical teacher-college subject field for classification and display, then add a validation check that rejects or quarantines uploads where `program_name` and `learning_area` represent conflicting subject values.

This prevents a display field from disagreeing with the field used by the STEM classifier and catches future shifted or semantically ambiguous uploads before they affect reports.

## Solution

### Immediate Fix
For Mutare Teachers College only, cleared `selected_category=STEM` from the 591 rows whose displayed program name was `CHISHONA`. Program names and learning-area values were not overwritten.

### Long-term Fix
Repair the Mutare rows from the original spreadsheet using validated program/subject mappings; do not infer replacements from the placeholder names alone. Keep the existing duration-code rejection in the upload path, and align the teacher-college upload contract, STEM classifier, API serializer, and frontend terminology around one canonical subject field.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Verification
- Before cleanup: 591 Mutare `CHISHONA` program rows matched STEM.
- After cleanup: 0 Mutare `CHISHONA` program rows match STEM.
- Mutare STEM total changed from 3,053 to 2,462.
- The update was limited to `institution_id=82` and `selected_category`; no program or learning-area text was changed.

## Related Issues
- None

## References
- `TESC/backend/academic/services/stem.py`
- `TESC/backend/academic/app_views/student_views.py`
- `TESC/inst/src/pages/StemStudents.tsx`
- `TESC/inst/src/hooks/useTerminology.ts`
- `TESC/backend/academic/services/student_services.py`

---

**Resolved By:** Copilot; scoped data workaround applied
**Time to Resolution:** Investigation session

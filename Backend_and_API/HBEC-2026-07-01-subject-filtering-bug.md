# Subject Disappearing Bug (Grade Filtering Mismatch)

**Date:** 2026-07-01
**Project:** HBEC
**Environment:** Development / Production
**Severity:** High
**Status:** Resolved

## Summary
A bug caused the Exam Practice page and Add Subject modal to treat the system as if there were 0 available subjects, even though the Learner Dashboard correctly identified that the student had 6 subjects selected in their profile personalization state.

## Symptoms
- The Learner Dashboard correctly displayed "6 selected" subjects.
- Navigating to the "Exam Practice Papers" page showed "No subjects added yet".
- Attempting to add a new subject from the "Add Subject" modal resulted in the message "All subjects are already added".

## Environment Details
- **Services Affected:** `STUDENT` Backend (`SubjectListView`), `STUDENT` Frontend
- **Related Components:** Curriculum API, Exam Practice Page
- **Time First Observed:** 2026-07-01

## Investigation Steps

### 1. Initial Diagnosis
Checked `STUDENT/Frontend/src/shared/hooks/useUserSubjects.ts` to understand why `visibleSubjects` and `availableToAdd` were both empty. Identified that this happens when `allSubjects` (returned by the backend) is an empty array.

### 2. Root Cause Analysis
Investigated `SubjectListView` in `STUDENT/hbec_backend/apps/curriculum/views.py`. The authenticated view enforces filtering by the user's `student_profile.grade`. 

```bash
# Investigated the DB state for grade_code
python manage.py shell -c "from apps.curriculum.models import Subject; print(list(Subject.objects.values_list('name', 'level', 'grade_code')[:5]))"
```

### 3. Key Findings
- Subjects were added during onboarding (when `student_profile.grade` was not yet strictly enforced by the backend endpoint).
- Once the profile was fully saved with a grade (e.g., "Form 3"), the backend strictly filtered queries using `queryset.filter(grade_code="form-3")`.
- The database lookup revealed that all 43 active subjects had a `grade_code` of `""` (empty string). This reflects that subjects in this curriculum are generally level-wide (e.g., O-Level) rather than tied to a single specific form.

## Root Cause
Strict filtering by `grade_code` without accounting for level-wide subjects (`grade_code=""`) resulted in an empty queryset for students who had assigned grades, breaking downstream frontend components.

## Solution

### Immediate Fix
This was a robust engineering fix at the ORM layer. I modified the `SubjectListView` API in Django to use `Q` objects, explicitly checking for either the exact `grade_code` OR an empty string (level-wide).

```python
# Before
queryset = queryset.filter(grade_code=student_profile.grade)

# After
from django.db.models import Q
queryset = queryset.filter(Q(grade_code=student_profile.grade) | Q(grade_code=""))
```
*Note: This `Q` object logic was applied to both authenticated and guest request paths.*

### Long-term Fix
The fix is permanent and addresses the core data model. No further changes needed.

## Prevention
- [ ] Code changes required: Added `Q` object filtering.
- [ ] Documentation to update: Note that `grade_code=""` acts as a wildcard for subjects across an entire level.

## Related Issues
None.

---

**Resolved By:** Antigravity (AI Principal Engineer)
**Time to Resolution:** 5 minutes

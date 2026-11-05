# Mutare Teachers College: 1,576 students (17% of the college) misattached to a placeholder "CHISHONA"/"2YEAR" program

**Date:** 2026-11-05
**Project:** TESC (ScalarEye)
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
Reported symptom: Mutare Teachers College students enrolled in the Shona
program were appearing in the STEM report. Investigation found this is one
visible symptom of a much larger data-integrity defect: a bulk upload at
some point in the past created a parentless placeholder `Program` row
(id 3088, name `"CHISHONA"`, code `"2YEAR"`, no department, faculty =
auto-created `"GENERAL FACULTY"` / department = `"GENERAL DEPARTMENT"`) and
attached 1,576 of Mutare's 9,426 students to it — 17% of the college's
entire student body — regardless of their actual subject. The students'
real subject survives only in the free-text `Student.learning_area` field:
Mathematics (328), History & Heritage Studies (499), English (227),
Accounting (96), Geography (181), Computer Science (82), and genuine
Chishona (163). The 591 Mathematics/Geography/Computer-Science students in
that bucket are correctly flagged `selected_category='STEM'` by subject
(see [[TESC-stem-classification]] if filed separately — classification
logic itself, in `backend/academic/services/stem.py`, is correct), which is
why they surface in the STEM report while their `program` field still
reads "Chishona" — the reported bug.

## Symptoms
- Students on what the UI shows as the "Shona" program appearing in the
  STEM students report.
- (Not yet reported, but present): the same college's History, English,
  Accounting, and genuine-Chishona students are also misattached to this
  same placeholder program, un-flagged, just less visible since they don't
  land in a report like STEM does.

## Environment Details
- **Server/Host:** tesc-prod (production database)
- **Services Affected:** `backend/academic/services/student_services.py`
  (bulk student upload), `backend/academic/services/ingestion_service.py`
  (specialized bulk uploads), `faculties_program` / `academic_student` tables
- **Related Components:** STEM/Specialized/Critical student reports
  (`StudentViewSet.stem_students` in `backend/academic/app_views/student_views.py`)
- **Time First Observed:** 2026-11-05, reported by user as a Shona/STEM
  mislabeling issue

## Investigation Steps

### 1. Initial Diagnosis
Ran a read-only Django-shell query against tesc-prod for Mutare's
Shona-named programs and the students enrolled in them. All of Mutare's
*correctly* named "Chishona" programs (ids 3980, 3991) carry
`categories=['HUMANITIES']` as expected — the program data itself is not
broadly mistagged.

### 2. Root Cause Analysis
```python
# read-only, run via: docker exec backend-blue python manage.py shell -c "..."
from academic.models import Student
Student.objects.filter(institution__name__icontains='Mutare', program__name__icontains='shona') \
    .values('id','student_id','learning_area','selected_category','program__name',
            'program__categories','institution__name')
```
591 of the matches had `program__name='CHISHONA'` (uppercase — a different
row than the two correctly-cased "Chishona" programs) with
`learning_area` values of `MATHEMATICS`, `COMPUTER SCIENCE`, or
`GEOGRAPHY AND ENVIRONMENTAL (STUDIES|MANAGEMENT)` — i.e. these students'
real subject has nothing to do with Shona. Pulling that program row
directly:
```python
Program.objects.filter(id=3088).values('id','name','code','categories','institution_id','institution__name','department_id')
# {'id': 3088, 'name': 'CHISHONA', 'code': '2YEAR', 'categories': ['', 'HUMANITIES'],
#  'institution_id': 82, 'institution__name': 'MUTARE TEACHERS COLLEGE', 'department_id': None}
```
`department_id` is `None` — this program was auto-created by the bulk
ingestion's "create a new program if the code doesn't match an existing
one" fallback
(`backend/academic/services/student_services.py`, program-resolution block
around lines 516-580), most likely because a row's Program Code column
held `"2YEAR"` (a duration/level label, not a real code) while its name
column held `"Chishona"`. Nothing in that fallback rejects a code that
looks like a duration/level token — it only rejects codes over 50 chars or
that look like a 4-digit year (`re.fullmatch(r"(19|20)\d{2}", program_code)`,
line 556) — so `"2YEAR"` sailed through and a brand-new, parentless program
got created and reused for every subsequent row whose code column also
said `"2YEAR"`.

Checking how many students actually sit on that one program row revealed
the real scope:
```python
Student.objects.filter(program_id=3088).count()  # 1576
Student.objects.filter(institution__name__icontains='Mutare').count()  # 9426
```
A sibling of the same pattern exists: program id 3089, name `"MATHEMATICS"`,
code `"3YEAR"`, same `GENERAL DEPARTMENT`/`GENERAL FACULTY` placeholder —
confirming this is a recurring ingestion defect, not a one-off typo.

### 3. Key Findings
- The STEM classification logic itself (`backend/academic/services/stem.py`)
  is correct and not the cause — the 591 Mathematics/Geography/Computer-
  Science students are *correctly* flagged STEM by their `learning_area`;
  it's their `program` FK that's wrong.
- 1,576 of Mutare's 9,426 students (not just the 591 STEM-flagged ones) sit
  on this one placeholder program, spanning every subject at the college.
- The field that would disambiguate which real program a given student
  belongs to (the real programs split by entry level, e.g. Mathematics
  `MATH-2` for Post-"A"-level entrants vs `MATH-3` for Post-"O"-level) is
  `Student.selected_level`, which is `None` for all 1,576 affected records;
  `study_mode` is blank too. There is currently no reliable stored signal
  to automatically pick the correct target program per student.

## Root Cause
The bulk-upload program-resolution fallback in
`student_services.py` auto-creates a new `Program` whenever the code
column doesn't match an existing program and isn't caught by the
"too long" or "looks like a year" guards — with no guard against a
duration/level token like `"2YEAR"`/`"3YEAR"`, and no requirement that the
new program resolve a department/faculty. A past Mutare upload apparently
had `"2YEAR"` (and separately `"3YEAR"`) in its Program Code column for a
large share of rows, so every such row got funneled onto the same
auto-created placeholder program instead of erroring out for manual
correction.

## Prevention / Rule
**Guardrail:** Extend the existing "code looks like a year" rejection
(`student_services.py:556`) to also reject common duration/level tokens
(regex such as `^\d+\s*YEAR$|^YEAR\s*\d+$` or a small denylist covering
`2YEAR`/`3YEAR`/`4YEAR`/etc.), returning the same kind of row error as the
year case instead of silently auto-creating a program. Additionally,
require the auto-create path to resolve a real department (reject the
`GENERAL DEPARTMENT`/`GENERAL FACULTY` default silently standing in for an
unresolved one) so a malformed upload fails loudly per-row rather than
creating a reusable placeholder every subsequent bad row then piles onto.

This closes the gap because the current guard already proves the pattern
(reject a bad code shape with a clear per-row error) — it just didn't
anticipate duration/level tokens as an input shape.

## Solution

### Immediate Fix
Not yet applied — tracked as a follow-up in this session: add the code
guard described above.

### Long-term Fix
Data remediation for the existing 1,576 misattached students requires a
mapping source not currently in a queryable field (which entry-level
program — Post-"A" vs Post-"O" — each student belongs to). Options to
resolve, pending user decision: (a) recover the original source upload
file(s) if Mutare retained them, to re-derive the real program per
student, or (b) a manual reconciliation pass with the Mutare registrar.
No production student records will be changed until a verified mapping
source is confirmed.

## Prevention
- [ ] Reject duration/level-like codes in the bulk-upload program-resolution
      fallback (`student_services.py`)
- [ ] Require department/faculty resolution before auto-creating a program
- [ ] Data cleanup of the 1,576 Mutare students on program id 3088 (and the
      sibling id 3089 / `3YEAR` pattern) — pending a confirmed mapping source
- [ ] Audit other institutions for the same `GENERAL DEPARTMENT`/
      `GENERAL FACULTY` + duration-coded placeholder-program pattern

## Related Issues
- None filed yet for the sibling `3089`/`"3YEAR"` program — same pattern,
  not yet scoped.

## References
- `backend/academic/services/student_services.py` (program-resolution
  fallback, ~lines 516-580)
- `backend/academic/services/ingestion_service.py` (specialized-upload
  paths, lines 834-883)
- `backend/academic/app_views/student_views.py` (`stem_students` action)
- `backend/academic/services/stem.py` (STEM classification, confirmed
  correct)

---

**Resolved By:** Investigation by Claude (Sonnet 5), requested by Tinotenda Mupezeni — not yet resolved
**Time to Resolution:** In progress — code fix next, data cleanup pending a mapping source

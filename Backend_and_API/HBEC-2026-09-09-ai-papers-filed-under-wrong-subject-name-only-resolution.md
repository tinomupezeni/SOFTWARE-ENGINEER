# AI-Generated Papers Landed on the Wrong Subject, Invisible Under the Intended Filter

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
A real Form 4 Economics batch generated cleanly — all variants saved with
real questions — but "No papers found" when filtering the admin papers list
by Economics + Form 4, with stats all showing 0. The papers existed; they
were filed under a completely different subject.

## Symptoms
- Real, successfully-generated papers invisible under the subject/grade
  filter the admin used to trigger their generation.
- Confirmed the papers existed by querying the database directly, not
  through the filtered UI.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Admin Backend (`GenerateAIPaperView`)
- **Related Components:** `apps/curriculum/models.py` (`Subject`)
- **Time First Observed:** 2026-09-09, reported live by the admin during generation

## Investigation Steps

### 1. Initial Diagnosis
Queried the generated papers' actual `subject_id` and compared it against
the subject the admin had selected in the UI — they didn't match.

### 2. Root Cause Analysis
`GenerateAIPaperView` resolved the subject with
`Subject.objects.filter(name__iexact=payload["subject"]).first()` — a
subject *name* is not unique across grades in this schema. Four separate
"Economics" rows exist (one per Form 1/3/4 and A-Level), all sharing the
name. `.first()` non-deterministically returned whichever row the query
happened to return first — confirmed live, the Form 4 batch landed on the
A-Level Economics subject instead.

### 3. Key Findings
- The admin frontend's generation form already resolves the *exact*
  `Subject` object the admin picks (it needs the id to look up the grade
  name for display) but was only sending the subject's name and grade name
  to the backend — discarding the id it already had in hand.
- This bug would recur for every subject name that repeats across grades,
  which is most subjects in this curriculum.

## Root Cause
Subject resolution by name alone is ambiguous whenever a subject name
repeats across grades, and the frontend already had the disambiguating id
but wasn't sending it.

## Prevention / Rule
**Guardrail:** Make `subject_id` a required field on the generation request serializer — reject any request that omits it — rather than keeping name-based resolution as a permanent fallback path.

A fallback that "still works" is exactly what let a silent ambiguity ship in the first place; see guide 22 (Multi-Service Data Replication and Consistency) §5 for the general rule this instantiates: resolve cross-service references by id, never by name.

## Solution

### Immediate Fix
Manually corrected the `subject_id` on the affected papers (both the
original Form 4 batch and a subsequent Form 3 batch that hit the same bug
from a stale browser tab still running pre-fix JavaScript).

### Long-term Fix
- `AIGenerationModal.tsx` now sends `subject_id` in the generation payload
  (it already had the value, just wasn't sending it).
- `PaperGenerateRequestSerializer` accepts an optional `subject_id`.
- `GenerateAIPaperView` resolves by `subject_id` when present, falling back
  to the old ambiguous name-only lookup only for backward compatibility
  with any caller that doesn't send it.
- 3 new tests: `subject_id` resolves to the exact subject among several
  same-named ones, the name-only fallback still works, `subject_id` never
  leaks into the harness payload (which is `extra="forbid"` and would
  reject an unexpected key).

## Prevention
- [x] subject_id-based resolution with test coverage
- [ ] Consider making `subject_id` required (not just preferred) once every
      caller of this endpoint has been confirmed updated

## Related Issues
- Directly connected to the `Paper.variant` identity gap (same debugging
  session, same feature)

## References
- `ADMIN/adminBackend/apps/exam_papers/views.py`
- `ADMIN/adminBackend/apps/exam_papers/serializers.py`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/AIGenerationModal.tsx`
- Commit `8ee7f060`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session

# AI paper generation failed with "Must be a valid UUID" — subject code sent where a database id was required

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Staging (live wireless-ADB test against `staging-student.hbca.tech`)
**Severity:** High
**Status:** Resolved

## Summary
The newly-built "Generate New Paper" / "Target My Weaknesses" actions
(AI Generator & My Studio, built earlier in this same session) failed
every time with a generic "Could not generate paper right now" toast.
Root cause: Flutter's exam-practice routes carry a subject's short CODE
(e.g. `"4003"`) as `subjectId` throughout, but `POST /ai/papers/generate/`
strictly validates its `subject_id` field as a UUID — every other exam
endpoint this app calls tolerates the code, this one does not.

## Symptoms
- User report: "it's saying could not generate papers right now."
- Live log: `POST https://staging-student.hbca.tech/api/ai/papers/generate/`
  → `400 {"success":false,"message":"Must be a valid UUID.","errors":
  {"subject_id":["Must be a valid UUID."]}}`.

## Environment Details
- **Server/Host:** `staging-student.hbca.tech`
- **Services Affected:** Flutter's AI Generator & My Studio only (same
  bug would affect `generate-targeted` too, not yet separately reproduced
  live but sharing the identical code path).
- **Related Components:**
  `STUDENT/mobile_flutter/lib/features/exam/presentation/bloc/ai_papers_cubit.dart`
- **Time First Observed:** 2026-11-05, live test immediately after building
  the feature.

## Investigation Steps

### 1. Initial Diagnosis
Tailed the live `flutter run` log and grepped for `ai/papers/generate`,
found the exact request body and the server's own error response.

### 2. Root Cause Analysis
Request body sent: `{subject_id: 4003, topics: [...], ...}`. The same log
window showed the `/curriculum/topics/` response for the same subject
moments earlier, including the subject's real id:
`"subject":{"id":"ce3c5581-f97f-4b2f-884a-70852df6f787","code":"4003",...}`.
Confirmed this app's own `/exams/:subjectId/...` route parameter is the
subject CODE everywhere else (paper listing, topic lookup — both already
proven to work with the code), so the fix could not be "use the code
consistently" — it had to be "resolve the real id just for this one
stricter endpoint."

### 3. Key Findings
- Not every endpoint behind the same `subjectId` route parameter accepts
  the same identifier shape. Three endpoints in this one feature alone
  (`/practice/papers/`, `/curriculum/topics/`, `/ai/papers/generate/`)
  were assumed to share a contract because they share a URL parameter name
  in this app's own router; they don't.
- The resolution didn't need a new network call: the offline curriculum
  catalog already synced locally (`CurriculumRepository.getSubjects()`,
  used elsewhere in this same page for subject-name display) already
  carries each subject's real `id` alongside its `code`.

## Root Cause
Assumed one subject identifier (the route's `subjectId`, actually a code)
was valid everywhere in the feature, because it had already proven valid
for two of the three endpoints involved.

## Prevention / Rule
**Guardrail:** None added this session. The closest mechanical guardrail —
asserting every backend endpoint documented as taking `subject_id`/
`subject` validates the same identifier shape — would need to live in the
backend's own API contract tests, not the mobile client; flagged as a
cross-repo observation rather than something this session's scope can fix.

[No automated guardrail added — recommend backend-side contract
consistency (one identifier shape per logical "subject" parameter across
all `/ai/papers/*` and `/practice/*` endpoints) as a follow-up if this
class of mismatch recurs elsewhere.]

## Solution

### Immediate Fix
Not applicable — client-only bug, no service was down.

### Long-term Fix
`AiPapersCubit` now resolves the subject's real id once (`_subjectUuid()`,
matching `subjectId` against `CurriculumRepository.getSubjects()`'s
already-synced `code`/`id` pairs, falling back to the raw value if no
match is found) and uses the resolved id for both `generatePaper` and
`generateTargetedPaper` calls — the two confirmed-strict endpoints.
`getMyAiPapers`/`getSubjectTopics` were left using the route's raw
`subjectId` (the code), since both are proven working with it live and
changing them without evidence would risk introducing a new, opposite bug.

## Prevention
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A
- [ ] Documentation to update — N/A
- [x] Code changes required — done, see Solution above.

## Related Issues
- Same feature build as
  `HBEC-2026-11-05-flutter-exam-practice-parity-ai-generator-floating-widgets.md`
  (report), which flagged "live verification of the five new endpoints"
  as its single biggest open risk — this is that risk materializing and
  being closed within the same session.

## References
- `STUDENT/mobile_flutter/lib/features/exam/presentation/bloc/ai_papers_cubit.dart`
- `STUDENT/mobile_flutter/lib/features/curriculum/domain/repositories/curriculum_repository.dart`

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** <20 minutes

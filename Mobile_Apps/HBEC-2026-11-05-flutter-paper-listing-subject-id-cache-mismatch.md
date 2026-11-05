# Papers silently disappeared for every subject — local cache keyed by UUID, queried by code

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Staging (reported live: Combined Science has real content on
web, zero on mobile)
**Severity:** Critical
**Status:** Resolved

## Summary
The Flutter app's paper listing (Select Paper Type → Paper 1/2/3) could
show an empty "no papers available" state for a subject that genuinely has
papers — confirmed for Combined Science, which the web app correctly shows
9 Community Practice papers for. Root cause: the offline-first cache
stored each paper under its subject's database UUID, but every caller in
this app queries that cache using the subject's short CODE (e.g.
`"4003"`) — the identifier this app's own routes (`/exams/:subjectId/...`)
actually carry throughout. The remote fetch always succeeded; the local
re-read that the UI actually displays silently matched nothing.

## Symptoms
- User report, with a pasted web screenshot showing real content: "this is
  combined science and there's content yet the mobile app is failing to
  pull any content for the same combined science papers."
- No error shown to the student — just an empty "No papers available"
  state, indistinguishable from a subject that genuinely has none.

## Environment Details
- **Server/Host:** `staging-student.hbca.tech`
- **Services Affected:** Flutter `PaperListingPage` for **every** subject,
  not only Combined Science — this is a structural mismatch in how the
  local cache is keyed, not a per-subject data problem.
- **Related Components:**
  `STUDENT/mobile_flutter/lib/features/exam/data/models/exam_models.dart`,
  `.../data/datasources/exam_local_datasource.dart`,
  `.../data/repositories/exam_repository_impl.dart`
- **Time First Observed:** 2026-11-05, live wireless-ADB test.

## Investigation Steps

### 1. Initial Diagnosis
The live log showed `GET /practice/papers/?subject=4003` returning `200`
with real paper data (confirmed non-empty `Response Text`, including an
item with `"subjectCode":"4003"`), yet the on-screen list for "Paper 1"
was empty. A successful fetch with an empty result pointed at
post-fetch filtering, not the network call.

### 2. Root Cause Analysis
Traced the read path: `ExamRepositoryImpl.getPapers` always re-reads from
`_localDataSource.getPapers(subjectId: subject)` after syncing, regardless
of whether the remote fetch succeeded — by design, so the UI reads one
consistent source. That local query:
```dart
// exam_local_datasource.dart
if (subjectId != null) {
  query.where((tbl) => tbl.subjectId.equals(subjectId));
}
```
compares against whatever was stored by `savePapers`, which persists
`p.subjectId` — and `PaperModel.fromJson` mapped that straight from the
API's `subjectId` field, **the subject's database UUID**
(`"ce3c5581-f97f-4b2f-884a-70852df6f787"`), not its code. Every caller in
this app passes the CODE: `ExamCubit.loadPapers(subject: widget.subjectId)`
where `widget.subjectId` is literally the `:subjectId` route segment, which
this app's own router populates with subject codes end to end (confirmed
by re-reading `ExamPracticePage`'s navigation, which pushes
`/exams/$subjectCode/select-paper`). A code string can never equal a UUID,
so the local re-read returned zero rows for every subject, every time —
masked for subjects with no real content (an empty result looked correct)
and only became visible once a subject (Combined Science) actually had
papers to lose.

### 3. Key Findings
- The backend's `/practice/papers/` response genuinely carries both
  `subjectId` (UUID) and `subjectCode` (e.g. `"4003"`) per paper — the
  code this app needed was already in every response, just never read
  into the model.
- This is the same root-cause *shape* as two other bugs fixed earlier in
  this session (`HBEC-2026-11-05-flutter-add-subjects-empty-list.md`,
  `HBEC-2026-11-05-flutter-ai-paper-generation-uuid-mismatch.md`): a
  subject identifier that is a code in this app's own routing silently
  compared against a UUID somewhere downstream. Flagging the pattern
  explicitly since it has now recurred three times in one session, across
  three unrelated features.
- `Paper.subjectId` (the Flutter entity field) is never read by any
  presentation-layer code for anything beyond this cache key — confirmed
  by grep before changing its semantic meaning, so repointing it from UUID
  to code could not silently break a different feature.

## Root Cause
`PaperModel.fromJson` stored the API's `subjectId` (a UUID) as the local
cache's filter key, while every caller queries that cache by the subject
CODE this app's routing actually uses — a mismatch invisible until a
subject with real content was checked.

## Prevention / Rule
**Guardrail:** None added this session. Flagging the recurring pattern
(three incidents, one session: `user.level` vs `user.grade`, a code vs a
UUID for `/ai/papers/generate/`, and now this) as a case for a slightly
heavier-handed fix than usual: this app has exactly one place where
"subject identifier" is ambiguous between code and UUID, and it keeps
costing a debugging pass each time a new feature touches it. A follow-up
worth considering: a single `SubjectRef` type (holding both `code` and
`id` together) used everywhere a "subject" is passed between layers, so a
caller can no longer accidentally pass the wrong half — not built now,
since it would touch routing, caching and several repositories at once,
bigger than this fix's blast radius.

[No automated guardrail added — see the `SubjectRef` follow-up above as
the shape a real fix would take if this recurs a fourth time.]

## Solution

### Immediate Fix
Not applicable — client-only cache bug, no service was down.

### Long-term Fix
`PaperModel.fromJson` now stores `subjectCode` (falling back to
`subjectId` only if a response has no code at all) as the `Paper` entity's
`subjectId` field — matching what every caller already filters by. Drift's
`remoteId`-keyed `InsertMode.replace` means the next successful sync for
any subject self-heals its cached rows with no migration or manual cache
clear needed.

## Prevention
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A
- [ ] Documentation to update — N/A
- [x] Code changes required — done, see Solution above.

## Related Issues
- `HBEC-2026-11-05-flutter-add-subjects-empty-list.md` and
  `HBEC-2026-11-05-flutter-ai-paper-generation-uuid-mismatch.md` — same
  session, same root-cause shape (code vs. UUID for "subject"), different
  features.

## References
- `STUDENT/mobile_flutter/lib/features/exam/data/models/exam_models.dart`
- `STUDENT/mobile_flutter/lib/features/exam/data/datasources/exam_local_datasource.dart`
- `STUDENT/mobile_flutter/lib/features/exam/data/repositories/exam_repository_impl.dart`
- `STUDENT/hbec_backend/apps/practice/views.py` (`PracticeSetListView`,
  confirms both `subjectId` and `subjectCode` are already in every
  response)

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** <30 minutes

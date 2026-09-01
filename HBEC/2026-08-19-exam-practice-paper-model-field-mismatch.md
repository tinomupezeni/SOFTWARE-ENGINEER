# Exam Practice Showed Codes Instead of Names — Paper Model Never Matched the API

**Date:** 2026-08-19
**Project:** HBEC (mobile_flutter)
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
After fixing the profile page's code-vs-name issue, the user reported the same symptom class on Exam Practice papers. Investigation found the mobile `Paper` domain entity's fields had never matched what `GET /practice/papers/` actually returns — every single remote paper sync silently failed and fell back to a cache that could never be populated correctly either, so the subtitle/detail shown for any paper was built from empty/zero fallback values.

## Symptoms
- User: "on exam practice papers its still showing paper codes not the actual paper names"
- Paper list subtitle rendered as something like `Paper 0 -  2024` (blank session, zero paper number) rather than a real label

## Environment Details
- **Server/Host:** Staging + Production
- **Services Affected:** `mobile_flutter` exam feature
- **Related Components:** `lib/features/exam/domain/entities/exam.dart`, `.../data/models/exam_models.dart`, `.../data/repositories/exam_repository_impl.dart`, `lib/core/local_db/drift_database.dart`
- **Time First Observed:** 2026-08-19

## Investigation Steps

### 1. Initial Diagnosis
Compared the mobile `Paper` entity's fields (`subject`, `level`, `paperNumber`, `session`) against the actual JSON returned by `GET /practice/papers/` on the Student Django backend, which returns `subjectName`/`subjectCode`, `paperType` (a string like `"paper1"`), `examSession`, `year` — none of the mobile field *names* matched.

### 2. Root Cause Analysis
`PaperModel.fromJson(p)` (`subject: json['subject']` etc., non-nullable) threw a null-cast error on **every real response**, since the backend never sent a key called `subject`. That exception was caught by `ExamRepositoryImpl.getPapers`'s outer `try/catch` and logged only as `AppLogger.warning('Failed to refresh papers from remote, using cache')` — meaning the remote sync had been silently failing on every load, for every user, and the app had been running entirely on whatever was in the local Drift cache (which itself could never populate correctly for the same field-mismatch reason).
Separately, `ExamPracticePage`'s subject grid rendered `state.user.subjects` (raw codes) directly with no name-resolution step at all — the same root symptom, in miniature, on a completely different screen.

### 3. Key Findings
- Confirmed via the web frontend's own `examApi.ts` that there is no single "paper name" field from the backend at all — the web client composes a two-line display (`"{subjectName} ({syllabusCode})"` / `"Paper 1 - November 2023"`) client-side from `subjectName`/`subjectCode`/`paperType`/`examSession`/`year` — so the mobile fix needed to match that composition, not look for a field that doesn't exist
- `ExamPracticePage`'s subject grid was blank of names because nothing had ever triggered a curriculum catalog sync — `CurriculumRepository.getSubjects()` only reads the local cache unless explicitly told to sync, and `TopicRevisionPage` already had a "sync if empty, then re-read" fallback pattern that `ExamPracticePage` was simply missing

## Root Cause
The mobile `Paper` entity/model's field names were never aligned with the Student backend's actual response shape, so every remote sync threw and silently fell back to an equally-broken cache; and the subject grid screen had no curriculum-sync fallback at all.

## Solution

### Immediate Fix
Realigned `Paper`/`PaperModel` to the backend's real fields (`subjectId`, `subjectName`, `paperType`, `examSession`, `year`, `totalMarks`, `questionCount`), added a `paperTypeLabel` getter matching the web client's `paper1 → "Paper 1"` mapping, bumped the Drift schema to v2 with a migration that drops and recreates the disposable local cache table, and updated every screen (`paper_listing_page.dart`, `practice_page.dart`) that displayed a paper. Added the same sync-if-empty fallback from `TopicRevisionPage` to `ExamPracticePage`'s subject grid. Deleted `exam_list_page.dart`, a confirmed-orphaned duplicate of `paper_listing_page.dart` referencing the old (now-removed) fields.

### Long-term Fix
Committed as `64e5378` (`fix(mobile): resolve subject and paper names on exam practice, not raw codes`). `flutter analyze` and `flutter test` both green with zero new issues against the existing ratchet.

## Prevention
- [x] Code changes required (committed)
- [ ] Consider a contract test between the mobile `PaperModel.fromJson` and a real/fixture backend response, so a future field rename on either side fails loudly in CI instead of degrading silently to a swallowed exception + stale cache

## References
- `STUDENT/Frontend/src/features/exam-practice/api/examApi.ts` (the reference composition logic mobile now matches)

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~1 hour

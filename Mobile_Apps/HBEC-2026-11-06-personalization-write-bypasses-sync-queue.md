# Personalization subject add/remove bypasses the offline sync queue

**Date:** 2026-11-06
**Project:** HBEC (mobile_flutter)
**Environment:** Development
**Severity:** Medium
**Status:** Investigating (flagged, not fixed — pre-existing, shared by multiple features)

## Summary
Flutter's offline-first rule ("mutations go through the sync queue, never
straight to the API" — `STUDENT/mobile_flutter/CLAUDE.md`) is violated by the
one write path every subject-picker page uses to add or remove a subject.
Found while porting the Interactive Learning landing page
(`InteractiveLearningPage`), which reuses this exact path — the gap is not
new to that page, but the migration surfaced it because the task asked
explicitly whether the reused write path already satisfied the rule.

## Symptoms
- No crash or visible error; this is a silent policy violation, not a defect
  a user reports directly.
- Practical consequence: adding/removing a subject while offline fails
  outright (the HTTP call throws, caught and surfaced as a toast via
  `AddSubjectSheet._updateProfile`'s try/catch) instead of queuing and
  syncing once connectivity returns, as every other mutation in the app does.

## Environment Details
- **Server/Host:** N/A (client-side architectural gap)
- **Services Affected:** `features/auth` (PersonalizationCubit,
  AuthRepositoryImpl), consumed by `features/exam` (ExamPracticePage),
  `features/revision` (TopicRevisionPage), and now
  `features/interactive_learning` (InteractiveLearningPage) — every page that
  lets a student manage their subject list.
- **Related Components:** `SyncQueueService` /
  `shared/services/sync_queue_local_datasource.dart` (the queue this path
  skips); `revision_repository_impl.dart` is the example of a repository that
  *does* route mutations through it correctly.
- **Time First Observed:** 2026-11-06, during the Interactive Learning
  migration pass (explicitly asked to verify, not assumed).

## Investigation Steps

### 1. Initial Diagnosis
The migration task required reusing `AddSubjectSheet` /
`PersonalizationCubit` (the only existing add/remove-subject UI) rather than
building a page-local one, and the task brief required confirming — not
assuming — that this reused path satisfies the offline sync-queue rule.

### 2. Root Cause Analysis
Traced the call chain from the UI down:
```
AddSubjectSheet._updateProfile()
  -> PersonalizationCubit.savePersonalization()
  -> AuthRepository.savePersonalization()  (abstract)
  -> AuthRepositoryImpl.savePersonalization()
       -> _remoteDataSource.savePersonalization(...)   // direct HTTP, no queue
```
Confirmed `SyncQueueService` exists and is used correctly elsewhere
(`revision_repository_impl.dart`), so the pattern to fix this with is already
in the codebase — this is an omission in one repository, not a missing
capability.

### 3. Key Findings
- `AuthRepositoryImpl.savePersonalization` (`lib/features/auth/data/
  repositories/auth_repository_impl.dart:185-204`) calls
  `_remoteDataSource.savePersonalization(...)` directly inside a try/catch
  that returns `Result.error` on failure — no queuing, no retry.
- The *web* app (`useUserSubjects.ts`) has the identical gap (`savePersonalization`
  called straight from the hook), which is consistent there since web has no
  offline-first contract — but Flutter does, and the port does not get a pass
  on that account.
- This is shared infrastructure: fixing it fixes Exam Practice, Topic
  Revision and Interactive Learning's add/remove-subject flows all at once,
  but also means a fix must be validated against all three call sites.

## Root Cause
`AuthRepositoryImpl.savePersonalization` was written as a thin passthrough to
the remote data source when personalization was onboarding-only (an
online-required flow at signup). As `AddSubjectSheet` was later reused
post-onboarding, from pages the app otherwise treats as fully offline-capable,
the write path never migrated to the mutation pattern the rest of the app
settled on (queue-first, synced in the background).

## Prevention / Rule
**Guardrail:** a repository-layer test asserting every `AuthRepositoryImpl`
mutation method that is reachable from an authenticated, non-onboarding route
either (a) writes through `SyncQueueService` or (b) is explicitly annotated/
documented as deliberately online-only with a stated reason — mirroring how
`revision_repository_impl.dart` already demonstrates the compliant pattern.
Without such a test, a repository method can silently stay on the old
synchronous pattern indefinitely, since nothing fails loudly: it works fine
whenever the device has a connection, which is also why no one had reported
it.

## Solution

### Immediate Fix
None applied in this pass — flagged per the task's explicit instruction to
confirm, not assume, and reported rather than silently fixed inside an
unrelated migration PR, since fixing it touches three features' tests
(`ExamPracticePage`, `TopicRevisionPage`, `InteractiveLearningPage`) and the
shared `AuthRepositoryImpl`/`PersonalizationCubit` test suite, which is
properly its own change.

### Follow-up
Route `AuthRepositoryImpl.savePersonalization` through `SyncQueueService`
when called post-onboarding (i.e. from `AddSubjectSheet`, not
`PersonalizationPage`'s initial wizard, which can reasonably stay
online-required since it gates account creation).

## References
- `STUDENT/mobile_flutter/lib/features/auth/data/repositories/auth_repository_impl.dart`
- `STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/add_subject_sheet.dart`
- `STUDENT/mobile_flutter/lib/features/auth/presentation/bloc/personalization_cubit.dart`
- `STUDENT/mobile_flutter/lib/shared/services/sync_queue_service.dart`
- `STUDENT/mobile_flutter/lib/features/revision/data/repositories/revision_repository_impl.dart`
  (the compliant precedent)
- Report: `reports/HBEC-2026-11-06-interactive-learning-flutter-first-slice.md`

---
**Completed By:** Claude Sonnet 5 (agent session)

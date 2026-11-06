# Personalization subject add/remove bypasses the offline sync queue

**Date:** 2026-11-06
**Project:** HBEC (mobile_flutter)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

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
Fixed in a dedicated pass, scoped only to the add/remove-subject path
(per the explicit "don't blanket-convert every `AuthRepositoryImpl` write"
instruction — password/email changes etc. correctly stay synchronous):

- `AuthRepository.savePersonalization` / `AuthRepositoryImpl.savePersonalization`
  gained an `allowQueue` parameter (default `false`, preserving the old
  online-required behaviour). When `true` and the remote call throws, the
  repository no longer returns `Result.error`: it applies the write to the
  local cache (new `AuthLocalDataSource.applyPersonalizationPatch`, merging
  grade/examBoardId/examBoardCode/subjects into the cached `UserModel`) and
  enqueues it via the existing `SyncQueueLocalDataSource.enqueueSync('save_personalization', payload)`
  — the same queue `revision_repository_impl.dart` already uses, with the
  `save_personalization` handler registered in `injection.dart`'s
  `SyncQueueService` map alongside `submit_attempt`/`submit_quiz_attempt`.
- `PersonalizationCubit.savePersonalization` now forwards `allowQueue` and,
  importantly, actually inspects the repository's `Result` and rethrows on
  `Err` — previously it awaited and discarded the `Result` entirely, so a
  real failure from the onboarding wizard's online-required path was already
  silently swallowed before this fix; that was a latent bug in the exact
  method this issue required touching, fixed as part of the same change.
- Call sites: `AddSubjectSheet._updateProfile` (used by ExamPracticePage,
  TopicRevisionPage and InteractiveLearningPage's add-subject flows) passes
  `allowQueue: true`. `PersonalizationPage` passes `allowQueue: widget.isEditMode`
  — the first-time wizard (`isEditMode == false`) stays online-required
  because it gates account creation, exactly as scoped in the original
  follow-up note; reopening the same page from Settings post-onboarding
  (`isEditMode == true`) is the same offline-capable mutation as
  `AddSubjectSheet` and now queues too.
- Optimistic UI: `AddSubjectSheet`/`PersonalizationPage` both call
  `AuthBloc.add(ProfileRefreshRequested())` after a save. That handler used
  to only emit on a successful remote `getProfile()` call, so offline it
  emitted nothing and the UI kept showing the pre-edit subject list even
  though the local cache had already been patched. `AuthBloc._onProfileRefreshRequested`
  now falls back to `getCachedUser()` on a failed remote fetch and emits that
  if present, so the queued local update is visible immediately.

### Testing
- `test/features/auth/data/repositories/auth_repository_impl_test.dart` (new):
  online success writes straight through with no queue interaction;
  `allowQueue: false` + remote failure returns `Err` and touches neither the
  cache nor the queue (pins the onboarding wizard's online-required
  behaviour); `allowQueue: true` + remote failure applies the local patch,
  enqueues `save_personalization` with the exact payload, and returns `Ok`;
  a device with no cached user yet is handled without throwing.
- `test/features/auth/presentation/bloc/personalization_cubit_test.dart` (new):
  completes without throwing on success; forwards `allowQueue` through
  (true and the false default); throws with the failure message on `Err`.
- `test/features/auth/presentation/bloc/auth_bloc_test.dart` (new):
  `ProfileRefreshRequested` emits the fresh profile on success; falls back to
  the cached user (simulating the post-queue optimistic state) when the
  remote fetch fails; emits nothing when there is no cached user either or
  when both reads fail.
- `flutter analyze`: clean on every touched file (no new issues; the 66
  pre-existing issues elsewhere in the app, plus 2 pre-existing golden-test
  pixel-diff failures and one pre-existing dangling test file reference from
  concurrent interactive-learning work in the same working tree, are
  unrelated — verified by stashing this change and re-running them, which
  reproduced the same failures without it).
- `flutter test` (full suite): all auth tests pass (20/20, 12 new); no
  regressions in exam/revision/interactive-learning suites that depend on
  `AddSubjectSheet`/`PersonalizationCubit`.

### What still calls the old direct (non-queued) path, and why
- `PersonalizationPage` in its first-time wizard mode (`isEditMode == false`)
  — `allowQueue` defaults to `false`. This is deliberate: it gates account
  creation and must report a real failure synchronously rather than let a
  brand-new account finish signup with a queued, unconfirmed personalization
  write.
- Every other `AuthRepositoryImpl` mutation (`login`, `changePassword`,
  `updateAccount`, `updatePhoneNumber`, `convertToParent`, `savePrivacy`,
  `saveStudyPlan`, `saveCompanion`, etc.) is untouched — per the task's scope
  instruction, these need synchronous server confirmation and queueing them
  would be wrong, not safer.

### Follow-up (still open)
The **Prevention / Rule** guardrail above (a repository-layer test asserting
every reachable `AuthRepositoryImpl` mutation is either queued or explicitly
documented as online-only) was not written in this pass — it's a broader
contract test across the whole repository, not specific to this bug, and is
left as a separate follow-up.

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

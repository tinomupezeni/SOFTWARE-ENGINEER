# Mobile Profile Page Showed Subject Codes and a Grade UUID Instead of Names

**Date:** 2026-08-19
**Project:** HBEC (mobile_flutter)
**Environment:** Production (real device)
**Severity:** Medium
**Status:** Resolved

## Summary
Immediately after the Android 15 crash fix was confirmed, the same live-device session surfaced three more issues at once: the profile page showed a subject **code** instead of the subject's real name, the grade field showed what looked like a raw UUID/code instead of a grade name, and the profile page had a black background instead of matching the web app's design.

## Symptoms
- User (same message that confirmed the crash fix): "ON SUBJECTS SELECTING IT ON SHOWING THE SUBJECTS STUDENT HAS SELECTED, ITS SHOING THE SUB ID NOT THE ACTUAL SUBJECT NAME, SAME WITH TH E STUDENT GRADE ITS SHOWN AS A UUID AND FINALLY THE STUDENT PROFILE ITS BLACK BACKGROUND"

## Environment Details
- **Server/Host:** User's real Android device
- **Services Affected:** `mobile_flutter` profile/auth feature
- **Related Components:** `lib/features/auth/domain/entities/user.dart`, `.../data/models/user_model.dart`, `.../presentation/pages/profile_page.dart`, `.../presentation/bloc/personalization_cubit.dart`
- **Time First Observed:** 2026-08-19

## Investigation Steps

### 1. Initial Diagnosis
The `User` entity only carried `grade`/`subjects` as raw codes end-to-end — there was no `gradeName` or resolved subject-name field anywhere in the model, datasource, or repository layer, so the UI had nothing but codes to render even if it wanted to show names.

### 2. Root Cause Analysis
The backend's `StudentProfile.to_dict()` already returns `gradeName`, `examBoardCode`, etc. — the data existed server-side and was simply never threaded through the mobile client's `User`/`UserModel`/datasource chain.
Separately, `PersonalizationCubit.loadOptions()` had a real, silent bug: `getPersonalizationOptions(boardCode ?? examBoard)` never passed `grade` through, even though `getPersonalizationOptions` had a `grade` parameter available — meaning grade-scoped subject-name lookups were being silently dropped even where the plumbing partially existed.

### 3. Key Findings
- `Scaffold(backgroundColor: Colors.transparent, ...)` was the black-background cause — transparent over a dark system background renders black; should have been `AppColors.background` to match web
- A hardcoded fake `'Form 4'` grade fallback existed in the old code, violating the project's own "no mock/fallback data" rule — removed rather than kept as a silent lie when data is genuinely missing

## Root Cause
Missing fields (`examBoardCode`, `grade`, `gradeName`) on the mobile `User` model meant the profile page only ever had codes to display, and a real silent bug in `PersonalizationCubit.loadOptions` dropped the `grade` parameter needed to resolve grade-scoped subject names even for the one path that did try.

## Solution

### Immediate Fix
Added `examBoardCode`/`grade`/`gradeName` through `User`, `UserModel`, the remote datasource, repository, and repository interface; fixed `PersonalizationCubit.loadOptions` to actually pass `grade` through. `ProfilePage` converted to `StatefulWidget` with a one-time `_maybeLoadSubjectNames` call that resolves subject codes to names via a map built from the cubit's grade/board-scoped options list. Background fixed to `AppColors.background`; fake `'Form 4'` fallback removed and replaced with `user.gradeName ?? user.grade ?? 'Not set'`.

### Long-term Fix
Committed as `df52160` (`fix(mobile): resolve subject and grade names on profile instead of raw codes`). `flutter analyze` confirmed the existing ~35-issue ratchet was unaffected (zero new issues).

## Prevention
- [x] Code changes required (committed)
- [ ] Consider surfacing `PersonalizationCubit`'s dropped-parameter class of bug via a stricter typed interface rather than optional named params that are easy to forget to forward

## References
- Verified live on the same real device used for the crash-fix confirmation

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~30 minutes

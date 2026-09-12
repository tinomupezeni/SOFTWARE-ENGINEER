# Silent Auth Failure Falls Back to Stale Guest-Cached Subjects Instead of Refreshing the Token

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Production (bug) / Staging (fix deployed and verified 2026-09-09)
**Severity:** Critical
**Status:** Fixed — deployed and verified on staging; production deploy not yet done

## Summary
While diagnosing a different student's missing-subjects report, a second account (`mupezeni2001@gmail.com`) was pulled in for comparison and turned up its own, unrelated bug: its Topic Revision screen shows O-Level subjects (`Combined Science`, `Economics`, `Mathematics`) tagged `zimsec_olevel`, even though the account's actual `StudentProfile` is `level=zimsec_alevel`, `grade=form-6`. The subject list on that screen isn't reading the student's current profile at all in this case — it's silently falling back to a stale, client-cached level because `SoftJWTAuthentication` swallows an expired/invalid token instead of returning 401, so the frontend's auto-refresh logic never triggers and the request degrades into an unauthenticated "guest" path that trusts client-supplied data.

## Symptoms
- Topic Revision page shows subjects for a level (`zimsec_olevel`) the account is not currently on.
- No error surfaced to the user or in logs — this is a silent data-integrity failure, not a crash.
- Reproducible whenever a request's access token has expired without a hard page refresh, for any account, not just this one.

## Environment Details
- **Server/Host:** `hbca-vps` production
- **Services Affected:** Student Backend (`STUDENT/hbec_backend`, `core.authentication`, `apps.curriculum`), Student Frontend (`STUDENT/Frontend`, topic-revision feature)
- **Related Components:** `SubjectListView`, `SoftJWTAuthentication`, `apiFetch`, `localStorage['hbc_level_preference']`, Redis subject-list cache
- **Time First Observed:** 2026-09-09, discovered incidentally while cross-checking a different account during another investigation

## Investigation Steps

### 1. Initial Diagnosis
The account was pulled up purely as a "known-good" comparison for a different bug. Its profile query showed `level=zimsec_alevel`, `grade=form-6`, `level_change_count=0`, `level_last_reset_at` empty — i.e. this level was set by a **direct write**, not through the self-service personalization endpoint (which would have incremented the counter and stamped the reset time). That mismatch (a UI screenshot showing `zimsec_olevel`, a DB row showing `zimsec_alevel`) is what triggered this investigation.

### 2. Root Cause Analysis
Traced the Topic Revision screen's data path front-to-back:

- `STUDENT/Frontend/src/features/topic-revision/pages/TopicRevisionPage.tsx:25-90` → `useSubjects()` (`.../hooks/useRevision.ts:11-33`) → `revisionService.getSubjects(preference.levelCode)` (`.../services/revisionService.ts:9-13`) → `api.fetchSubjects(level)` (`.../api/revisionApi.ts:35-57`), which calls `GET /curriculum/subjects/?level=${level}` on the **Student Backend**, not the harness's revision pillar — there is no separate "revision subjects" table; the list is the same `personalization.subjects` field on `accounts_studentprofile` used everywhere else.
- `preference.levelCode` comes from `localStorage['hbc_level_preference']`, refreshed only when a `personalization` change event fires (`ProfileSyncBridge.tsx:36-40`) — a direct-write level change, as this account had, never fires that event, so a stale value can sit in `localStorage` indefinitely.
- Backend side: `SubjectListView.get()` (`STUDENT/hbec_backend/apps/curriculum/views.py:145-258`) calls `get_student_profile(request)` (`core/middleware.py:10-39`). If it resolves, the view filters strictly by the DB profile (`:206-222`, the correct path). **If it does not resolve, the view falls into a "guest" branch (`:223-236`) that trusts the client-supplied `level` query parameter outright.**
- `SoftJWTAuthentication.authenticate()` (`core/authentication.py:16-20`) returns `None` on an expired or invalid access token instead of raising a 401. `apiFetch`'s token-refresh interceptor only triggers on an actual 401 response, so it never fires here — the request silently proceeds as anonymous and lands in the guest branch.
- The guest branch's response is itself cached in Redis for an hour under a key built from the raw client value: `curriculum:subjects:guest:{level}:{code}:{grade_code}` (`views.py:197-201`, `CURRICULUM_CACHE_TTL_SECONDS=3600` at `:32`). `@never_cache` (`:144`) only sets HTTP response headers — it has no effect on this Redis layer.

### 3. Key Findings
- Two independent failures have to compound for this to surface: (a) a level change that bypasses the personalization endpoint, leaving `localStorage` stale with no event to refresh it, and (b) an expired token on the same request, which silently degrades auth instead of failing loudly.
- Neither failure is logged anywhere — `SoftJWTAuthentication` returning `None` produces no warning, and the guest-branch fallback in `SubjectListView` produces no signal that it served unauthenticated, client-trusted data to what might be a real logged-in user. This is a direct violation of the project's "silent swallowing is forbidden" rule (`CLAUDE.md`, Cross-Cutting Rules).
- This is not specific to `mupezeni2001@gmail.com` or to Topic Revision — any endpoint using `SoftJWTAuthentication` with a guest/anonymous fallback path is exposed to the same class of bug whenever a client's token has expired without a hard refresh.

## Root Cause
`SoftJWTAuthentication.authenticate()` silently returns `None` instead of raising 401 on an expired/invalid token, which prevents the frontend's automatic token-refresh flow from ever running. `SubjectListView` then falls back to an unauthenticated "guest" branch that trusts a client-supplied, `localStorage`-cached `level` value with no server-side verification against the actual account — and caches that untrusted response server-side for an hour. When the client's cached level is stale (as happens whenever a level change bypasses the personalization endpoint), the student is served subjects for a level they are no longer on, with no error anywhere in the chain.

## Prevention / Rule
**Guardrail:** Any endpoint offering a dual authenticated/guest path must call the new `token_present_but_rejected(request)` middleware helper before falling into its guest branch — codified as a required code-review checklist item for every new "works for guest, richer for logged-in" endpoint.

`SoftJWTAuthentication` returning `None` on a rejected token is deliberate by design (genuinely public endpoints depend on it) and can't be tightened globally without breaking them — the guardrail has to live at each dual-path endpoint, not at the authentication class itself.

## Solution

### Implemented (deployed to staging, verified live 2026-09-09)
Deliberately did **not** change `SoftJWTAuthentication.authenticate()` itself — it's intentionally permissive by design for genuinely public endpoints (`ExamBoardListView`, `LevelListView` both rely on staying browsable regardless of token state; the original proposal below to make it raise on any bad token would have broken that). Instead, added a surgical helper that distinguishes "no token" from "token present but rejected" at the specific call sites that need to know:
- `core/middleware.py`: new `token_present_but_rejected(request)` — true only when an `Authorization` header was sent but `get_student_profile()` still resolves to nothing.
- `SubjectListView` and (found during implementation, not in the original diagnosis) **`TopicTreeView`** — which has the same class of gap: an expired token silently downgrades its level/exam-board access guard from enforced to skipped, rather than showing wrong subjects. Both now return 401 when `token_present_but_rejected()` is true, before reaching their guest-trusting/unguarded paths.
- `SoftJWTAuthentication`'s docstring updated to explicitly warn against "fixing" it globally, pointing at the middleware helper instead.
- Added regression tests (`apps/curriculum/tests/test_grade_scoping.py`, `core/tests/test_middleware.py`) covering: rejected token → 401, no token → guest path still works, valid token → unaffected.
- Verified live against `student-backend-staging`: a bogus bearer token now returns `401 {"success":false,"message":"Authentication token is invalid or expired."}`; a genuinely tokenless request to a guest-open endpoint still returns 200.

### Still open
- The `refreshUser()`/`localStorage['hbc_level_preference']` staleness mechanism this doc originally proposed fixing turned out not to be necessary as a standalone fix: once a rejected token 401s instead of silently degrading, a *logged-in* student can no longer reach the guest-trusting path at all, which was the only way stale `localStorage` data could leak into a real account's response. Direct writes to `StudentProfile.level`/`grade` bypassing `apply_personalization` remain a separate, real gap (still invisible to `ProfileSyncBridge`) but are lower severity now that this fix is in — logged as a follow-up, not fixed here.
- Not yet deployed to production — staging only, deliberately (production was out of scope for this pass).

## Prevention
- [x] Code changes: 401 on a rejected-but-present token at both affected call sites (done, staging-verified)
- [x] Regression tests added
- [ ] Production deploy
- [ ] Audit for other `SoftJWTAuthentication` call sites with a similar guest-fallback or guard-skip pattern beyond the two found here
- [ ] Direct writes to `StudentProfile.level`/`grade` still don't emit a `ProfileSyncBridge` signal — lower priority now, but still a real gap

## Related Issues
- [2026-09-09: O-Level Silently Unselectable — Dropped From Every Exam Board's supported_levels](./2026-09-09-olevel-not-in-exam-board-supported-levels.md) — surfaced in the same investigation, different account, unrelated root cause
- [2026-09-09: Staging Postgres/Pgbouncer Password Drift](./2026-09-09-staging-postgres-secret-drift-crash-loop.md) — hit while deploying this fix to staging, unrelated to this bug

## References
- `STUDENT/hbec_backend/core/authentication.py:16-20` (`SoftJWTAuthentication`)
- `STUDENT/hbec_backend/core/middleware.py` (`get_student_profile`, `token_present_but_rejected`)
- `STUDENT/hbec_backend/apps/curriculum/views.py` (`SubjectListView`, `TopicTreeView`)
- `STUDENT/Frontend/src/features/topic-revision/pages/TopicRevisionPage.tsx`
- `STUDENT/Frontend/src/features/topic-revision/api/revisionApi.ts:35-57`
- `STUDENT/Frontend/src/shared/hooks/useLevelPreference.ts`
- `STUDENT/Frontend/src/shared/components/ProfileSyncBridge.tsx:36-40`
- `STUDENT/Frontend/src/shared/hooks/useUserSubjects.ts:40-77,97-147`
- `STUDENT/Frontend/src/lib/api.ts` (`apiFetch`, refresh-on-401)
- Commit: `d415b02d`

---

**Diagnosed and fixed by:** Claude Code (Sonnet 5) — staging-verified; production deploy pending
**Time to Resolution:** ~25 minutes diagnosis + ~30 minutes implementation/deploy

# Flutter gamification/leaderboard base-path and field-name mismatches vs. live backend

**Date:** 2026-11-03
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Staging (`staging-student.hbca.tech`)
**Severity:** High (gamification/leaderboard/streak data would have silently
rendered as zeros/empty on every real account)
**Status:** Resolved

## Summary
The Flutter dashboard rebuild's gamification data layer (built earlier the
same session — see `reports/HBEC-2026-11-03-flutter-dashboard-parity-
phase1-2.md`) was implemented from the web frontend's TypeScript usage
without a live backend check, as explicitly flagged at the time. A live
staging login (provided by the user) surfaced two distinct, confirmed bugs:
a wrong request base path for every gamification endpoint (always 404),
and multiple wrong JSON field names in the dashboard/leaderboard parsers
(would have silently defaulted to zero/empty instead of erroring). A third,
separate issue (analytics 402s flattened into a generic error) was found
and fixed in the same pass.

## Symptoms
Not yet user-visible (caught before any user tested the rebuilt dashboard)
— found during a deliberate live-verification pass requested right after
the feature build. Expected symptom if shipped unverified: every
gamification widget (StreakToday, AchievementGrid weekly/streak-grid
sections, Leaderboard) would have rendered as empty/zero despite the
account having real XP, streak, and achievement data.

## Environment Details
- **Server/Host:** `staging-student.hbca.tech` (main API) + its
  `/harness-stream/` reverse-proxy path (gamification/analytics backend)
- **Services Affected:** Flutter mobile app only — no backend change
- **Related Components:** `lib/features/gamification/`, `lib/features/
  analytics/`
- **Time First Observed:** During this session's live-verification pass,
  immediately after the 4-phase dashboard rebuild

## Investigation Steps

### 1. Initial Diagnosis
Logged into staging directly via `curl` with a real test account (provided
by the user) to compare actual API responses against what the Flutter
models assumed, rather than trusting the earlier TypeScript-derived guesses.

### 2. Root Cause Analysis
```bash
# Login to get a bearer token
curl -s -X POST https://staging-student.hbca.tech/api/auth/login/ \
  -H "Content-Type: application/json" -d '{"email":"...","password":"..."}'

# Guessed paths all 404'd
curl .../api/v1/analytics/gamification/dashboard            # 404
curl .../api/harness-stream/api/v1/analytics/gamification/dashboard  # 404

# Reading the web frontend's actual api client resolved it
grep -n "STREAM_API_URL" STUDENT/Frontend/src/features/gamification/api/gamificationApi.ts
# -> const STREAM_API_URL = import.meta.env.VITE_HARNESS_STREAM_URL || '/harness-stream';
# -> base = `${STREAM_API_URL}/api/v1/analytics/gamification${path}`
# i.e. /harness-stream/... is relative to the HOST ORIGIN, not nested under /api

# Confirmed correct path:
curl https://staging-student.hbca.tech/harness-stream/api/v1/analytics/gamification/dashboard  # 200
```

### 3. Key Findings
- **Base path bug:** `GamificationRepositoryImpl` used `static const _base
  = '/harness-stream/api/v1/analytics/gamification'` as a path relative to
  Dio's `baseUrl` (`.../api`), producing `.../api/harness-stream/...`,
  which 404s. The real path is `/harness-stream/api/v1/...` on the host's
  origin, bypassing the `/api` prefix entirely — confirmed by reading the
  web frontend's own `gamificationApi.ts`, not by further guessing.
- **Field-name mismatches**, confirmed against the real `GET .../dashboard`
  response body:
  - `title` (not `level_title`) for the level title
  - `current_streak`/`longest_streak` top-level (not nested under a
    `streak: {today, longest}` object that doesn't exist in the real
    response)
  - `weekly` (not `weekly_momentum`), containing `total_questions` (not
    `questions`)
  - `consistency` (not `last_30_days`), each entry keyed `day` (not `date`)
  - `freezes` is an object (`{banked, max, earn_every, used}`), not a
    number — `streakFreezes` needs `freezes.banked`
  - Leaderboard's ranked list is `rows` (not `entries`/`leaderboard`), each
    row uses `display_name`/`score` (not `name`/`value`), and the total
    count is `total_ranked` (not `total_participants`)
- **Separate finding, same pass:** `/ai/analytics/...` endpoints correctly
  resolve (no path bug), but an account with an expired/inactive
  subscription gets a `402 {"error":"Subscription expired","upgradeUrl":
  "/subscription"}` response that `AnalyticsRepositoryImpl` flattened into
  a generic `NetworkFailure` — losing the real, user-relevant message and
  giving no path to the subscription page.

## Root Cause
The gamification/analytics data layer was built from frontend TypeScript
*usage* (confirmed research, not guessing) but without executing a single
real HTTP request against the live backend before shipping the code — the
`/harness-stream` proxy's non-`/api`-relative base path and the backend's
actual snake_case field choices were both things that could only be
confirmed by either reading the frontend's HTTP client config file
directly (which was in scope but not re-checked at implementation time)
or by a live call. This was explicitly flagged as an unverified risk in
the phase-1 report; it was real.

## Prevention / Rule
**Guardrail:** Any new Flutter repository that talks to an endpoint whose
exact base path or response shape was inferred from another codebase (web
frontend, API docs, etc.) rather than read from that *exact* client's
request-building code must have at least one live request executed
against a real backend (even a one-off `curl` with a test account) before
the PR/session is considered complete — not deferred to "verify later."

This closes the specific gap here because both bugs (wrong origin-relative
path, wrong field names) are structurally undetectable by `flutter
analyze`/`flutter test` with mocked data — they only fail against the real
server, and a single real request against each new endpoint would have
caught both on the first try.

## Solution

### Immediate Fix
- `GamificationRepositoryImpl`: replaced the hardcoded relative `_base`
  with a computed origin-based URL derived from `_dio.options.baseUrl`'s
  scheme/host/port, confirmed against a live 200 response.
- `GamificationDashboardModel`/`LeaderboardModel`: added the confirmed real
  field names as the primary parse path, keeping the old guessed names as
  fallbacks (defensive, in case of backend variance across account types).
- `AnalyticsRepositoryImpl`/`AnalyticsBloc`: added a `SubscriptionFailure`
  branch on HTTP 402, surfaced as a distinct `AnalyticsSubscriptionRequired`
  state with a "Subscribe to unlock analytics" CTA linking to `/subscription`
  instead of a generic error message.

```bash
cd STUDENT/mobile_flutter && flutter analyze && flutter test
# zero errors, 17 passed / 1 pre-existing skip, after all fixes
```

### Long-term Fix
None needed beyond the above — this is now live-verified, not inferred.
Notifications and subscription models were checked in the same pass and
were already correct (no fix needed there).

## Prevention
- [x] Code changes required — done, see Solution above
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none for this specific issue
- [ ] Documentation to update — none beyond this log entry

## Related Issues
- `reports/HBEC-2026-11-03-flutter-dashboard-parity-phase1-2.md` — the
  feature build this verification pass followed up on; that report's
  "Decisions & Findings" section originally flagged these exact endpoints
  as unverified.

## References
- `STUDENT/Frontend/src/features/gamification/api/gamificationApi.ts`
  (ground truth for the `/harness-stream` base path)
- `STUDENT/mobile_flutter/lib/features/gamification/`
- `STUDENT/mobile_flutter/lib/features/analytics/`

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** Same session as the original build (~30 min live
-verification + fix pass)

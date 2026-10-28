# Mobile app unexpectedly logs users out (refresh token discarded)

**Date:** 2026-10-28
**Project:** CRM (Myra)
**Environment:** Production/Development (affects both — depends only on `SIMPLE_JWT` config and mobile client code, not environment)
**Severity:** High
**Status:** Resolved

## Summary
The Expo/React Native mobile app was logging users out roughly every 30-60
minutes of active use. Root cause: a mismatch between the backend's JWT
refresh-token rotation policy and the mobile client's token-persistence
logic — the client discarded the rotated refresh token the backend issued
on every refresh call.

## Symptoms
- Reported via ProjectFlow task "App: logging out" — "The app is logging
  the user out."
- Users bounced to the login screen mid-session with no action on their
  part.

## Environment Details
- **Server/Host:** CRM backend (Django + DRF + simplejwt)
- **Services Affected:** `mobile` app (Expo/React Native), all authenticated
  API calls
- **Related Components:**
  - `backend/config/settings/base.py:120-126` (`SIMPLE_JWT` config)
  - `mobile/src/services/api.ts` (axios response interceptor / token refresh)
- **Time First Observed:** Reported prior to 2026-10-28; investigated and
  fixed this session.

## Investigation Steps

### 1. Initial Diagnosis
Checked `mobile/src/features/auth/store.ts` and `api.ts` for anywhere
`logout()` gets called unexpectedly. Found three call sites: two are
explicit user-initiated logout buttons; the third, `useProfile`'s
`meta.onError: () => logout()` in `features/auth/api.ts`, turned out to be
dead code under TanStack Query v5 (per-query `onError` was removed in v5;
`meta` callbacks only fire if wired through a global `QueryCache`, which
this app's `queryClient.ts` does not configure) — ruled out as the cause,
but flagged separately as broken error handling.

### 2. Root Cause Analysis
Checked backend JWT settings:
```
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    ...
}
```
`ROTATE_REFRESH_TOKENS` + `BLACKLIST_AFTER_ROTATION` means every call to
`/api/v1/auth/token/refresh/` returns a *new* refresh token and blacklists
the one that was just used.

Checked the mobile client's refresh handler in the axios response
interceptor (`mobile/src/services/api.ts`):
```ts
const { data } = await axios.post(
  `${API_BASE_URL}/api/v1/auth/token/refresh/`,
  { refresh: refreshToken }
);
await SecureStore.setItemAsync('accessToken', data.access);
// data.refresh (the newly rotated token) was never saved
processQueue(null, data.access);
```
Only `data.access` was persisted; the rotated `data.refresh` was dropped on
the floor, leaving the stale (and now server-side blacklisted) refresh
token in `SecureStore`.

### 3. Key Findings
- Access tokens expire every 30 minutes, so the bug reproduces reliably:
  the first refresh succeeds (old refresh token still valid at that point),
  but the *second* refresh attempt sends the already-blacklisted token,
  gets rejected, and the client's catch block wipes both tokens and
  force-logs-out the user.
- This is a one-directional mismatch: the backend's rotation policy is
  correct and intentional; the client simply never finished implementing
  rotation support.

## Root Cause
Backend-enforced refresh-token rotation (`ROTATE_REFRESH_TOKENS: True`,
`BLACKLIST_AFTER_ROTATION: True`) was never matched by client-side logic to
persist the newly issued refresh token after each refresh call.

## Prevention / Rule
**Guardrail:** Any client codebase that talks to a `simplejwt` backend with
`ROTATE_REFRESH_TOKENS` enabled must have an integration test that performs
two consecutive refresh cycles back-to-back and asserts the second succeeds
— this is the only way to catch "only the access token gets persisted"
regressions, since a single-refresh test (the common case) can't distinguish
correct behavior from this bug.

This closes the gap because the earlier symptom (occasional unexplained
logout) only manifests on the *second* refresh in a token's rotation chain,
which a naive single-cycle test would never exercise.

## Solution

### Immediate Fix
`mobile/src/services/api.ts`: persist `data.refresh` to `SecureStore`
alongside `data.access` after every successful token refresh.
```ts
await SecureStore.setItemAsync('accessToken', data.access);
if (data.refresh) {
  await SecureStore.setItemAsync('refreshToken', data.refresh);
}
```
Committed as `4ff3102` in the `crm` repo.

### Long-term Fix
Add the two-consecutive-refresh-cycle integration test described in
Prevention/Rule above, ideally as a Detox/E2E test or a focused unit test
against a mocked `/auth/token/refresh/` response pair.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done — `mobile/src/services/api.ts`)
- [ ] Add double-refresh-cycle regression test (not yet done)

## Related Issues
- Found alongside this bug, now resolved: `useProfile`'s
  `meta.onSuccess`/`meta.onError` in `mobile/src/features/auth/api.ts` were
  dead code under TanStack Query v5 (per-query `onSuccess`/`onError` were
  removed in v5; `meta` callbacks only fire via a global `QueryCache`
  handler, which this app never configured). Replaced with `useEffect`s
  reacting to the query's own `data`/`isError` state, so `setUser()` on
  success and `logout()` on failure actually run now. Fixed in `crm@b662edf`.

## References
- `mobile/src/services/api.ts`
- `backend/config/settings/base.py:120-126`
- ProjectFlow task: "App: logging out" (Myra project)

---

**Resolved By:** Tinotenda Mupezeni (via Claude Code)
**Time to Resolution:** Same session (investigation + fix).

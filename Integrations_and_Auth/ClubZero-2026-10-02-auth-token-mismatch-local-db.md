# Auth Token Mismatch Due to Local DB Migration

**Date:** 2026-10-02
**Project:** Club Zero
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The Flutter mobile app successfully built and ran but failed to load any data on the dashboard, repeatedly returning 401 Unauthorized errors on API calls (`/clubs/me`). 

## Symptoms
- The app appeared to be logged in (routing to the Dashboard) but data was missing.
- Backend API logs showed successful `POST /auth/refresh` returning 200 OK, but subsequent requests to authenticated endpoints returned 401.
- `flutter run` logs showed: `>>> getMyClubs status: 401` and `{"detail":"Could not validate credentials"}`.

## Environment Details
- **Server/Host:** Localhost (192.168.60.227)
- **Services Affected:** FastAPI Backend, Flutter Mobile App
- **Related Components:** JWT Authentication, Local Database
- **Time First Observed:** 2026-10-02

## Investigation Steps

### 1. Initial Diagnosis
Checked `auth_provider.dart` to see how the app handles 401s. It was observed that `_tryAutoLogin()` calls `_authService.refresh(refreshToken)`.

### 2. Root Cause Analysis
The app was previously pointing to the production database and had a valid refresh token saved in device storage. Because the local backend shared the same default `SECRET_KEY` as production, the `POST /auth/refresh` call successfully decoded the JWT and issued a new access token without querying the database. However, when the app used this new access token to query `/clubs/me`, the `get_current_user` dependency queried the newly spun-up, empty local database for the user ID (`sub`), found nothing, and threw a 401.

### 3. Key Findings
- `POST /auth/refresh` does not validate the existence of the user in the database before issuing a new token.
- The app's `AuthProvider` does not automatically log the user out and clear tokens upon receiving a 401 on standard authenticated routes; it only does so if the refresh route itself fails.

## Root Cause
The saved JWT on the mobile device contained a valid signature but referenced a user ID that did not exist in the fresh local database environment. 

## Prevention / Rule
**Guardrail:** Ensure the `SECRET_KEY` used for JWT generation differs strictly between environments (local, staging, prod) via enforced `.env` validation, OR implement a database check within the refresh token endpoint to ensure the user still exists.
Enforcing distinct keys ensures that a token from Prod will instantly fail signature validation on Local, preventing misleading "half-authenticated" states.

## Solution

### Immediate Fix
Cleared the app's local storage via ADB to wipe the stale production tokens and force a clean login flow.
```bash
adb shell pm clear com.example.club_zero_mobile
```

### Long-term Fix
- Update backend configuration to enforce unique `SECRET_KEY` per environment.
- Add an interceptor or global error handler in the Flutter app to automatically dispatch a logout event and clear local storage whenever a 401 response is encountered on any API route.

## Prevention
- [x] Configuration changes needed (Environment specific keys)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (Global 401 handler)

## Related Issues
- None

## References
- None

---

**Resolved By:** Antigravity
**Time to Resolution:** 15m

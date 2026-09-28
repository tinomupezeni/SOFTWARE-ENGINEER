# The mobile app's "Check In" button can never succeed — it calls a URL the backend doesn't have

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** Critical (this is the app's single core action — the entire "multiplayer habit tracker" product has no working check-in path)
**Status:** Resolved

## Summary
`ClubService.checkIn()` in the Flutter client posts to
`$baseUrl/clubs/$clubId/checkin`, but the FastAPI backend only registers
`POST /clubs/{club_id}/check-in` (with a hyphen), in
`club-zero-backend/app/routers/checkins.py`. Every check-in attempt from
the mobile app will hit FastAPI's default 404 handler instead of the
real endpoint. Since "tap Check In" is the entire product's core loop
(per the PRD's 3.2 Daily Check-In journey and the vision doc's whole
premise), this means the app's primary feature has never worked
end-to-end, even though the backend itself is correctly implemented and
covered by passing tests.

## Symptoms
- Tapping "Check In" in the Flutter app would surface a generic
  `Exception` (from `club_service.dart`'s `throw Exception(response.body)`
  branch) built from a FastAPI 404 JSON body, not the real check-in
  response.
- No check-in row would ever be written, no `check_in_completed` Redis
  event would ever be published, and other club members would never see
  a friend's avatar light up — because the request never reaches
  `checkins.py`'s handler at all.
- Backend-side, `tests/test_checkins.py` passes cleanly, because it calls
  the correct `/clubs/{club_id}/check-in` path directly — masking this
  from any backend-only test run.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend at
  `club-zero-backend/app/routers/checkins.py:12`)
- **Services Affected:** `club_zero_mobile` Flutter client, `ClubService.checkIn`
  (`club_zero_mobile/lib/services/club_service.dart:85`)
- **Related Components:** `DashboardProvider.checkIn()`
  (`club_zero_mobile/lib/providers/dashboard_provider.dart:84-95`), which
  calls `ClubService.checkIn` and relies on the WebSocket broadcast that
  never fires because the write never happens.
- **Time First Observed:** Found during a full codebase read, 2026-09-28.

## Investigation Steps

### 1. Initial Diagnosis
While reading through the mobile → backend request flow for the daily
check-in feature, compared the client's request URL against the
backend's registered route.

### 2. Root Cause Analysis
```
# Backend route (club-zero-backend/app/routers/checkins.py:10-12)
router = APIRouter(prefix="/clubs", tags=["checkins"])
@router.post("/{club_id}/check-in", ...)

# Mobile client (club_zero_mobile/lib/services/club_service.dart:85)
final url = Uri.parse('$baseUrl/clubs/$clubId/checkin');
```
`check-in` (hyphenated) vs. `checkin` (no hyphen) — a plain string
mismatch between the two sides of the same feature, with no shared
contract (OpenAPI client, constants file, etc.) to catch the drift.

### 3. Key Findings
- The backend implementation and its test suite (`test_checkins.py`) are
  correct and internally consistent — the bug is entirely in the mobile
  client's hardcoded URL.
- Nothing in the codebase generates the Flutter HTTP calls from the
  FastAPI OpenAPI schema, so there's no automated check that would catch
  a client route drifting from a server route.

## Root Cause
The mobile client's endpoint path was hand-typed independently of the
backend's route definition, and the two were never reconciled — the
client uses `checkin`, the server defines `check-in`.

## Prevention / Rule
**Guardrail:** Add an integration test (or a contract check against the
backend's generated OpenAPI schema) that exercises the mobile client's
actual `ClubService` HTTP calls against a running backend instance, so a
path/verb mismatch fails CI instead of surfacing only as a silent 404 at
runtime.

Neither side's own test suite can catch this class of bug alone — the
backend tests hard-code the correct path, and the mobile client has no
tests that hit a real or mocked backend at all. Only a cross-boundary
check closes this gap.

## Solution

### Immediate Fix
Changed `club_zero_mobile/lib/services/club_service.dart:85` from
`'$baseUrl/clubs/$clubId/checkin'` to `'$baseUrl/clubs/$clubId/check-in'`.
Verified with a manual end-to-end run against the FastAPI app (SQLite
in-memory DB, real Redis) hitting the exact hyphenated path the client
now uses: `POST /clubs/{club_id}/check-in` returned `201` with the
expected `CheckInResponse` body.

### Long-term Fix
Consider generating the Flutter API client from the FastAPI OpenAPI
schema (or centralizing all route path strings in one shared constants
file on each side) so this class of drift is structurally prevented
rather than caught by inspection. Not done in this pass.

## Prevention
- [x] Fix the path in `club_service.dart`
- [ ] Add a mobile-to-backend integration test for the check-in flow
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- None filed yet.

## References
- `club-zero-backend/app/routers/checkins.py`
- `club_zero_mobile/lib/services/club_service.dart`
- `club-zero-backend/tests/test_checkins.py`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.

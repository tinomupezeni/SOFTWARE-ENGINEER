# Every check-in from the mobile app 422'd — the client sent `check_in_date`, the backend expects `local_date`

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** Critical — the app's core action, again (a second, independent bug in the same feature as the earlier URL-path mismatch)
**Status:** Resolved

## Summary
After fixing the check-in endpoint's URL path mismatch earlier this
session (`checkin` vs `check-in`), live-testing the actual "tap to check
in" flow on a physical device still failed. The backend's
`CheckInCreate` schema (`app/schemas.py`) expects a JSON body with a
`local_date` field; `ClubService.checkIn()` in the Flutter client was
sending `check_in_date` instead. FastAPI's request validation rejected
every request with a 422, since the required `local_date` field was
simply missing from the payload.

## Symptoms
- Backend logs: `POST /clubs/{id}/check-in HTTP/1.1" 422 Unprocessable
  Entity` on every attempt from the app.
- This was never caught by the backend's own `pytest` suite
  (`test_checkins.py`), which correctly uses `local_date` in its own
  payloads — the mismatch only existed on the mobile side.
- Not caught by this session's earlier `curl`-based smoke tests either,
  since those were hand-written directly against the documented schema
  (`local_date`) rather than through the actual mobile client code path.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend + physical Android device)
- **Services Affected:** `club_zero_mobile/lib/services/club_service.dart`
  (`checkIn` method)
- **Time First Observed:** 2026-09-28, live-testing on a physical device
  after the URL-path fix.

## Investigation Steps

### 1. Initial Diagnosis
Tapped "Complete Protocols" on the dashboard; watched `docker compose
logs api -f` for the resulting request.

### 2. Root Cause Analysis
```dart
// club_service.dart (before fix)
body: jsonEncode({'check_in_date': checkInDate}),
```
```python
# schemas.py — what the backend actually expects
class CheckInCreate(BaseModel):
    local_date: date
```
Same class of bug as the earlier check-in path mismatch: the mobile
client's request shape was hand-typed independently of the backend's
actual schema, with nothing to catch the two drifting apart.

### 3. Key Findings
- This is the second independent bug found in the same feature within
  this session (see the earlier `check-in`-vs-`checkin` URL path entry).
  Both point at the same underlying gap: there is no generated or shared
  client for the mobile app, so every request shape is hand-typed and
  can silently diverge from the backend's actual contract.

## Root Cause
The mobile client's request body field name was hand-typed independently
of the backend's Pydantic schema and never reconciled against it.

## Prevention / Rule
**Guardrail:** Same as the earlier check-in path bug — a contract test
(or a generated client from the FastAPI OpenAPI schema) that exercises
the mobile client's actual HTTP calls against a running backend would
catch a body-shape mismatch exactly like this one. Two independent bugs
in the same single request, both invisible to each side's own tests, is
a strong signal this guardrail is worth building rather than deferring
again.

## Solution

### Immediate Fix
Changed `club_service.dart`'s `checkIn()`:
`jsonEncode({'check_in_date': checkInDate})` →
`jsonEncode({'local_date': checkInDate})`. Verified live on the physical
device: tapping "Complete Protocols" now returns 201 and the day
correctly marks complete.

### Long-term Fix
Not done in this pass — see the cross-boundary contract test called for
in the earlier check-in-path bug entry; the same fix covers this class of
bug too.

## Prevention
- [x] Fix the field name in `club_service.dart`
- [ ] Add a mobile-to-backend contract test for the check-in request body
- [ ] Documentation to update

## Related Issues
- `Mobile_Apps/CLUBZERO-2026-09-28-mobile-checkin-endpoint-mismatch.md` —
  the first bug in this same feature, found and fixed earlier the same
  session.

## References
- `club_zero_mobile/lib/services/club_service.dart`
- `club-zero-backend/app/schemas.py`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.

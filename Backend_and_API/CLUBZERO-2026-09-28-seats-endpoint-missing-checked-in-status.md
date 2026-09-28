# A friend's lit-up avatar only appeared if they checked in *after* you opened the dashboard — `/seats` never told the client who was already checked in

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** High — silently showed stale/wrong ambient-awareness state, the product's core mechanic, with no error anywhere
**Status:** Resolved

## Summary
`DashboardProvider._checkedInUsers` (the set driving which seat avatars
light up, and whether the bottom button reads "ALL COMPLETED") was only
ever populated from live `check_in_completed` WebSocket events received
*after* the dashboard screen opened and connected. `GET
/clubs/{id}/seats` — the endpoint used to hydrate the dashboard's initial
state — never included each member's checked-in status for the day, so
there was no way to correctly show that state on first load. A user who
opened the dashboard after a friend had already checked in earlier that
day would see that friend's avatar as not-done until some *new*
check-in-related event happened to arrive over the socket.

## Symptoms
- Reported directly by the user: "not showing which club members have
  done the tasks and which ones have checked in to done."
- Per-habit "Done by" lists were unaffected (that data was already
  correctly included in the initial `/seats` response) — only the
  day-level "checked in" / avatar-lighting state was wrong on first load.
- No error anywhere; the UI just silently displayed stale data as if it
  were current.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend + physical Android device)
- **Services Affected:** `club-zero-backend/app/routers/clubs.py`
  (`get_seats`), `club_zero_mobile/lib/providers/dashboard_provider.dart`
  (`_fetchSeats`)
- **Time First Observed:** 2026-09-28, live-testing multi-member dashboard
  state.

## Investigation Steps

### 1. Initial Diagnosis
Compared what `GET /seats` actually returns against what
`DashboardProvider` reads to populate `_checkedInUsers` — found the
client only ever adds to that set inside the WebSocket's
`check_in_completed` case, never from the initial HTTP fetch.

### 2. Root Cause Analysis
```python
# clubs.py get_seats (before fix) — members list had no checked-in info
members = [
    {"user_id": str(m.ClubMember.user_id), "name": m.display_name, "is_user": True}
    for m in member_result.all()
]
```
```dart
// dashboard_provider.dart — _checkedInUsers populated ONLY here:
case 'check_in_completed':
  if (data['check_in_date'] == today) {
    _checkedInUsers.add(data['user_id'].toString());
    ...
```
There was no code path that ever added to `_checkedInUsers` from the
initial `_fetchSeats()` call — the set started empty every time the
dashboard opened, regardless of actual state in the database.

### 3. Key Findings
- The per-habit `completed_by` data didn't have this bug because it was
  explicitly built into `get_seats`'s response from the start; the
  day-level "checked in" concept (the original `CheckIn` model, predating
  the habit-tracking work) was simply never extended the same way when
  the dashboard's initial-load path was built.

## Root Cause
`GET /clubs/{id}/seats` was never extended to report each member's
day-level check-in status, so the mobile client had no way to hydrate
that specific piece of state on load — only ever accumulating it from
events received after the fact.

## Prevention / Rule
**Guardrail:** Any piece of state a dashboard shows that can change via a
WebSocket event must also be fully derivable from that screen's initial
REST fetch — a WS event should update existing state, never be the only
way that state is ever populated in the first place. When adding a new
WS event type, check the corresponding initial-load endpoint already
returns equivalent data; if it doesn't, that's the same bug again.

## Solution

### Immediate Fix
`get_seats` now also queries `CheckIn` for the target date and includes a
`"checked_in": bool` field on each member object. `DashboardProvider._fetchSeats`
now populates `_checkedInUsers` from that field on every fetch (clearing
and rebuilding the set, so it also correctly reflects state after
switching clubs or re-fetching). Verified via a backend smoke test
(register, check in, fetch `/seats`, confirm `checked_in: true` appears
immediately, no WS connection involved) and live on the physical device.

### Long-term Fix
Done — see Immediate Fix. No further work needed for this specific gap.

## Prevention
- [x] Add `checked_in` to each member in `GET /seats`
- [x] Hydrate `_checkedInUsers` from the initial fetch, not just WS events
- [x] Verify via a direct backend smoke test independent of the WebSocket
- [ ] Add a `pytest` case asserting `checked_in` reflects a real `CheckIn`
      row (currently only manually verified)

## Related Issues
- None filed yet.

## References
- `club-zero-backend/app/routers/clubs.py`
- `club_zero_mobile/lib/providers/dashboard_provider.dart`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.

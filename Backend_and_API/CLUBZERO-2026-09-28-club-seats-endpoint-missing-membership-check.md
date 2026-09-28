# `GET /clubs/{club_id}/seats` lets any logged-in user view any club's members and pending invites

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** High (direct violation of the project's own stated NFR: "Users must only be able to query check-in/club data for their own Club members")
**Status:** Resolved

## Summary
`GET /clubs/{club_id}/seats` in `club-zero-backend/app/routers/clubs.py`
requires a valid JWT (`get_current_user`) but never checks that the
requesting user is actually a member of `club_id`. Any authenticated
user who guesses or observes a club's UUID can read that club's full
member list (display names, user IDs) and its pending invite list
(invited email addresses), regardless of whether they belong to it. This
directly contradicts SRS §3.4 ("Data Isolation: Users must only be able
to query check-in data for their own Club members via strict Row Level
Security (RLS) policies") — there is no equivalent authorization check
in the application layer either.

## Symptoms
- No visible symptom in normal use, since club IDs are UUIDs and aren't
  exposed in any listing endpoint to non-members. This is a latent
  authorization gap rather than something currently triggering visibly.
- Any client (or anyone who obtains a club ID, e.g. via a leaked invite
  link, logs, or brute-force enumeration of the small UUID-keyed
  endpoint) can call the endpoint successfully with any valid account's
  token and receive member names, user IDs, and invited emails for a
  club they never joined.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend)
- **Services Affected:** `club-zero-backend/app/routers/clubs.py`,
  `get_seats` handler (lines 120-153)
- **Related Components:** Contrast with `checkins.py:14-17`, which
  correctly checks `ClubMember` before allowing a check-in — the same
  pattern is missing here.
- **Time First Observed:** Found during a full codebase read, 2026-09-28.

## Investigation Steps

### 1. Initial Diagnosis
Compared every `clubs.py` / `checkins.py` route's authorization logic
against the SRS's explicit data-isolation requirement.

### 2. Root Cause Analysis
```python
# club-zero-backend/app/routers/clubs.py:120-125
@router.get("/{club_id}/seats")
async def get_seats(
    club_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session)
):
    # No check that current_user is a ClubMember of club_id before
    # querying and returning its members/invites below.
```
Every other mutating route in this file/`checkins.py` (`join_club`,
`create_checkin`) does verify membership or an equivalent business rule
before proceeding; `get_seats` was written without the same guard.

### 3. Key Findings
- `get_my_clubs` (`/clubs/me`) correctly scopes results to the current
  user via a `ClubMember` join — the pattern for "how to scope by
  membership" already exists in the same file, just wasn't applied here.
- No test in `tests/test_clubs.py` currently exercises a non-member
  calling `/seats`, so this gap wasn't caught by the existing suite.

## Root Cause
`get_seats` authenticates the caller but never authorizes them against
the specific club being queried — an authorization check present on
sibling endpoints was omitted on this one.

## Prevention / Rule
**Guardrail:** Add a `test_clubs.py` case asserting a non-member gets
403 from `/clubs/{club_id}/seats` (mirroring the existing
`test_check_in_not_member_forbidden` pattern in `test_checkins.py`), and
add the same `ClubMember` membership check used in `checkins.py:14-17`
to `get_seats` before it returns any data.

Reusing the existing membership-check pattern closes this specific gap;
a companion test at the same granularity as the checkins tests prevents
this endpoint (or a future one) from regressing to unauthenticated-scope
access silently.

## Solution

### Immediate Fix
Added the same `ClubMember` membership check used in `checkins.py` to
the top of `get_seats` in `club-zero-backend/app/routers/clubs.py`,
returning `403 Not a member of this club` before any query runs.
Verified manually: a club creator's token gets `200` from
`/clubs/{club_id}/seats`; a second, non-member user's token against the
same club gets `403 {"detail": "Not a member of this club"}`.

### Long-term Fix
Add a `test_clubs.py` regression test asserting the 403 (not done in
this pass — logged as a follow-up below).

## Prevention
- [x] Add membership check to `get_seats`
- [ ] Add a regression test for non-member access to `/seats`
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- None filed yet.

## References
- `club-zero-backend/app/routers/clubs.py`
- `club-zero-backend/app/routers/checkins.py`
- `docs/requirements/srs.md` §3.4

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.

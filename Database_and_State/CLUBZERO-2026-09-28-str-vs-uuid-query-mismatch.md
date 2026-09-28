# Every authenticated request crashed under the SQLite test backend — JWT `sub` and `{club_id}` path params were queried against `Uuid` columns as raw strings

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** High (broke every authenticated request path in the test suite; a latent type-safety gap in production routes too)
**Status:** Resolved

## Summary
While getting the backend test suite running again (see
[[CLUBZERO-2026-09-28-test-suite-could-not-even-collect]]) in order to
verify fixes for other Club Zero bugs, every test that hit an
authenticated endpoint failed with
`sqlalchemy.exc.StatementError: (builtins.AttributeError) 'str' object has no attribute 'hex'`.
Two call sites compared a Python `str` directly against a SQLAlchemy
`Uuid(as_uuid=True)` column: `get_current_user` in `dependencies.py`
(and its WebSocket twin `get_ws_user` in `websockets.py`) took the raw
`sub` claim straight out of the decoded JWT and queried `User.id ==
user_id` without ever calling `uuid.UUID(user_id)`. Separately, every
router path operation that declared `club_id: str` (in `clubs.py` and
`checkins.py`) queried `Club.id == club_id` / `ClubMember.club_id ==
club_id` the same way. Under the SQLite dialect used by the test suite,
SQLAlchemy's generic `Uuid` type's bind processor calls `.hex` directly
on the bound value, which a plain `str` doesn't have.

## Symptoms
- `pytest` failures on every test that authenticates and then queries by
  ID: `test_check_in_success`, `test_check_in_duplicate_prevented`,
  `test_check_in_not_member_forbidden`, `test_join_club_enforces_max_four`
  (all in `test_checkins.py` / `test_clubs.py`), each raising the same
  `'str' object has no attribute 'hex'` `StatementError`.
- `test_create_club_success` and `test_login_success` passed even before
  this fix — they only touch `get_current_user` on a session-derived
  token wired through `db.refresh()`, or don't query by UUID at all, so
  they didn't happen to exercise this path the same way.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend, SQLite in-memory test DB)
- **Services Affected:** `club-zero-backend/app/dependencies.py`
  (`get_current_user`), `club-zero-backend/app/routers/websockets.py`
  (`get_ws_user`), `club-zero-backend/app/routers/clubs.py`
  (`join_club`, `get_seats`), `club-zero-backend/app/routers/checkins.py`
  (`create_checkin`)
- **Related Components:** `app/models.py`'s `User.id` / `Club.id` /
  `ClubMember.club_id` columns, all `Uuid(as_uuid=True)`.
- **Time First Observed:** 2026-09-28, while running the test suite for
  the first time after fixing its collection errors.

## Investigation Steps

### 1. Initial Diagnosis
After fixing the test suite's import/dependency errors, re-ran `pytest`
and got a new class of failure on every authenticated-endpoint test.

### 2. Root Cause Analysis
```python
# app/dependencies.py (before fix)
user_id: str = payload.get("sub")
...
result = await db.execute(select(User).where(User.id == user_id))
# user_id is a plain str; User.id is Uuid(as_uuid=True)
```
```python
# app/routers/clubs.py / checkins.py (before fix)
async def join_club(club_id: str, ...):          # FastAPI never coerces this to UUID
    result = await db.execute(select(Club).where(Club.id == club_id))
```
SQLAlchemy's generic (non-native) `Uuid` bind processor assumes it's
handed an actual `uuid.UUID` instance so it can call `.hex`; a `str`
breaks that assumption. This is dialect-dependent — dialects with a
native UUID type (e.g. Postgres via `asyncpg`, which this project runs
in production) are more forgiving of plain strings, which is likely why
this was never caught: the app has only ever been run against Postgres.

### 3. Key Findings
- This wasn't introduced by anything in this session — it's a
  pre-existing correctness gap that the SQLite-backed test suite is
  specifically well-positioned to catch (per its own comment: "ideal for
  API contract validation"), except the suite couldn't run at all until
  [[CLUBZERO-2026-09-28-test-suite-could-not-even-collect]] was fixed
  first.
- Declaring FastAPI path parameters as `club_id: str` instead of
  `club_id: UUID` also meant malformed club IDs would reach the DB layer
  at all, rather than FastAPI rejecting them with a `422` up front.

## Root Cause
Path/token identifiers were carried as raw strings from the HTTP/JWT
boundary all the way to ORM query comparisons against `Uuid` columns,
relying on dialect-specific leniency (Postgres/asyncpg) rather than
explicit typing.

## Prevention / Rule
**Guardrail:** Type every path parameter and JWT-derived identifier that
gets compared against a `Uuid(as_uuid=True)` column as `uuid.UUID` (via
FastAPI's automatic path-param coercion, or an explicit
`uuid.UUID(value)` cast) at the boundary, not at the query call site.
Running the test suite against SQLite (a dialect that enforces this
strictly) rather than only ever testing against Postgres is itself the
guardrail that catches a regression here — keep the SQLite test config
rather than switching it to Postgres for convenience.

## Solution

### Immediate Fix
- `app/dependencies.py`: `get_current_user` now does
  `user_uuid = uuid.UUID(user_id)` (raising `credentials_exception` on a
  malformed value) before querying `User.id == user_uuid`.
- `app/routers/websockets.py`: `get_ws_user` now wraps the query in
  `uuid.UUID(user_id)` the same way.
- `app/routers/clubs.py`: `join_club` and `get_seats` now declare
  `club_id: UUID` (from `uuid.UUID`) instead of `club_id: str`.
- `app/routers/checkins.py`: `create_checkin` now declares
  `club_id: UUID` the same way.
- `app/routers/websockets.py`: `websocket_endpoint` now declares
  `club_id: uuid.UUID`.

Verified: full `pytest` suite (9 tests) passes against the SQLite test
backend with a live Redis instance available.

### Long-term Fix
Done — see Immediate Fix. Worth a follow-up audit for any other
`str`-typed identifier compared against a `Uuid` column elsewhere in the
codebase, though none were found beyond the sites above.

## Prevention
- [x] Cast JWT `sub` to `uuid.UUID` before querying
- [x] Type all `{club_id}` path params as `UUID` instead of `str`
- [x] Re-ran full test suite to confirm the fix
- [ ] Documentation to update

## Related Issues
- [[CLUBZERO-2026-09-28-test-suite-could-not-even-collect]] — had to be
  fixed first to even discover this bug.

## References
- `club-zero-backend/app/dependencies.py`
- `club-zero-backend/app/routers/websockets.py`
- `club-zero-backend/app/routers/clubs.py`
- `club-zero-backend/app/routers/checkins.py`
- `club-zero-backend/app/models.py`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.

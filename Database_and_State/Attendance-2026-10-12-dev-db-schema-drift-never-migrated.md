# Dev database was built from a stale, pre-Alembic schema — records fetch 500'd on a column that never existed

**Date:** 2026-10-12
**Project:** Attendance (Verified Attendance Platform)
**Environment:** Development
**Severity:** Critical — any endpoint touching `attendance_events` with the current ORM models would 500 (confirmed for the mobile Records fetch; the check-in write path narrowly avoided it only because it hadn't been exercised yet this session)
**Status:** Resolved

## Summary
`GET /check-in/events/{employee_code}` (used by the mobile Records screen)
returned `500 Internal Server Error`. The traceback showed
`sqlalchemy.exc.ProgrammingError: column attendance_events.hardware_monotonic_nanoseconds
does not exist`. Inspecting the live table showed it was built from an
entirely different, older schema than the current SQLAlchemy models:
`hardware_monotonic_time` instead of `hardware_monotonic_nanoseconds`,
`gps_lat`/`gps_lng`/`gps_accuracy` instead of
`gps_latitude`/`gps_longitude`/`gps_accuracy_meters`, no
`reconstructed_event_timestamp` or `previous_event_hash` columns, and a
`device_id` foreign key pointing at a legacy `devices` table rather than
the current `employee_devices` table the ORM actually queries.
`alembic current` on this database returned nothing — no migration had
ever been applied here; the tables were created some other way (most
likely a one-off `Base.metadata.create_all()` or manual bootstrap early in
the project, before the schema now expected by `models.py` existed) and
then left behind as the models evolved.

## Symptoms
- `curl http://localhost:8010/check-in/events/EMP777` → `500 Internal
  Server Error` (and a Dio-level failure on the mobile Records tab).
- `alembic current` on the dev database returned empty output — no
  revision stamped at all, despite tables already existing with data in
  them.
- `admin/Dockerfile` (dev) has no entrypoint beyond `php artisan serve`;
  separately, `backend`'s dev `Dockerfile` has no entrypoint beyond
  `uvicorn ... --reload` — neither runs `alembic upgrade head`, unlike
  `backend/Dockerfile.production` (`docker-entrypoint.production.sh` does).

## Environment Details
- **Server/Host:** Local dev, `attendance-db-1` (Postgres/PostGIS,
  Docker-managed volume `attendance_postgres_data`), `attendance-backend-1`.
- **Services Affected:** `backend/app/routers/checkin.py`
  (`get_employee_events`), by extension any query touching
  `AttendanceEvent`/`VerificationEvidence` columns added after whatever
  point this dev schema was first created.
- **Time First Observed:** 2026-10-12, first mobile Records-tab fetch
  against this long-lived local dev database this session.

## Investigation Steps

### 1. Initial Diagnosis
Backend logs for the 500 showed the SQLAlchemy `ProgrammingError` directly
naming the missing column, pointing straight at a schema/model mismatch
rather than application logic.

### 2. Root Cause Analysis
```
$ docker compose exec backend alembic current
(no output — nothing stamped)

$ docker compose exec db psql ... -c "\d attendance_events"
 hardware_monotonic_time | bigint | not null     <- old name
 gps_lat / gps_lng / gps_accuracy                 <- old names
 device_id -> devices(id)                         <- legacy table, not employee_devices
```
Compared against `backend/migrations/versions/001_initial_event_sourced_schema.py`,
which defines `hardware_monotonic_nanoseconds`, `gps_latitude`,
`gps_longitude`, `gps_accuracy_meters`, `reconstructed_event_timestamp`,
and `previous_event_hash` — all absent from the live table. The two
`backend/migrations/001_initial_schema.sql`(/`.sql.bak`) raw-SQL files in
the same directory don't define `attendance_events` at all, so this
database's schema wasn't built from either of the migration mechanisms
present in the repo; it predates both.

### 3. Key Findings
- Neither the backend's nor the admin's **dev** Dockerfile runs any
  migration step — only `backend/Dockerfile.production` does, via
  `docker-entrypoint.production.sh`'s `alembic upgrade head`. A dev
  database can therefore accumulate indefinite schema drift from the
  actual models with zero automated signal, surfacing only the moment a
  query touches a changed column.
- `backend/migrations/001_initial_schema.sql` on disk is actually an
  **empty directory** (owned by `root`, dated 2026-10-05), not a file —
  almost certainly a Docker bind-mount artifact from some earlier run that
  tried to mount this path and auto-created a directory when the expected
  file wasn't there. Left as-is since it's inert, but worth a human's
  attention if that migration file was ever meant to exist as real SQL.

## Root Cause
The local dev Postgres database's schema was never created or kept in
sync via Alembic — it was built once, early in the project, from a schema
that has since diverged significantly from the current SQLAlchemy models,
and nothing in the dev Docker workflow runs migrations to catch or close
that drift automatically.

## Prevention / Rule
**Guardrail:** Give the backend's **dev** `Dockerfile` the same migration
entrypoint as `Dockerfile.production` (`alembic upgrade head` before
`uvicorn --reload`), so a dev database can never silently drift more than
one `docker compose up` behind the current models. This is the same
guardrail already proven out in production — it just needs to apply to
dev too.

## Solution

### Immediate Fix
This session's dev database held only disposable local test fixtures (1
employee, 2 workplaces, 3 legacy unlinked devices), so rather than hand-write
`ALTER TABLE` statements chasing every drifted column, the volume was
recreated from scratch and brought up to the current schema properly:
```
docker compose down
docker volume rm attendance_postgres_data   # user-approved, local dev data only
docker compose up -d
docker compose exec backend alembic upgrade head   # -> 001 (head)
```
Re-seeded the demo fixtures that existed before the reset (employee
`EMP777`/"Tino", workplace `ZINGSA` with a fresh geofence polygon, a new
device-pairing code) via the admin API, and verified
`GET /check-in/events/EMP777` now returns `200 {"employee_code": "EMP777",
"count": 0, "events": []}` instead of `500`.

### Long-term Fix
Add `alembic upgrade head` to the backend's dev `Dockerfile`/compose
startup (not just production), so this class of drift becomes structurally
impossible in local dev rather than something a developer discovers via a
500. Not done in this pass — flagged as the standing guardrail above.

## Prevention
- [x] Recreate the dev database schema correctly via Alembic
- [x] Re-seed the demo fixtures lost in the reset
- [ ] Add `alembic upgrade head` to the backend dev Dockerfile/compose
      startup
- [ ] Investigate the stray `backend/migrations/001_initial_schema.sql`
      directory (likely a bind-mount artifact) and the unused `.sql`/`.sql.bak`
      files for removal or reconciliation

## Related Issues
- `Mobile_Apps/Attendance-2026-10-12-checkin-field-name-schema-mismatch.md`
  — found immediately before this one, in the same check-in/records
  investigation; that bug was a mobile-client/backend contract mismatch,
  this one is a backend/database schema mismatch, but both surfaced from
  the same live-testing pass.

## References
- `backend/migrations/versions/001_initial_event_sourced_schema.py`
- `backend/app/models.py` (`AttendanceEvent`)
- `backend/Dockerfile` vs `backend/Dockerfile.production` /
  `backend/docker-entrypoint.production.sh`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-10-12.

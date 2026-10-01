# NOTIFICATIONS Crash-Looped On Production: `alembic_version` Was One Revision Behind The Actual Schema

**Date:** 2026-10-01
**Project:** HBEC
**Environment:** Production
**Severity:** Critical (service down)
**Status:** Resolved

## Summary
Immediately after a production promotion recreated `notifications-backend`,
the container entered a restart crash loop. The container's entrypoint
auto-runs `alembic upgrade head` on every boot, and migration `0005`'s
`ADD COLUMN` statements failed with "column already exists" — the schema
already had every change that migration would make, but `alembic_version`
was pinned one revision behind, at `0004`. This was leftover drift from an
earlier, much-earlier partial/accidental production deploy of the
Announcements feature, which had applied the DDL without ever advancing the
version pointer, and sat undetected until today's promotion restarted the
container and triggered the auto-migration path.

## Symptoms
```
sqlalchemy.exc.ProgrammingError: (sqlalchemy.dialects.postgresql.asyncpg.ProgrammingError) column "is_banner" of relation "notification_drafts" already exists
[SQL: ALTER TABLE notification_drafts ADD COLUMN is_banner BOOLEAN DEFAULT false NOT NULL]
```
`hbec-notifications-backend` restarted continuously; service unavailable.

## Environment Details
- **Server/Host:** Production VPS (`/opt/hbec`)
- **Services Affected:** `notifications-backend` (crash-looping);
  `notifications-worker`/`notifications-beat` unaffected (do not run
  migrations at startup, stayed healthy throughout)
- **Related Components:** `NOTIFICATIONS/alembic/versions/
  0005_notification_is_banner.py`, `hbec_notifications` Postgres database
- **Time First Observed:** Immediately after `docker compose up -d --wait`
  during today's full-catchup production promotion

## Investigation Steps

### 1. Initial Diagnosis
Read the crash-loop traceback: a plain "column already exists" on an
`ADD COLUMN` makes the hypothesis straightforward — the DDL this migration
performs is already present, but Alembic doesn't know that yet.

### 2. Root Cause Analysis
Connected directly to the production `hbec_notifications` database (correct
credentials recovered via
`docker exec hbec-notifications-worker env | grep DATABASE_URL`, since the
assumed username `hbca` was wrong) and confirmed, column by column, that
every DDL change migration `0005` makes was already physically present:

```sql
-- both already existed, boolean NOT NULL DEFAULT false, matching 0005 exactly
\d notification_drafts   -- is_banner present
\d notifications         -- is_banner present
SELECT indexname FROM pg_indexes WHERE tablename = 'notifications' AND indexname = 'ix_notifications_is_banner';
-- present

SELECT version_num FROM alembic_version;
-- 0004
```

### 3. Key Findings
- The schema reflects `0005`; the tracking table says `0004` — a pure
  bookkeeping mismatch, not a schema defect.
- Every container restart re-triggers `alembic upgrade head` via the
  entrypoint, so this was not a one-time failure but a permanent crash loop
  until fixed.
- `notifications-worker`/`-beat` share the same image and database but
  don't run migrations at startup, so they stayed healthy and usable as a
  stable place to run the fix from.

## Root Cause
An earlier, previously-flagged partial/accidental production deploy of the
Announcements feature applied migration `0005`'s DDL directly without its
corresponding `alembic_version` bump ever landing (or it landed and was
later rolled back incompletely). This left the database schema and
Alembic's own state pointer disagreeing, invisibly, until the next full
`alembic upgrade head` attempt — which arrived today's promotion restarted
the container.

## Prevention / Rule
**Guardrail:** Never deploy a service's migrations by any path other than
the full `alembic upgrade head` the entrypoint already runs — no manual
"just run this one ALTER" partial application. If a partial manual DDL
change is ever truly necessary as a hotfix, it must be immediately paired
with the matching `alembic stamp <revision>` in the same action, so the
tracking table and the schema can never diverge even transiently.

This closes the specific gap because the root cause was exactly a DDL
change applied outside of Alembic's own bookkeeping; requiring the stamp to
accompany any such change removes the window where they can disagree.

## Solution

### Immediate Fix
Verified the schema was identical to what `0005` would produce (not
assumed), then stamped the version forward without re-running DDL, from a
healthy sibling container sharing the same image/database:

```bash
docker exec hbec-notifications-worker alembic stamp 0005
```
`notifications-backend`'s next boot then cleanly auto-applied migration
`0006` (today's new `content_gap_resolutions` table, genuinely not yet
applied) and the container came up healthy.

### Long-term Fix
No code change — the fix is procedural (see Prevention/Rule above). The
drift was already a known, previously-flagged risk from an earlier session;
this incident is that exact predicted scenario materializing, now closed.

## Prevention
- [x] Documentation to update: this entry, closing out the
      previously-flagged open risk.
- [ ] Monitoring/alerts to add: consider a periodic check comparing
      `alembic_version` against the latest revision file per service, to
      catch drift before the next restart rather than at the next restart.
- [ ] Configuration changes needed: none.
- [ ] Code changes required: none.

## Related Issues
- This closes a risk flagged as open in an earlier session (the "is_banner
  schema vs. alembic version" mismatch noted as unresolved at the time).
- `reports/HBEC-2026-10-01-full-catchup-production-promotion.md`

## References
- `NOTIFICATIONS/alembic/versions/0005_notification_is_banner.py`
- `NOTIFICATIONS/alembic/versions/0006_content_gap_resolutions.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Diagnosed and fixed within the same promotion session, container recovered within minutes of the stamp.

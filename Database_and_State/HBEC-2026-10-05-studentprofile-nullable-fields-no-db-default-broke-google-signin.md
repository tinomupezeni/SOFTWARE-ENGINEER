# StudentProfile Fields Added Without a Persistent DB Default Broke Google Sign-In

**Date:** 2026-10-05
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
A Django migration (`0031_student_study_plan.py`) added 4 NOT NULL columns to
`accounts_studentprofile` with a Python-level `default=`. Discovered
accidentally today while testing an unrelated admin API login: Google
Sign-In had been failing with a 500 for every brand-new user since the
migration ran, because the old code still serving live production traffic
has no idea these columns exist, and Postgres had nothing to fall back to
for them.

## Symptoms
- `POST /api/auth/google/` returning 500 for new users.
- Surfaced via `system_error_logs` (cross-service error log), not a user
  report — found while verifying a new admin API login worked, which
  happened to hit that endpoint's listing.
- 39 occurrences between 2026-10-05 07:27 and 14:49 UTC, still ongoing at
  time of discovery.

## Environment Details
- **Server/Host:** hbca-vps, shared `hbec_student` Postgres database.
- **Services Affected:** `student-backend-blue` (serving 100% of real
  traffic) writing against a database schema that had already moved ahead
  of it.
- **Related Components:** blue-green deployment's shared-database model.

## Investigation Steps

### 1. Initial Diagnosis
Queried the error directly from `system_error_logs` (not raw container
logs): `IntegrityError: null value in column "daily_goal" ... violates
not-null constraint`, from `apps.accounts.views.py`'s Google sign-up path.

### 2. Root Cause Analysis
Checked the actual column state in Postgres:

```sql
SELECT column_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'accounts_studentprofile'
AND column_name IN ('daily_goal','reminder_days','reminder_time','reminders_enabled','last_reminded_on');
```

`column_default` was empty for all 4 NOT NULL fields the migration added,
despite each having a Python-level `default=` in the model. Confirmed why:
this blue-green deploy round built `student-backend-green` fresh today;
its container startup runs `migrate --noinput` automatically against the
one database blue and green share. The migration applied the Python
default only to backfill rows that existed *at migration time* — it never
issued a persistent `ALTER COLUMN ... SET DEFAULT`. `student-backend-blue`
(the old code still serving every real request) has no Python model field
for any of these 4 columns, so its ORM-generated INSERT for a new
`StudentProfile` omits them entirely — and with no database-level default
left behind, Postgres had nothing to use.

### 3. Key Findings
- Only 4 of the migration's 5 new fields are at risk — `last_reminded_on`
  is nullable, so it was never a problem.
- The harness's own Alembic migrations from the exact same deploy round do
  not have this gap — they explicitly pass `server_default=` (e.g.
  `sa.Column("actions", sa.Integer(), nullable=False, server_default="0")`),
  which Alembic turns into a true, persistent Postgres default. Django's
  bare `default=` kwarg on a model field does not do the equivalent; the
  asymmetry between the two migration frameworks in this codebase is the
  root cause, not something project-specific to this one migration.
- This is invisible to a purely textual migration-safety check: the
  migration file plainly shows `default=3` right next to the field — a
  keyword/pattern scan would call this safe, because the gap is in what
  Django's `AddField` *does* with that default, not in anything the
  migration's source text itself reveals as dangerous.

## Root Cause
Django's `AddField` operation with a Python-level `default=` only uses that
default to backfill existing rows at migration time. It does not leave a
database-level `DEFAULT` for rows inserted afterward by code that doesn't
know the field exists — exactly blue's situation for the duration of a
blue-green deploy against a shared database.

## Prevention / Rule
**Guardrail:** Any Django migration adding a NOT NULL field to a table that
a *shared-database, mixed-code-version* deployment (blue-green, or any
rolling deploy against one database) can touch must use `db_default=`
(Django 5.0+, generates a true Postgres column default) instead of, or
alongside, `default=`. A repo-wide check that greps new migrations for
`AddField` + `null=False`/no `null=True` + `default=` without an
accompanying `db_default=` would catch this at review time, before the
migration ever reaches a shared database the old code is still writing to.

This is the Django-side version of a lesson the harness's own Alembic
migrations already apply correctly — `server_default=` has been the
pattern there since the blue-green work began. The gap was that nothing
enforced the same discipline on the Django side.

## Solution

### Immediate Fix
Applied directly to the live, shared `hbec_student` database:

```sql
ALTER TABLE accounts_studentprofile ALTER COLUMN daily_goal SET DEFAULT 3;
ALTER TABLE accounts_studentprofile ALTER COLUMN reminder_time SET DEFAULT '17:00:00';
ALTER TABLE accounts_studentprofile ALTER COLUMN reminders_enabled SET DEFAULT true;
ALTER TABLE accounts_studentprofile ALTER COLUMN reminder_days SET DEFAULT '[0,1,2,3,4,5,6]'::jsonb;
```

### Long-term Fix
Committed `0033_studentprofile_persistent_defaults.py` (a `RunSQL`
migration applying the identical statements, with a `reverse_sql` that
drops them) so a fresh environment built from migrations alone — a new
local dev setup, a disaster-recovery restore — gets the same protection
the live database now has by hand, not just the one database this was
patched on directly.

## Prevention
- [ ] Configuration changes needed — none; this is a migration-authoring
      discipline gap, not a config gap.
- [ ] Monitoring/alerts to add — none added this pass; `system_error_logs`
      already caught this, the gap was nobody checking it proactively
      (separate, already-flagged conversation this session about adding a
      pull-and-resolve tool on top of that table).
- [ ] Documentation to update — the Guardrail above should fold into
      whatever migration-review checklist this project uses for
      blue-green-era Django migrations specifically.
- [x] Code changes required — done, see Solution above.

## Related Issues
- None filed separately; this is itself the first incident of this class
  on this project.

## References
- `STUDENT/hbec_backend/apps/accounts/migrations/0031_student_study_plan.py`
  (the original migration)
- `STUDENT/hbec_backend/apps/accounts/migrations/0033_studentprofile_persistent_defaults.py`
  (this fix)
- `AGENTIC_HARNESS/alembic/versions/039_add_daily_activity_actions.py` (the
  Alembic sibling that already does this correctly, used as the reference
  for what "right" looks like)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed within the same session the
automation (MCP error-log tool) work that surfaced it was happening.

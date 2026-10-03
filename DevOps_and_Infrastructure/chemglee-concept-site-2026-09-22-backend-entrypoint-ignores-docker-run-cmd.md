# Backend Docker Image's `ENTRYPOINT` Ignores Any `docker run` Command, Silently Running Real `migrate` Against the Mounted DB Instead

**Date:** 2026-09-22
**Project:** chemglee-concept-site
**Environment:** Development (local container run, testing a backend change)
**Severity:** Medium (no data loss, but silently mutated the local dev database when a test run was intended; the same trap would hit anyone using this image to run one-off management commands)
**Status:** Resolved (workaround documented; image not changed)

## Summary
While adding backend tests for a new feature, I tried to run the test suite
inside the already-built `chemglee-concept-site-backend:latest` image via
`docker run ... chemglee-concept-site-backend:latest python manage.py test ...`.
Instead of running the test command, the container always executed
`backend/entrypoint.sh`, which unconditionally runs
`python manage.py migrate --noinput` against the real configured database
before `exec`-ing Gunicorn — completely ignoring the command passed after
the image name. Because `docker-compose.yml`/`Dockerfile` point the default
sqlite `DATABASE_URL` at the mounted `backend/data/db.sqlite3` (the real
local dev database, not an isolated test DB), this applied pending Django
migrations (`orders.0008_paynowconfig` etc.) straight onto the dev database
during what was supposed to be a read-only test run.

## Symptoms
- `docker run --rm -v "$(pwd)/backend:/app" -w /app chemglee-concept-site-backend:latest python manage.py test ...` produced tracebacks about a "readonly database" (running as the container's non-root `django` user against a host-owned mount) instead of any test output.
- Re-running with `--user "$(id -u):$(id -g)"` "succeeded" (printed `Applying migrations: ... OK` lines) but then failed with `table "orders_paynowconfig" already exists` — evidence the *real* migrate was running, not a test-database migrate.
- `backend/data/db.sqlite3`'s mtime had jumped to the moment of the `docker run`, confirming the real dev DB was touched, not an in-memory/test DB.

## Root Cause
`backend/entrypoint.sh` is a production entrypoint (`set -e; python manage.py migrate --noinput; ...; exec gunicorn ...`) and never references `"$@"`. Docker's `ENTRYPOINT` form means anything passed as the image's `CMD` (e.g. `python manage.py test ...`) is silently discarded — the script runs regardless. There is no `ENTRYPOINT ["/app/entrypoint.sh", "$@"]`-style pass-through, and nothing warns that the "command" argument to `docker run` is a no-op for this image.

## Solution
Worked around it without touching the image: pass an explicit
`--entrypoint python` (or `--entrypoint ""`) to `docker run` so the
container's default entrypoint is bypassed entirely, e.g.:
```bash
docker run --rm --user "$(id -u):$(id -g)" --entrypoint python \
  -v "$(pwd)/backend:/app" -w /app -e DJANGO_SETTINGS_MODULE=config.settings.test \
  -e HOME=/tmp chemglee-concept-site-backend:latest manage.py test apps.catalog
```
No lasting damage: `backend/data/db.sqlite3` is git-ignored, local-only, and
`manage.py showmigrations` confirmed the partially-applied migration had
rolled back (SQLite migrations are transactional), so no schema drift
persisted.

## Prevention / Rule
**Guardrail:** Before running any one-off command (tests, shell, a management
command) inside the `chemglee-concept-site-backend` image via `docker run`,
always pass `--entrypoint python` (or `--entrypoint ""`) — never rely on the
trailing `docker run <image> <cmd>` args, since `entrypoint.sh` ignores them
and runs the real production migrate instead.

This closes the gap because the failure mode is invisible until the mtime/
migration-state check: the container still "does something" and exits 0 or
with an error that looks test-related (readonly DB, table exists), not an
obvious "your command was ignored" message.

## Prevention
- [ ] Consider adding `exec "$@"` handling to `entrypoint.sh` (e.g. `if [ "$1" = "manage.py" ] ...` or a documented convention of using `--entrypoint` for ad-hoc runs) so a stray `docker run <image> <anything>` can't silently migrate the mounted DB
- [x] Documented the `--entrypoint python` workaround here for future sessions

## Related Issues
- None on file yet for this image; this is the first time an ad-hoc `docker run` against it was attempted for testing rather than via `docker compose`.

## References
- `backend/entrypoint.sh`
- `backend/Dockerfile` (`ENTRYPOINT ["/app/entrypoint.sh"]`)
- `backend/config/settings/base.py` (`DATABASES` default: `sqlite:///{DATA_DIR}/db.sqlite3`)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** ~10 minutes, same session (workaround only, no image change)

# Runner: container stack, runnable paths, and where the code lives

**Date:** 2026-09-27
**Project:** ArchCode
**Type:** Architecture Decision / Bring-Up
**Status:** Completed

## Summary
Assembled the runner into something that can actually be started, and settled where it lives in
version control. Added a pinned `Dockerfile`, a three-service Compose stack with a one-shot
migration gate, a `reset-db` command for an operation that had twice hung, and a README that
states plainly what does not exist yet. `runner/` is now its own git repository. No execution
exists and none was simulated.

## Context / Trigger
The previous session ended with the API verified against a live server, but the stack was not
assembled: there was no image, no `api`/`admin` services, no README, and no repository. Two
open items were named — "Compose services + README so the stack is runnable" and "decide
repository placement for `runner/`, since all of this work is currently uncommitted and only
recoverable from the filesystem".

## Scope
Included: `Dockerfile`, `.dockerignore`, Compose services for `api` and `admin` plus a `migrate`
gate, `scripts/reset_db.py`, README, `[build-system]` packaging metadata, and `git init` with a
first commit.

Excluded, deliberately:
- **The executor, warm pool, JSONL boundary and verifier.** Still not built. `execution_enabled`
  remains `false` and no run is graded. The README opens with that statement rather than burying
  it, because the most likely way to misuse this repo is to read "runner" and assume it runs code.
- **A git remote.** No hosting destination was chosen, so none is configured. See Decisions.
- **CI.** Referenced in the README as the future home of the smoke test; not created, because
  there is no remote to run it from.
- **Django static files.** `collectstatic` is not run; the admin works because Django serves
  static files from apps in DEBUG. A real deployment needs `STATIC_ROOT` served by something.

## Method
Two documented paths, both verified rather than assumed:

1. **Development** — database in a container, both frameworks on the host in `.venv` with reload.
   No image rebuild between edits, and `manage.py`/`pytest` work without a container wrapper.
2. **Full stack** — `docker compose --profile app up --build`, both services on one image.

The stack was brought up **from an empty volume** rather than against existing state, so the
migration gate was actually exercised instead of skipped by pre-existing rows. The smoke test was
then pointed at each path in turn. Because the smoke script asserts against the database directly
from the host while the containerised API writes to the same instance over the compose network,
a pass proves the two paths share one database — not two, each with their own migrations.

## Decisions & Findings

**1. `runner/` becomes its own repository, with no remote.** The only existing repository is
`pixel-perfect-replication`, whose `origin` is a GitHub repo that **pushes synchronise to
Lovable**. Putting Django and FastAPI in that repo would push a Python backend through a
Lovable sync, and would give the backend Node tooling it has no use for. The two codebases share
no imports — their entire contract is the OpenAPI document — which is the textbook condition for
separate repositories. A monorepo at the `Club Zero/` root was considered and rejected: it would
have to nest the existing frontend repository, and would pull in `review-shots/`, `planning/` and
`apple-design/`. The repository has a first commit and **no remote**, so hosting stays the user's
call without anything needing to be undone.

**2. Python 3.14 pinned in the image, not ranged.** `pyproject` already required `>=3.14`, and
the CPython 3.14 wheels for `pydantic-core` and `psycopg` are the reason this stack is viable at
all. A floating base tag would silently reintroduce the packaging problem the latency report
documents. Same reasoning applies to `pyproject`'s own floor.

**3. `[build-system]` added, because the project was not installable.** `pip install .` and
`pip install -e .` both failed: there was no build backend, and no package discovery. That is why
the venv's dependencies had been installed by hand — so the local environment and the container
image were maintained separately, with nothing keeping them in step. `setuptools.packages.find` is
scoped with an explicit include list that deliberately excludes `tests`, `scripts` and `bench`.

**4. One image, two commands, and a migration gate that blocks startup.** `migrate` is a one-shot
service both app services wait on via `service_completed_successfully`. Without it the two
frameworks can race into a half-migrated schema — and since Django owns the schema, that race is
between the framework that applies it and the framework that reads it. A failing migration now
stops the stack instead of letting both services start against an unverified schema.

**5. Healthchecks use `urllib`, not `curl`.** The runtime image has no `curl`, and adding a
package to a production image purely to serve a health probe is a poor trade. Each check also
proves something specific: `/healthz` for the API, `/admin/login/` for Django, so a container
that cannot serve its actual surface is not reported healthy.

**6. The image runs unprivileged, and needs no build toolchain.** Django's `runserver` refuses to
run as root, which is a convenient forcing function — and a content admin reachable from a
browser should not be one `docker exec` away from a root shell. No compiler is installed because
every native dependency resolves to a prebuilt wheel.

**7. `reset_db.py` exists because the operation hung twice.** `DROP DATABASE` issued from a
connection *into* the database being dropped does not error — it blocks. The script connects to
`postgres` to issue the drop, uses `WITH (FORCE)` to evict connections left open by
`CONN_MAX_AGE=60`, and refuses to run against a database name outside a small allow-list.
Measured at 2 seconds, versus two multi-minute hangs.

**8. Scripts are path-independent.** `python scripts/reset_db.py` puts `scripts/` on `sys.path`,
not the project root, so `archcode` would not import. Both scripts now insert the project root
explicitly and the README no longer requires `PYTHONPATH=.` — a documented incantation is a
footgun that a clean checkout will not have.

## Changes Made
New repository at `runner/` (commit `bdcc5b7`, 38 files, 3427 lines, no remote):

- `Dockerfile` — `python:3.14-slim`, unprivileged, no build toolchain, deps in their own layer
- `.dockerignore` — keeps `.env` and secrets out of the image
- `docker-compose.yml` — `db`, `migrate` (one-shot gate), `api` (`:8000`), `admin` (`:8001`)
- `scripts/reset_db.py` — drop/recreate/migrate, with the hang and the allow-list handled
- `README.md` — architecture, both run paths, verification commands, and the traps
- `pyproject.toml` — `[build-system]` + scoped package discovery
- `scripts/smoke.py` — made path-independent
- `git init -b main`; no remote configured

One bug-log entry filed alongside this report.

## Verification
Full stack brought up from an **empty volume**, so the migration gate was genuinely exercised:

```
Container runner-db-1 Healthy
Container runner-migrate-1 Exited
Container runner-admin-1 Started
Container runner-api-1 Started
```

Both services healthy; `GET :8000/healthz` → `{"status":"ok",...,"execution_enabled":false,
"attempt_budget_ms":2500}`; `GET :8001/admin/login/` → 200. Admin login as a superuser succeeded
and the `content/problem`, `content/scenario` and `attempts/run` changelists all rendered. The test
superuser was deleted afterwards.

Smoke test passes against **both** paths:

```
POST /runs             -> 202 queued, verdict=null, seed=42
GET /runs/{id}         -> 200 over_budget=null (not yet measurable)
submission persisted   -> sha256=d320a9bfd561… content matches
GET events?after_seq=-1-> 1 event(s), replay from the start
POST read-only file    -> 422 not editable: sandbox.yml
websocket              -> hello + replayed queued event
websocket after_seq=0  -> no replay, as expected
```

```
ruff check .                            -> All checks passed!
ruff format --check .                   -> 26 files already formatted
python manage.py check                  -> no issues
python manage.py makemigrations --check -> No changes detected
python -m pytest -q                     -> 19 passed
docker compose config --quiet           -> valid
python scripts/reset_db.py --yes        -> exit 0 in 2s
```

Repository left clean: `git status` empty, `.env`/`.venv`/caches/bench results all ignored,
0 remotes.

## Follow-ups / Deferred
- **A remote and a host for `runner/`.** One local commit, no remote — the decision is open.
- **CI.** `docker compose config --quiet` and `scripts/smoke.py` are the obvious first two jobs,
  and there is nowhere to run them yet.
- **`collectstatic`.** The admin relies on `DEBUG` to serve its own static files; a real deployment
  needs `STATIC_ROOT` behind something.
- **`ARCHCODE_ALLOWED_HOSTS`** defaults to `localhost`/`127.0.0.1`, which is why both published
  ports work. Anything beyond local needs this set deliberately.
- **CORS origins** are still the hardcoded dev ports in `api/app.py`; they should become
  configuration before the API is reachable from anywhere else.
- **The executor, warm pool, JSONL boundary and verifier** — the actual product, still absent.
- **Deliberately-broken benchmark case**, so "2.5 s" is not a best case presented as typical.
- **PRD §§7.3 and 10** still need the measured numbers folded in.

## References
- `Backend_and_API/ARCHCODE-2026-09-27-app-import-order-broke-uvicorn-startup.md` — the reason
  `scripts/smoke.py` exists at all
- `Database_and_State/ARCHCODE-2026-09-27-stale-dev-database-after-in-place-migration-edit.md` —
  the reason `scripts/reset_db.py` exists
- `DevOps_and_Infrastructure/ARCHCODE-2026-09-27-compose-anchor-nested-environment-one-level-too-deep.md`
- `reports/ARCHCODE-2026-09-27-runner-architecture-decision.md` — the two-process split this
  stack implements
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — why 3.14 is pinned and why the warm pool
  is load-bearing
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md` — the eight defects behind this state
- `runner/README.md`, `runner/docker-compose.yml`, `runner/Dockerfile`

---

**Completed By:** Claude (opencode)
**Duration:** ~1.5 hours

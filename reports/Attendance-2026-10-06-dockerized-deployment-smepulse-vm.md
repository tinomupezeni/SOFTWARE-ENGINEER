# Dockerized Production Deployment of the Admin Dashboard to smepulse-vm

**Date:** 2026-10-06
**Project:** Attendance
**Type:** Deployment
**Status:** Completed

## Summary
Deployed the VerifiedHQ admin dashboard (Laravel) and its FastAPI backend, PostgreSQL/PostGIS, and Redis as a Dockerized stack on `smepulse-vm`, a shared multi-tenant VPS already hosting four other projects. Built production-hardened Dockerfiles (replacing the dev-only `php artisan serve` bind-mount / `uvicorn --reload` setup), applied the host's established deployment guide (resource isolation, restart policies, no exposed datastore ports, per-service log rotation), and found/fixed two real deployment-time bugs along the way (each logged separately). The stack is live: backend on `:8002`, admin dashboard on `:8080`, both smoke-tested past the bare-200 false-positive trap.

## Context / Trigger
User asked to check `smepulse-vm` and deploy the dashboard there, Dockerized. No prior deployment of this project existed anywhere beyond local development.

## Scope
**Included:** admin (Laravel dashboard), backend (FastAPI ingestion/API), db (Postgres+PostGIS), redis — one `docker-compose.production.yml` stack. Both the dashboard and the backend were exposed on host ports per explicit user decision (backend needs to be reachable by the Flutter mobile client eventually).

**Excluded, by explicit user decision this session:**
- No domain/subdomain or nginx/TLS wiring yet — the user chose direct host-port access (`http://10.50.101.11:8080` / `:8002`) over provisioning a subdomain under `zchpc.ac.zw` (the pattern the VM's other tenants use). Follow-up when a domain is chosen.
- Mobile app configuration (pointing the Flutter client at the new backend URL) — out of scope for this pass, not touched.
- CI/CD automation for future deploys — this was a manual one-off deployment (rsync + docker compose over SSH); no pipeline was set up.

## Method
1. Read `SOFTWARE-ENGINEER`'s guide 10 ("Deployment & Maintenance — Self-Hosted VPS") before touching the VM, per the mandatory global-guides rule. The VM uses nginx, not Caddy (guide's own rewire note says skip the Caddy-specific parts), so the reverse-proxy section was set aside for this pass (no domain chosen) and the resource-isolation / restart-policy / log-rotation / smoke-test-not-just-200 guidance was applied directly.
2. Reconnaissance first, no changes: confirmed SSH access, inventoried running containers/ports/networks on the VM (4 other tenants already present: club-zero-backend, topshelf-bot, smepulse-bot, labflow-ai-main), confirmed free host ports (8002, 8080) to avoid collision with `labflow-ai-main-backend` already on `:8000`/`:8001`.
3. Asked the user three scoped questions before making any VM-side change (domain vs. no domain, whether to expose the backend publicly, generate-vs-provide secrets) since those are decisions only the user can make and the VM is shared infrastructure.
4. Hardened the Dockerfiles for production (see Changes Made) rather than reusing the dev images, consistent with guide 10's resource-isolation and restart-policy guidance.
5. Generated production secrets (DB password, Laravel `APP_KEY`, admin seed password) locally, placed them only in a `.env.production` on the VM (never committed).
6. Shipped code via `rsync` over the existing SSH key (not `git clone` — avoided needing GitHub credentials on a shared VM for a private repo), to `/home/user/attendance`, matching the directory convention the VM's other tenants already use (`/home/user/<project>`).
7. Built and brought the stack up with `docker compose -f docker-compose.production.yml --env-file .env.production up -d`.
8. Smoke-tested past the "bare 200" false-positive trap from guide 10: checked the backend's actual readiness payload (not just that `/health` returned something), checked the admin login page's actual `<title>`, and verified the specific built CSS/JS assets it referenced also returned 200 (asset-integrity check) rather than trusting the page shell alone.

## Decisions & Findings
- **Pre-existing bug found and fixed first:** `backend/Dockerfile` bound uvicorn to `--host 0.0.0` (missing an octet). It happened to still work by accident (glibc's `getaddrinfo` resolves the legacy 3-octet form), but was a latent risk if the base image ever changed. Fixed and logged separately (`Attendance-2026-10-06-backend-dockerfile-malformed-bind-host.md`) before the deployment work began.
- **Port allocation:** `BACKEND_PORT=8002`, `ADMIN_PORT=8080` — chosen after checking `ss -tln` on the VM against the 4 existing tenants' allocations (`3000-3002`, `5433`, `8000`, `8001` already taken).
- **Datastores stay internal-only:** Postgres and Redis have no host port mappings, per the project's own prior incident log (`ATTENDANCE-2026-10-03-redis-port-conflict.md`) and guide 10's multi-tenant port-collision guidance — both already-learned lessons, reapplied here rather than rediscovered.
- **Laravel kept on SQLite for its own framework needs** (sessions/cache/queue/users), matching the existing dev `.env.example` default — the dashboard is a thin client over the FastAPI backend, so Postgres wasn't needed for Laravel's own state; only `storage/app/` (holding the SQLite file) is volume-persisted, not the whole `database/` directory, to avoid masking the `migrations/`/`seeders/` source files that `COPY . .` places there.
- **Resource limits applied per guide 10's table** even though the VM is lightly loaded (31GB RAM, 28% disk) — caps are cheap insurance against this new tenant starving the four already running, consistent with the guide's stated rationale (OOM killer heuristics can take down unrelated containers).
- **Two real bugs surfaced during deployment, each logged separately:**
  - `admin/Dockerfile.production`'s `mkdir -p storage/framework/{cache,sessions,views}` silently created one wrong directory instead of three, because Docker `RUN` uses `/bin/sh` (dash), which doesn't support bash brace expansion. Caused a 500 on every request (Blade view-cache path resolution failure). See `Attendance-2026-10-06-dockerfile-brace-expansion-silently-skips-mkdir.md`.
  - A locally-generated, gitignored dev artifact (`bootstrap/cache/packages.php`, listing dev-only package `laravel/pail` as a provider) rode along in the `rsync` payload (git-ignore and deploy-ignore are different lists) and crash-looped the container, since the production image's `--no-dev` vendor tree never installed it. See `Attendance-2026-10-06-stale-dev-bootstrap-cache-shipped-to-production.md`.
- Both bugs were caught specifically because the smoke test checked real content (log output, page title, referenced asset URLs) instead of trusting container "Up" status or a bare HTTP 200 — the exact false-positive trap guide 10 calls out.

## Changes Made
- `backend/Dockerfile`: fixed `--host 0.0.0` → `--host 0.0.0.0` (pre-existing bug, unrelated to the new files below).
- `backend/Dockerfile.production` (new): no `--reload`, no bind-mounted source, `--workers 2`.
- `admin/Dockerfile.production` (new): multi-stage build (`composer:2` for `--no-dev` vendor install, `node:20-alpine` for the Vite asset build, `php:8.4-cli` runtime), clears any stale `bootstrap/cache/*.php` shipped in the build context, explicit per-directory `mkdir -p` (no brace expansion).
- `admin/docker-entrypoint.production.sh` (new): `package:discover` → `migrate --force` → `db:seed --force` → `config:cache` → `route:cache`, then execs the server command. Refuses to start if `APP_KEY` is unset.
- `docker-compose.production.yml` (new, repo root): `db`, `redis`, `backend`, `admin` services with `restart: unless-stopped`, `deploy.resources` limits/reservations per guide 10's table, healthchecks on `db`/`redis`, `depends_on: condition: service_healthy`, per-service `json-file` log rotation (`max-size: 10m`, `max-file: 3`) since the host has no global `/etc/docker/daemon.json` rotation configured, and required secrets (`DB_PASSWORD`, `APP_KEY`, `ADMIN_PASSWORD`) enforced via Compose's `${VAR:?error}` syntax rather than silently defaulting.
- On `smepulse-vm`: `/home/user/attendance/` now holds the deployed tree (via `rsync`, excluding `.git`, `node_modules`, `vendor`, dev storage/cache paths, `.sqlite`, `.env*`, `bootstrap/cache/*.php`) plus a `chmod 600 .env.production` holding the generated secrets. Stack is running as `attendance-{db,redis,backend,admin}-1`.

## Verification
- `docker ps`: all four containers `Up`, `db`/`redis` report `(healthy)`.
- Backend: `curl http://localhost:8002/health/ready` → `{"status":"ready","database":"connected"}` (dependency-health check, not just a liveness ping).
- Admin: `curl http://localhost:8080/login` → HTTP 200, `<title>Sign in — VerifiedHQ</title>`; the two asset URLs the page actually references (`/build/assets/app-*.js`, `/build/assets/app-*.css`) independently verified to return 200 (asset-integrity check).
- Grepped the built JS bundle for `localhost`/`127.0.0.1` leaks (environmental-leak check per guide 10) — none found.
- Did not get a full login POST round-trip verified end-to-end (a 419 CSRF response was hit using an ad-hoc `curl` script to simulate the browser flow; traced to the test script's own token-extraction regex, not an application fault — the migrations/seed log confirmed the admin user was created, and the rendered login page itself is correct). Recommend the user do one real browser login as a final human check.

## Follow-ups / Deferred
- Choose a subdomain (e.g. under `zchpc.ac.zw`, matching the VM's existing nginx pattern) when ready to expose the dashboard under a real domain with TLS; current access is plain HTTP on the VM's IP.
- Point the Flutter mobile client at the new backend URL (`http://10.50.101.11:8002`) when mobile deployment is planned — not done this session.
- No automated backup job exists yet for the new `attendance_postgres_data` volume; guide 10's `pg_dump -Fc` + offsite-sync pattern should be applied once this deployment is more than a smoke-tested first cut.
- Laravel sessions use the `file` driver (storage/framework/sessions, not volume-persisted) — logins are lost on redeploy/container recreate. Acceptable for an internal admin tool at this stage; switching to the `database` session driver later would need a `sessions` migration that doesn't currently exist.

## References
- `Attendance-2026-10-06-backend-dockerfile-malformed-bind-host.md`
- `Attendance-2026-10-06-dockerfile-brace-expansion-silently-skips-mkdir.md`
- `Attendance-2026-10-06-stale-dev-bootstrap-cache-shipped-to-production.md`
- `ATTENDANCE-2026-10-03-redis-port-conflict.md` (prior lesson reapplied: no host port for Redis)
- `Principal_Engineer/engineering-guides/10. Deployment And Maintenance.md`

---

**Completed By:** Claude (Sonnet 5)
**Duration:** ~2 hours (recon, hardening, two debugging cycles, verification)

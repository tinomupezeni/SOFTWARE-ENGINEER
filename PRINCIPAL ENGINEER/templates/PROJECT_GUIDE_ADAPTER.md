# PROJECT GUIDE ADAPTER — template

> Use this file to record how the engineering-guides library was "rewired" into a
> specific project. One adapter per project. It is the bridge between the generic
> guides (in `dev-logs/PRINCIPAL ENGINEER/engineering-guides/`) and the project's
> own `CLAUDE.md` / `ARCHITECTURE.md` / `docs/`.

## Project

- **Name:** <project name>
- **Path:** <path under /home/tino/Projects>
- **Stack:** <e.g. pnpm monorepo, FastAPI BFF, React/Vite, Postgres x5, Redis, nginx/Traefik>
- **Deploys to:** <self-hosted VPS / Coolify / PaaS / none>

## Guides applied

For each guide, state: which sections were ported, where they landed in the project,
and any stack adaptation. Keep this honest — if a guide was *not* applied, say why.

### 6. Database Engineering
- **Ported sections:** UUIDv7 PK standard, short-transaction rule, migration strategy.
- **Landed in:** `apps/store-api/app/core/db.py`, `CLAUDE.md` data-access rules.
- **Adaptation:** guide assumes SQLAlchemy/Alembic; project uses <actual ORM/migration tool>.
- **Compliance:** [ ] UUIDv7 on new tables  [ ] migrations include data port  [ ] stmt timeouts set

### 10. Deployment And Maintenance
- **Ported sections:** Docker `deploy.resources` caps, OOM isolation.
- **Landed in:** `docker-compose.prod.yml`, `infrastructure/`.
- **Adaptation:** guide recommends Caddy; project uses nginx/Traefik — proxy section skipped.
- **Compliance:** [ ] memory limits on every service  [ ] swap disabled  [ ] staging parity verified

### 7. Software Security Engineering
- **Ported sections:** multi-tenant row isolation, payment authz.
- **Landed in:** `CLAUDE.md` architecture rules, `apps/store-api/app/modules/auth`.
- **Adaptation:** <none / notes>
- **Compliance:** [ ] tenant boundary enforced at query layer  [ ] payment webhooks idempotent

## Open gaps (guides not yet applied)

- [ ] 4. SRE — no SLOs defined yet
- [ ] 5a. Observability — no trace correlation across services
- [ ] 8. E2E — smoke tests exist but not gated in CI

## Review cadence

Re-open this adapter each review cycle (see `../growth_tracker.md`). If a guide was
updated in the library, re-port the changed sections here and bump the version below.

- **Adapter version:** 0.1
- **Last synced:** <date>

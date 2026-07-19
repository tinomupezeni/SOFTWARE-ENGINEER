# PROJECT GUIDE ADAPTER — TESE-MARKET (BFF)

> Bridge between `dev-logs/PRINCIPAL ENGINEER/engineering-guides/` and the TESE
> Marketplace monorepo. Records which guides were ported, where they landed, and
> the stack adaptations required.

## Project

- **Name:** Tese Marketplace (BFF Architecture)
- **Path:** `/home/tino/Projects/TESE-MARKET---BFF-ARCHITECTURE`
- **Stack:** pnpm monorepo — FastAPI BFF (`apps/store-api`), React/Vite
  `customer-store` + `admin-dashboard`, shared TS/Py packages; 5× Postgres
  (store/sourcing/brain/auth/chat) + Redis; nginx (dev/VPS) + Traefik (prod).
- **Deploys to:** Self-hosted VPS via docker-compose + deploy scripts.
- **Already has:** `ARCHITECTURE.md`, `CLAUDE.md`, `DECISIONS_LOG.md`, `DOCKER_GUIDE.md`,
  `smoketest/` (load + smoke), `deployment-config.json`.

## Guides applied

### 6. Database Engineering  → fit: high
- **Ported sections:** UUIDv7 PK standard; short-transaction rule (no external
  calls inside tx); migration strategy (data port before traffic).
- **Landed in:** `CLAUDE.md` data-access rules (Service-Repository pattern
  already enforced); propose UUIDv7 for new tables.
- **Adaptation:** Guide assumes SQLAlchemy/Alembic; confirm `packages/common-py`
  uses Alembic — align migration section.
- **Compliance:** [x] data-mapper/repo enforced  [ ] UUIDv7 on new tables
  [ ] migration data-port step  [ ] statement timeouts set on every DB

### 10. Deployment And Maintenance  → fit: high
- **Ported sections:** Docker `deploy.resources` caps, OOM isolation, swap disable.
- **Landed in:** `docker-compose.prod.yml` / `docker-compose.vps.yml`.
- **Adaptation:** Guide recommends Caddy; project uses **nginx/Traefik** — proxy
  section skipped (explicit deviation already noted in CLAUDE.md: "do not re-platform the proxy").
- **Compliance:** [ ] memory limits on every service  [ ] swap disabled
  [ ] staging parity verified via deploy_staging.sh

### 7. Software Security Engineering  → fit: high
- **Ported sections:** multi-tenant row isolation; payment webhook idempotency;
  authz at the edge.
- **Landed in:** `CLAUDE.md` architecture rules; `apps/store-api/app/modules/auth`, `orders`.
- **Adaptation:** None structural; focus on the 5-DB multi-tenant boundary.
- **Compliance:** [ ] tenant boundary enforced at query layer (not just app filter)
  [ ] payment webhooks idempotent (matches growth_tracker goal)
  [ ] secrets validated at startup

### 4. SRE + 5a. Observability  → fit: high (NOT YET APPLIED)
- **Ported sections:** SLOs + error budgets; structured logs + error alerting;
  trace correlation across the 5 services.
- **Landed in:** (planned) `docs/runbooks/`, `CLAUDE.md` observability section.
- **Adaptation:** None.
- **Compliance:** [ ] SLOs defined  [ ] postmortem template  [ ] trace IDs
  propagated store-api → DB

### 8. E2E Testing  → fit: high (PARTIAL)
- **Ported sections:** CI gating of smoke/load tests.
- **Landed in:** `smoketest/` already exists; formalize under guide's gate model.
- **Adaptation:** Guide assumes Playwright/Cypress; confirm what `smoketest/load` uses.
- **Compliance:** [x] smoke tests exist  [ ] gated in CI  [ ] customer+admin journeys covered

### 1. SDLC  → fit: high (reconcile)
- **Ported sections:** ADR/gate model vs existing `DECISIONS_LOG.md`.
- **Landed in:** promote `DECISIONS_LOG.md` entries to ADR-format or cross-link.
- **Adaptation:** None.
- **Compliance:** [x] decisions logged  [ ] ADR numbering/status  [ ] gate checklist

## Open gaps

- [ ] 4. SRE — no SLOs / postmortem process yet
- [ ] 5a. Observability — no cross-service trace correlation
- [ ] 8. E2E — tests not gated in CI
- [ ] 6. Database — UUIDv7 + stmt timeouts not yet enforced

## Review cadence

Re-open each cycle with `../growth_tracker.md`. If a guide is updated in the
library, re-port changed sections and bump version.

- **Adapter version:** 0.1
- **Last synced:** 2026-07-19

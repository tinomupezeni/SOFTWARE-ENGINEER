# Engineering Guides — Manifest

> Purpose: make the `engineering-guides/` library **rewirable**. Each guide below is a
> standalone reference. This manifest declares its scope, the stack it assumes, the
> trigger conditions for applying it to a project, and which of Tino's projects it
> already maps to. New guides MUST follow `../templates/GUIDE_TEMPLATE.md` so they
> slot in here without refactoring.

## How to rewire a guide into a project

1. Read the guide's `## Metadata` block (scope, stack, triggers).
2. If a project matches the triggers, copy the relevant section into the project's
   `CLAUDE.md` / `ARCHITECTURE.md` / `docs/`, adapting stack specifics (see the
   `applies_to` notes). Do **not** copy the whole guide — copy the parts that bite.
3. Record the mapping in the `applies_to` table so we know which project already
   absorbed which guide (prevents drift / duplicate effort).

---

## Guides

### 1. SDLC
- **File:** `1. SDLC.md`
- **Scope:** Full systems/software development lifecycle (ISO 12207 + NIST SSDF + OWASP SAMM), gates, ADRs, agent-driven workflow.
- **Stack:** Stack-agnostic. Assumes small (1–4) team, CLI coding agents, self-hosted VPS.
- **Triggers:** Greenfield project, or a project with no defined process / missing ADRs / no quality gates.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | Already has DECISIONS_LOG + CLAUDE.md; align gate model with it. |
  | HBEC | High | Has CODEBASE_AUDIT; needs formal SDLC gates. |
  | shipwright | Medium | Rust CLI tool; SDLC applies to release process. |
  | Most others | Medium | Apply lightweight version (ADRs + test gate). |

### 3. Mobile App Agent-First Development
- **File:** `3. Mobile App Agent-First Development Guide.md`
- **Scope:** React Native / Flutter mobile development driven by coding agents.
- **Stack:** React Native, Flutter.
- **Triggers:** Project ships a mobile app.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | Retro RPG World Simulator | High | Mobile game / app target. |
  | MAISHA | Maybe | Check if app/ is React Native. |
  | (none others currently mobile) | — | Add when a mobile project appears. |

### 4. Site Reliability Engineering
- **File:** `4. Site Reliability Engineering.md`
- **Scope:** SLOs, error budgets, on-call, toil caps, postmortems for self-hosted infra.
- **Stack:** Docker, Coolify, VPS, Linux.
- **Triggers:** Project runs in production on self-managed infra.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | Multi-DB + Redis + nginx/Traefik; needs SLOs. |
  | HBEC | High | Production resiliency already a theme. |
  | Most deployable projects | Medium | Apply SLO + postmortem minimum. |

### 5a. Observability and Monitoring
- **File:** `5. Observability and Monitoring.md`
- **Scope:** Logs, metrics, traces, dashboards for small teams.
- **Stack:** Stack-agnostic; self-hosted friendly.
- **Triggers:** Project needs production visibility / currently flying blind.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | Many services; needs trace correlation. |
  | HBEC | High | Incident history shows monitoring gaps. |
  | Most deployable projects | Medium | At minimum: structured logs + error alerting. |

### 5b. Secure Application Configuration
- **File:** `5. Secure Application Configuration.md`
- **Scope:** Secrets, env config, config hardening.
- **Stack:** Stack-agnostic.
- **Triggers:** Project has `.env`, secrets, or external service credentials.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | ALL deployable projects | High | Universal — secrets everywhere. |
  | TESE-MARKET (BFF) | High | Multi-service config surface. |

### 6. Database Engineering
- **File:** `6. Database Engineering.md`
- **Scope:** PostgreSQL internals, schema design, migrations, UUIDv7 PKs, connection mgmt.
- **Stack:** PostgreSQL (primary), SQLAlchemy/Alembic implied.
- **Triggers:** Project uses a relational DB (esp. Postgres).
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | 5 Postgres DBs + Redis; UUIDv7 standard candidate. |
  | HBEC | High | Postgres-backed. |
  | TESC | High | Postgres + crypto search. |
  | Most backend projects | High | Postgres is the default. |
  | TESC (ScalarEye) | High | Django ORM + Postgres 15; Celery/Fernet crypto paths. |
  | SMEPulse | High | Prisma + Postgres; ephemeral-Postgres-in-CI rule ported, `db push` not yet `migrate` — see `PROJECT_ADAPTER_SMEPULSE.md`. |

### 7. Software Security Engineering
- **File:** `7. Software Security Engineering.md`
- **Scope:** Threat modeling, authn/z, OWASP, secure design.
- **Stack:** Stack-agnostic.
- **Triggers:** Project handles user data, auth, or payments.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | Payments + wallets + multi-tenant. |
  | HBEC | High | Sensitive institutional data. |
  | TESC | High | Crypto (Fernet), decryption endpoints, instauth. |
  | SMEPulse | Medium | Hand-rolled signed-cookie session (no auth lib, due to Next 16 compatibility risk) — see `PROJECT_ADAPTER_SMEPULSE.md`. |

### 8. E2E Testing
- **File:** `8. E2E Testing.md`
- **Scope:** End-to-end test strategy, tooling, CI gates.
- **Stack:** Stack-agnostic; Playwright/Cypress implied.
- **Triggers:** Project has a UI or API surface that users depend on.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | customer-store + admin-dashboard UIs. |
  | HBEC | Medium | ADMIN app. |
  | Most web projects | Medium | Smoke test minimum. |
  | TESC (ScalarEye) | High | Strong baseline: pytest tiers + k6 load + fuzz. |
  | SMEPulse | High | Vitest + Supertest for `apps/webhook` (unit + integration, CI-gated); `apps/admin` UI E2E not started. |

### 9. Performance Engineering
- **File:** `9. Perfomance Engineering.md`
- **Scope:** Queueing-theory capacity planning, backend/DB performance, observability, and AI-agent verification workflows for performance-sensitive systems.
- **Stack:** Stack-agnostic; FastAPI examples given.
- **Triggers:** Project has a latency-sensitive request path (e.g. a webhook with a delivery-provider timeout) or needs load/capacity planning.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | SMEPulse | Medium | Webhook must ack Meta quickly and reliably; motivated idempotency + payload-shape guards. Load testing deferred — see `PROJECT_ADAPTER_SMEPULSE.md`. |

### 10. Deployment And Maintenance
- **File:** `10. Deployment And Maintenance.md`
- **Scope:** Self-hosted VPS multi-tenancy, Docker resource isolation, Coolify, Caddy. Also covers immutable artifact tagging / build-once-promote-everywhere (added 2026-08-11).
- **Stack:** Docker, Docker Compose, Coolify, Caddy, Linux VPS.
- **Triggers:** Project deploys to a self-managed VPS.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | nginx/Traefik instead of Caddy — adapt. |
  | HBEC | High | Two Compose environments, one VPS, no registry. Full adapter: `PROJECT_ADAPTER_HBEC.md` — ported the immutable-sha-tagging / build-once section this same day, root-caused from a real staging incident. |
  | shipwright | Medium | Dockerfile + compose agent. |
  | Most deployable projects | High | Resource caps are universal guidance. |
  | TESC (ScalarEye) | High | GH Actions self-hosted runner + nginx (not Coolify/Caddy). |

---

## Pilot: TESE-MARKET (BFF)

This project is the reference pilot for rewiring. It is a pnpm monorepo with a FastAPI BFF
(`apps/store-api`), React/Vite storefront + admin, shared TS/Py packages, 5 Postgres DBs +
Redis, nginx (dev/VPS) + Traefik (prod), already carrying `ARCHITECTURE.md`, `CLAUDE.md`,
`DECISIONS_LOG.md`, `DOCKER_GUIDE.md`.

Guides to absorb (in priority order):
1. **6. Database Engineering** — align on UUIDv7 PKs, short transactions, migration strategy.
2. **10. Deployment And Maintenance** — add Docker `deploy.resources` caps; note nginx/Traefik
   deviation from the guide's Caddy default.
3. **7. Software Security Engineering** — payments/wallets/multi-tenant isolation review.
4. **4. SRE + 5a. Observability** — define SLOs + trace correlation across services.
5. **8. E2E Testing** — smoke/load tests already exist under `smoketest/`; formalize.
6. **1. SDLC** — reconcile DECISIONS_LOG with the guide's ADR/gate model.

See `templates/PROJECT_GUIDE_ADAPTER.md` for the adapter format used to wire these in.

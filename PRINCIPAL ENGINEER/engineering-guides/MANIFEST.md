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
- **Scope:** Full systems/software development lifecycle (ISO 12207 + NIST SSDF + OWASP SAMM), gates, ADRs, agent-driven workflow. Also covers technical-debt audit cadence (verify-before-delete) and foundational-docs-at-project-start (added 2026-08-11).
- **Stack:** Stack-agnostic. Assumes small (1–4) team, CLI coding agents, self-hosted VPS.
- **Triggers:** Greenfield project, or a project with no defined process / missing ADRs / no quality gates.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | Already has DECISIONS_LOG + CLAUDE.md; align gate model with it. |
  | HBEC | High | Ran against the real repo 2026-08-11 — see `PROJECT_ADAPTER_HBEC.md`. Real strengths (per-service CI tests, OpenAPI specs, real SLOs, populated readiness/runbook docs); the recurring gap is scaffolding created once and never exercised (zero ADRs despite a template, zero postmortems despite 25+ real incidents, threat model unfilled). |
  | shipwright | Medium | Rust CLI tool; SDLC applies to release process. |
  | Most others | Medium | Apply lightweight version (ADRs + test gate). |

### 2. Project Documentation
- **File:** `2. Project Documentation.md`
- **Scope:** Architectural standards, documentation requirements, and SDLC blueprint aligning ISO 12207 with agile tailoring for 1-10 dev teams. Overlaps guides 1/4/6/8/10/11 heavily; its distinctive content is the companion doc's document inventory and the AGENTS.md/MCP-gateway-security material.
- **Stack:** Stack-agnostic; docs-as-deliverable.
- **Triggers:** Project needs a documentation standard, or wants an ISO-aligned but agile process.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | Medium | CLAUDE.md already encodes many of these rules. |
  | HBEC | High | Ran 2026-08-11 — see `PROJECT_ADAPTER_HBEC.md`. Missing README/ARCHITECTURE/CONTRIBUTING/RUNBOOK/CHANGELOG/SECURITY at root (fails the doc's own stated minimum) despite the substance existing under other names; AGENTS.md's telemetry mandates checked and substantially real in code (OTel tracing, JSON log formatters). |
  | Most others | Not yet reviewed | Companion to `PRINCIPAL ENGINEER/projects_documentation.md` (parent dir) — check that first before re-deriving. |

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
- **Scope:** SLOs, error budgets, on-call, toil caps, postmortems for self-hosted infra. Also covers shallow-vs-deep health check design and the "Zombie Service" failure mode (added 2026-08-11).
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
- **Scope:** Secrets, env config, config hardening. Also covers fail-fast startup validation — crash on boot rather than silently run with a placeholder/missing production secret (added 2026-08-11).
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
- **Scope:** Threat modeling, authn/z, OWASP, secure design. Also covers financial/payment webhook security — signature verification, secret-domain isolation, idempotency, at-least-once delivery (added 2026-08-11).
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
- **Scope:** Queueing-theory capacity planning, backend/DB performance, observability, and AI-agent verification workflows for performance-sensitive systems. Also covers LLM-provider rate limits as an external capacity ceiling distinct from code-level performance, and capacity-cost-tier estimation (added 2026-08-11).
- **Stack:** Stack-agnostic; FastAPI examples given.
- **Triggers:** Project has a latency-sensitive request path (e.g. a webhook with a delivery-provider timeout) or needs load/capacity planning.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | SMEPulse | Medium | Webhook must ack Meta quickly and reliably; motivated idempotency + payload-shape guards. Load testing deferred — see `PROJECT_ADAPTER_SMEPULSE.md`. |
  | TESE-MARKET (BFF) | Medium | Not yet reviewed against this project directly. |
  | HBEC | Medium | AI-generation latency (paper/marking endpoints) and pgbouncer connection pooling both match; not yet reviewed against this project directly. |

### 10. Deployment And Maintenance
- **File:** `10. Deployment And Maintenance.md`
- **Scope:** Self-hosted VPS multi-tenancy, Docker resource isolation, Coolify, Caddy. Also covers exhaustive backup scope before a destructive wipe, a gateway-unreachable triage checklist, deployment-verification patterns (Blue-Green/Smoke/Staging + the False Positive Trap), and host-level (systemd/VPS) failure modes beneath Docker (added 2026-08-11). The single-host instantiation of immutable-artifact-tagging / build-once-promotion lives here; the full stack-agnostic pattern was split out to guide 18 for reuse outside VPS/Coolify/Caddy projects.
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

### 11. SE Verification
- **File:** `11. SE Verification.md`
- **Scope:** Full-stack verification and production-readiness framework for teams whose implementation code is largely agent-generated: functional/contract/chaos testing, mutation-tested test-suite integrity, security (NIST SSDF/OWASP SAMM) and observability (OpenTelemetry/Prometheus) gates, SRE-style readiness (SLIs/SLOs, error budgets, MTTA/MTTR).
- **Stack:** Django, FastAPI, Laravel, React, Flutter, Postgres, Redis, Docker Compose, GitHub Actions, OpenTelemetry.
- **Triggers:** Project uses CLI coding agents to generate implementation code; needs CI gates beyond linting; deploys to a self-managed VPS and needs SLOs/production readiness review.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | FastAPI + Postgres/Redis matches directly. Not yet reviewed against this project directly. |
  | HBEC | High | Stack matches closely, but CLAUDE.md states most CI workflows are disabled — no automated test/lint gate today, so this guide's gates are aspirational here, not adopted. |
  | shipwright | Low | Rust CLI/release tool, not a hosted service — DB pooling, contract-testing, and PRR/SLO sections don't apply. |
  | TESC (ScalarEye) | High | Django + Postgres matches; existing pytest + k6 + fuzz baseline (guide 8) is a head start, but this guide's specific gates not yet reviewed against it. |
  | SMEPulse | Medium | Prisma/Next only partially overlaps the guide's examples; mutation testing and PRR/SLO sections not yet reviewed against this project directly. |

### 12. HCI
- **File:** `12. HCI.md`
- **Scope:** Cognitive-science-grounded UX/UI engineering — Nielsen's heuristics, Shneiderman's golden rules, ISO 9241/25010 usability standards, WCAG 2.2 accessibility, form/error-handling design, dashboard IA, usability testing/metrics.
- **Stack:** Stack-agnostic; web and mobile.
- **Triggers:** Project has a user-facing UI (web, mobile, or desktop); needs WCAG/accessibility compliance.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | Storefront + admin-dashboard UIs; not yet reviewed against this project directly. |
  | HBEC | High | Two React frontends with forms, dashboards, curriculum navigation; not yet reviewed against this project directly. |
  | shipwright | Low | Rust CLI tool; no graphical UI surface. |
  | TESC (ScalarEye) | Medium | Two React/Vite frontends (public portal + admin); not yet reviewed against this project directly. |
  | SMEPulse | Medium | Next.js admin portal + WhatsApp conversational interface; not yet reviewed against this project directly. |

### 13. Deployment (Production Readiness & Release Engineering)
- **File:** `13. Deployment.md`
- **Scope:** Enterprise-scale production readiness and release engineering — PRR checklists, staging/production parity vectors, deployment strategies (canary/blue-green/rolling/progressive delivery), zero-downtime DB migrations, rollback engineering, SLO-based observability, incident response. Written for Kubernetes/cloud-native shops with a dedicated SRE function — heavier-weight than guide 10's self-hosted-VPS equivalent, and the two are complementary rather than redundant (10 answers "how do I run this on my VPS," 13 answers "what does a rigorous cloud-scale promotion process look like").
- **Stack:** Kubernetes, PostgreSQL/MySQL, Docker, Terraform, Prometheus.
- **Triggers:** Project needs a formal Production Readiness Review before a major release; runs on Kubernetes or another orchestrated platform; needs zero-downtime relational DB migrations or a documented rollback/incident-response runbook.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | Medium | PRR/rollback/DB-migration sections plausibly fit; Kubernetes-specific subsections don't (nginx/Traefik, no orchestrator). |
  | HBEC | Medium | Immutable-tagging/rollback already ported via guide 10 (see `PROJECT_ADAPTER_HBEC.md`); this guide's PRR checklist and parity vectors overlap but aren't checked against HBEC specifically. Docker Compose on one VPS, not Kubernetes. |
  | shipwright | Low | Not a running production service — PRR/canary/incident-response don't map; release-artifact-integrity ideas may still apply. |
  | TESC (ScalarEye) | Medium | Section 5's ORM-migration guidance names Django directly, mapping to TESC's stack; PRR/rollback sections not yet reviewed against it. |
  | SMEPulse | Medium | Postgres/Prisma migrations benefit from the Expand-Contract guidance; not yet reviewed against this project directly. No Kubernetes in use. |
- **Note:** none of the tracked projects run Kubernetes, so no entry above exceeds `medium` — pull the stack-agnostic parts (PRR checklist, Expand-Contract DB pattern, rollback triggers, incident-response protocol, postmortem template) rather than the whole guide.

### 14. SDK Development
- **File:** `SDK Development.md`
- **Scope:** Building, packaging, and maintaining production-grade Python libraries, SDKs, and plugin-extensible developer platforms consumed by external/third-party code — public API design, src-layout packaging, PyPI release/supply-chain security, layered config, error taxonomies, plugin sandboxing, SemVer/deprecation compatibility.
- **Stack:** Python, Pydantic, httpx, Hatchling, PyPI, mypy, pytest.
- **Triggers:** Project builds or distributes a Python library, SDK, or plugin-extensible developer platform for external consumers; must preserve a stable public API contract across versions.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | Low | FastAPI BFF serving its own frontends, not a distributed client SDK; shared TS/Py packages are internal-only. |
  | HBEC | Low | Application suite serving its own frontends via internal HMAC calls; nothing packaged/versioned as a redistributable library. |
  | shipwright | Low | Rust CLI tool; Python packaging detail doesn't transfer, though SemVer/deprecation principles are language-agnostic. |
  | TESC (ScalarEye) | Low | Django ORM application, not a published library. |
  | SMEPulse | Low | Next.js/Prisma — not Python, not a distributed SDK. Guide does not apply. |
- **Note:** none of the tracked projects currently ship a distributable client SDK — revisit if one splits out a public library.

### 15. Code Integration
- **File:** `Code Integration.md`
- **Scope:** End-to-end code integration lifecycle — git branching strategy (trunk-based dev), PR standards, the 12-vector code review framework, CI/CD quality gates, integration testing, merge-conflict resolution, Postgres migration safety, API versioning/contract testing, config/secrets/feature-flag rollout, release/rollback procedures, and how to review AI-agent-generated contributions specifically. Also covers single-source-of-truth discipline for cross-file constants, and closing a bug by its pattern, not just its one reported instance (added 2026-08-11).
- **Stack:** git, GitHub Actions, PostgreSQL, Docker, Coolify.
- **Triggers:** Project uses a PR-based git workflow with a CI/CD pipeline gating merges; runs Postgres migrations in production; integrates AI coding agents into the review/merge workflow.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | TESE-MARKET (BFF) | High | FastAPI + Postgres + Docker matches the guide's migration-timeout and CI/CD examples directly. |
  | HBEC | High | Stack matches (Django, FastAPI, Postgres, Docker, GitHub Actions), but per CLAUDE.md most CI workflows are disabled — the guide's core thesis (automated gates blocking merge) is aspirational here, not adopted. |
  | shipwright | Medium | Branching/PR-size/release guidance is language-agnostic; worked examples (Django/FastAPI, Postgres locking) don't map directly. |
  | TESC (ScalarEye) | High | Django + Postgres 15 + GH Actions self-hosted runner already in place; overlaps with this guide's CI and migration-safety sections. |
  | SMEPulse | Medium | CI-gated tests for `apps/webhook` already established (guide 8), but no Postgres migration-locking or PR/branching review yet against this guide. |

### 16. AI Agent Orchestration and Delegation
- **File:** `16. AI Agent Orchestration and Delegation.md`
- **Scope:** How a human engineer delegates implementation work to AI coding agents and verifies the result — the Builder-to-Architect identity shift, the Reverse Engineering Path audit technique, a Definition of Done for agent-delegated tasks, the 3-Step Delegation framework (Directive / Verification Script / Standard Reference), and the Blueprint-repo pattern. Distinct from guide 1 (mentions "agent-driven workflow" in passing) and guide 11 (mentions reviewing agent output) — neither centers on the delegation loop itself.
- **Stack:** Stack-agnostic; CLI coding agents, git, bash/PowerShell/SSH, Docker.
- **Triggers:** Project uses CLI coding agents for implementation; delegated work has no Definition of Done; scripts cross shell boundaries (PowerShell → SSH → Bash → Python etc.).
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | shipwright | High | Literal origin case — the guide's case-study incident and its remediation pattern. |
  | HBEC | High | This session's own delegation (parallel subagents wiring 15+ guides, fixing a real deploy incident) is itself live evidence the framework works, not just theory. |
  | SMEPulse | High | Its adapter already practices "Behavioral Proof" (real test/curl against target env) unprompted. |
  | TESE-MARKET (BFF) | High | Raw material (CLAUDE.md, DECISIONS_LOG) exists; not yet reorganized around this framework specifically. |
  | TESC (ScalarEye) | Medium | Plausible fit; no documented evidence yet either way. |

### 17. AI/LLM System Observability and Behavioral Correctness
- **File:** `17. AI-LLM System Observability and Behavioral Correctness.md`
- **Scope:** Detecting semantic/behavioral degradation in LLM/agent-backed systems that are "up" by SRE measures (guide 4) and "passing" by functional-test measures (guide 11) while silently producing wrong, degraded, or ungrounded output — model-fallback drift, empty/ungrounded RAG retrieval, and agent behavioral-contract violations (routing, memory, multi-turn continuity) that throw no error and fail no status-code assertion.
- **Stack:** FastAPI, LangGraph, LiteLLM, Qdrant, Redis, PostgreSQL (source stack; swap for whatever a target project uses — the three failure-mode checks generalize).
- **Triggers:** Project routes through more than one LLM provider/model tier; implements RAG over a vector store; runs LLM-backed agents with routing, memory, or multi-turn state.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | HBEC | High | Source of every example: the 2026-07-21 silent model-fallback incident, SYSTEM-AUDIT.md's single-provider and empty-RAG findings, PROBLEM.md's 3 agent behavioral-contract bugs. |
  | TESE-MARKET (BFF) | None | E-commerce BFF with no LLM/AI-agent surface. Does not apply unless/until an AI feature is added. |
  | shipwright | None | Rust CLI tool. No model calls, no retrieval, no agents. |
  | TESC (ScalarEye) | None | No LLM/AI integration in its current architecture. |
  | SMEPulse | None | Static Twilio templates, not LLM-generated content. |

### 18. Build Once, Deploy Everywhere: Immutable Artifact Promotion
- **File:** `18. Build Once Deploy Everywhere.md`
- **Scope:** Tag every build artifact by the immutable identity of the commit it came from, then promote that exact artifact between environments instead of rebuilding it. Covers the single-host (no registry) and multi-host (registry push/pull) variants, a fast-rollback pattern that falls out of the same mechanism, retention, and the specific way this silently breaks when two environments' build steps drift structurally out of sync. Split out of guide 10 on 2026-08-11 so the pattern is reusable outside VPS/Coolify/Caddy projects — guide 10 keeps only the single-host instantiation and points here for the rest.
- **Stack:** Docker, Docker Compose, git, CI/CD, stack-agnostic.
- **Triggers:** Project has more than one deployment environment; a bug fixed on staging reappeared in production (or vice versa); images are tagged `:latest`/by branch name rather than build identity; rollback means rebuilding an old commit and hoping it comes out the same.
- **applies_to:**
  | Project | Fit | Notes |
  |---|---|---|
  | HBEC | High | Source of this guide — full compliance record in `PROJECT_ADAPTER_HBEC.md` under guide 10. |
  | TESE-MARKET (BFF) | High | Multiple services + a promotion path is exactly this guide's trigger. Not yet reviewed against this project directly. |
  | TESC (ScalarEye) | Medium | GH Actions self-hosted runner already exists to host this pattern; not yet reviewed against this project directly. |
  | SMEPulse | Medium | Not yet reviewed against this project directly. |
  | shipwright | Low | A release/deploy tool itself, not a running service with environments to promote between. |

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

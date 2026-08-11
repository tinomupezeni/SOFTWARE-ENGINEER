# PROJECT GUIDE ADAPTER — HBEC

## Project

- **Name:** HBEC (Heritage-Based Curriculum platform)
- **Path:** `/home/tino/Projects/HBEC`
- **Stack:** Django (Admin CMS, Student Backend), FastAPI (Agentic Harness,
  Payments), React/Vite (two frontends), PostgreSQL, Redis, Qdrant, GHCR.
- **Deploys to:** Self-hosted VPS (single host), two independent Docker
  Compose environments on it — `/opt/hbec` (production, root-owned) and
  `/home/winstontino/HBEC` (staging, user-owned). No Coolify; a bespoke
  GitHub Actions pipeline (`.github/workflows/cd.yml`) triggers builds that
  run directly on the VPS itself (SSH, not a GitHub-hosted runner — a
  free-tier Actions minutes constraint), then hands off to `docker compose`.

## Guides applied

### 1. SDLC
- **Method:** ran the guide's 12 phases against HBEC's actual repo state
  directly (file existence, CI job list, git log, branch names) rather than
  against memory or the earlier audit docs alone — see the checks below,
  each independently verifiable.
- **The single most important finding:** a repeated pattern across multiple
  phases of *scaffolding created once, then never exercised*. `docs/ADR_TEMPLATE.md`
  exists but zero actual `ADR-NNN` files exist anywhere in the repo.
  `docs/THREAT_MODEL_TEMPLATE.md` exists and is genuinely empty (44 lines,
  section headers only). `SRE/POSTMORTEM_TEMPLATE.md` exists, but zero real
  postmortems exist despite 25+ real incidents logged in `dev-logs/HBEC/` —
  the incident data got captured, just never run through the guide's actual
  Post-Incident Review process. `SRE/SLOs.md` is a real, well-specified
  document (3 Critical User Journeys, explicit SLI/SLO/error-budget-policy),
  **correcting an earlier, wrong claim in this same adapter's "Open gaps"
  section that HBEC has no SLOs defined** — it does; what it lacks is
  alerting wired to them, which is exactly why the `redis-sentinel`
  crash-loop (7,237 restarts, found this same session) never tripped an SLO
  breach despite plausibly violating the "System Availability ≥99.9%"
  target.
- **Phase-by-phase, condensed** (full phase list in the guide itself):
  - Phase 1 (Discovery): no `vision_document.md` in the guide's prescribed
    location; `PRD.md` exists at repo root (not `docs/requirements/`) and
    predates a formal Vision Document step entirely.
  - Phase 3 (Architecture): **strong** on OpenAPI — real, current specs per
    service (`openapi/admin.yml`, `harness.yml`, `payments.yml`,
    `schools.yml`, `student.yml`). **Not met** on ADRs (template-only, see
    above) despite real architecture docs existing under other names
    (`ADMIN_PIPELINE_ARCHITECTURE.md`, `CODEBASE_AUDIT.md`).
  - Phase 5 (Engineering Standards): pre-commit linting is real and active
    (ruff, ruff-format, detect-secrets — confirmed firing on every commit
    made this session). OpenTelemetry-style trace-correlated structured
    logging not confirmed present.
  - Phase 6 (Dev Workflow): real PR-based review in active use (PRs #31,
    #34 merged this session) — but branch names are ad-hoc
    (`fix/workbench-prediction-gates`, `payment`, `blitzyhbec`), not the
    guide's `feature/issue-[id]-[slug]` convention.
  - Phase 7 (Testing & QA): **real, per-service CI test jobs exist**
    (`harness-tests`, `harness-integration`, `student-backend-tests`,
    `admin-backend-tests`, `student-frontend`, `mobile`, `config-parity`,
    `ci-success` gate) — a genuine strength, not a template. **Gate 6's
    85% coverage threshold is not met and not close**: `QUALITY_BASELINE.md`
    ratchets coverage per service at 30%/15%/10% (harness/student/admin).
    Zero mutation testing anywhere (`stryker`/`mutmut`/`cosmic-ray` all
    absent).
  - Phase 8 (Security): `security-scan.yaml` runs Gitleaks + TruffleHog +
    Trivy on every push — real SCA/secret-scanning, not aspirational.
    Threat model template exists, never filled in (see above).
  - Phase 9 (CI/CD & Release): substantially *exceeds* the guide's baseline
    as of today — see guide 10's entry below for the immutable-tagging/
    build-once work. No `CHANGELOG.md` is auto-generated, despite commit
    message discipline (`fix(deploy):`, `feat(exam-practice):` — real
    Conventional Commits throughout) that would make this nearly free to add.
  - Phase 10 (Production Readiness): `docs/PRODUCTION_READINESS.md` is a
    real, detailed, populated checklist (DB/app/cache/rate-limit/circuit-
    breaker/timeout/queue/memory/monitoring/degradation/load-balancing/
    health-checks), not a template. Liveness/readiness health endpoints are
    real and already documented in `CLAUDE.md` (`/health/live/`,
    `/health/ready/` on Django; `/health`, `/health/ready` on the harness).
    Still: per the SLO finding above, none of this is *operationalized*
    with alerting that would actually catch a live breach.
  - Phase 11 (Operations): `SRE/EMERGENCY_RECOVERY_RUNBOOK.md` is real and
    populated (a genuine Incident Runbook). Postmortems: see the top finding
    — zero written despite ample real incidents that warranted one.
- **Compliance:**
  - [x] PR-based code review in active practice
  - [x] Per-service CI test suite, gated on a `ci-success` job
  - [x] Automated secret/dependency scanning on every push
  - [x] OpenAPI specs exist and are current, per service
  - [x] SLOs are actually defined with real targets and an error-budget policy
  - [x] A real, populated production-readiness checklist and emergency
    recovery runbook exist
  - [ ] Zero ADRs exist despite a template being present — the guide's
    single most emphasized Phase 3 artifact is the one most completely
    unused
  - [ ] Threat model template unfilled
  - [ ] Zero postmortems written despite 25+ real incidents on record
  - [ ] Coverage nowhere near the guide's 85% gate; no mutation testing
  - [ ] SLOs/readiness checklists not wired to alerting — they exist on
    paper but a real reliability incident (redis-sentinel) proved they
    aren't being watched in practice

### 2. Project Documentation
- **Method:** guide 2's own content overlaps heavily with guides 1, 4, 6, 8,
  10, and 11 (already run/refined this session) — ISO/NIST/SAMM process
  mapping, testing topology, DB pooling, SRE/SLOs, blue-green/DORA. Rather
  than re-deriving the same findings under a different heading, this run
  focused on what's actually distinctive to guide 2: its companion
  `projects_documentation.md`'s document inventory, and the AI-agent/
  AGENTS.md/MCP-gateway-security material neither of the other guides own.
- **Document inventory (`projects_documentation.md`'s table), checked
  directly against the repo root:** missing `README.md`, `ARCHITECTURE.md`,
  `CONTRIBUTING.md`, `RUNBOOK.md`, `CHANGELOG.md`, `SECURITY.md`,
  `docs/adr/`, `docs/onboarding.md`, `docs/glossary.md` — HBEC does not meet
  the doc's own stated "default minimum for any real project" (README +
  ARCHITECTURE, even short). `SECURITY.md`'s absence is notable given the
  doc's own trigger for it ("handles sensitive data") and HBEC handling
  institutional/student data. The *substance* often exists under different
  names — `CLAUDE.md` (320 lines) carries much of what ARCHITECTURE.md/
  CONTRIBUTING.md would; `PRD.md`, `EngineerApproach.md` exist at root;
  `SRE/EMERGENCY_RECOVERY_RUNBOOK.md` is a real runbook just not at the
  canonical path — but a new contributor or external auditor looking for
  the canonical filenames a professional project is expected to have would
  not find them.
- **AGENTS.md — genuinely present, narrower than expected:** 23 lines,
  scoped entirely to telemetry/observability rules for agent-written code
  (mandatory JSON logs with `trace_id`/`span_id`/`service.name`,
  OpenTelemetry tracing, Prometheus metric types, `/health/live` +
  `/health/ready` pathways) — general engineering conventions live in
  `CLAUDE.md` instead, an unusual but workable split.
- **Checked AGENTS.md's specific mandates against real code — a genuine
  strength, unlike guide 1's template-never-exercised pattern:**
  - `AGENTIC_HARNESS/app/shared/observability/tracing.py`: real OpenTelemetry
    setup, auto-instrumenting FastAPI/SQLAlchemy/Redis/httpx, exporting to
    Jaeger — not a stub.
  - Both Django backends (`STUDENT/hbec_backend`, `ADMIN/adminBackend`)
    wire a custom `core.logging.OpenTelemetryJSONFormatter` in
    `config/settings/production.py` — real, not aspirational.
  - `/health/live`/`/health/ready` pathways: confirmed real (already
    documented in `CLAUDE.md`, cross-referenced under guide 1 above).
  - Not confirmed: whether `structlog`'s output actually carries
    `trace_id`/`span_id` on every log line as AGENTS.md's rule 3 demands
    (structlog is in use in the Harness, but no explicit trace-context
    processor was found wired to it) — worth a direct check, not assumed
    either way.
- **MCP gateway security section: not applicable.** No custom MCP server
  code or `.mcp.json` config found anywhere in the repo — HBEC doesn't
  build MCP servers today, so this section has nothing to check against.
- **Compliance:**
  - [x] AGENTS.md exists and its specific mandates are substantially real
    (OTel tracing in the Harness, JSON+OTel log formatter in both Django
    backends, split health endpoints) — checked in code, not assumed
  - [ ] Canonical doc filenames (README, ARCHITECTURE, CONTRIBUTING,
    RUNBOOK, CHANGELOG, SECURITY) absent at root despite substantial
    content existing under other names
  - [ ] structlog-to-trace-context correlation not confirmed
  - N/A MCP gateway security — no custom MCP servers in this repo

### 10. Deployment And Maintenance
- **Ported sections:** the **Immutable Artifact Tagging and Build-Once
  Promotion** pattern (added 2026-08-11, same session that produced this
  adapter — HBEC's incident is the reason it exists at all). That content
  has since been split out to its own guide, **18. Build Once, Deploy
  Everywhere**, so it's directly reusable outside VPS/Coolify/Caddy
  projects — guide 10 now only keeps the single-host instantiation and
  points to guide 18 for the rest. This adapter section's compliance
  record below applies equally to both.
- **Landed in:** `.github/workflows/cd.yml` (`deploy-staging` /
  `deploy-production` / `rollback-production` jobs),
  `scripts/deploy/image-tags.sh` (the `exists`/`prune` helper).
- **Adaptation:** guide's example assumes a registry push
  (`docker compose pull`); HBEC skips the registry entirely — staging and
  production share one Docker daemon on one VPS, so "promote" is just
  referencing the same already-built local `sha-<gitsha>` tag from a second,
  independently-configured Compose project. Would need to change back to a
  real push/pull if staging and production ever move to separate hosts —
  the guide's `rewire_notes` now says this explicitly.
- **What actually happened (the incident this ported from):** staging's
  generated compose file (`docker-compose.staging.yml`, generated from
  `docker-compose.production.yml` + `scripts/staging_overrides.yml`) was
  missing a `build:` patch for 2 of 9 services. `docker compose build`
  silently skipped them, and the subsequent `up` tried to pull their tag
  from a private registry and aborted the whole rollout while the other 7
  services quietly kept running their previous image. Root-caused and fixed
  at the actual source (the overrides file, not the generated output, which
  would have been silently overwritten on the next regeneration). A second,
  related gap in the same overrides file (two services with no `image:` key
  at all, so they'd never match the `sha-<X>` tag scheme) was caught by
  watching a live deploy end to end and fixed the same way.
- **Compliance:**
  - [x] Every image tagged by immutable git SHA, not `:latest`/`:staging`
  - [x] Production checks for an already-built artifact before rebuilding
  - [x] `.last_good_sha` marker written only after a passing health check
  - [x] Rollback tries a tag-swap fast path before falling back to a rebuild
  - [x] Retention (`image-tags.sh prune`, keep newest 5 per service) so old
    `sha-*` tags don't grow disk usage unbounded
  - [x] Staging parity verified — validated directly against the live VPS,
    twice, including the follow-up fix, not just by code review
  - [ ] Production/rollback path validated via an actual push to `main` —
    implemented and unit-verified (`image-tags.sh exists`/`prune` run
    directly against real Docker state), but not yet exercised through a
    real production promotion or a real rollback trigger. Do this before
    calling this guide's compliance checklist fully closed for HBEC.

## Open gaps (guides not yet applied)

Per `MANIFEST.md`'s fit assessment for HBEC — none of these have been
formally ported yet; listed honestly rather than skipped silently:

- [ ] 4. SRE — `SRE/SLOs.md` **does** define real SLOs and an error-budget
  policy (corrected 2026-08-11 — an earlier version of this adapter wrongly
  said none existed; see the guide 1 section above for how that was caught).
  The actual gap is narrower than "no SLOs": they aren't wired to any
  alerting, so a breach has no mechanism to surface. Production resiliency
  has been reactive (see `dev-logs/HBEC/` incident history) despite the
  targets existing on paper.
- [ ] 5a. Observability — Prometheus/Grafana exist but aren't wired to
  alerting; a crash-looping container (`redis-sentinel`, 7000+ restarts) went
  unnoticed until someone happened to SSH in, discovered in the same session
  that produced this adapter
- [ ] 5b. Secure Application Configuration — partially applied historically:
  the guide's own fail-fast-startup-validation example
  (`_validate_production_secrets()`) IS HBEC's real fix from
  `dev-logs/2026-06-02-hbec-production-resiliency.md` — but that was months
  before this adapter, and hasn't been re-verified as still present/correct
  in the current codebase this session. Treat as "implemented historically,
  not re-verified now," not as an open gap in the same sense as the others.
- [ ] 6. Database Engineering — Postgres-backed, UUIDv7 PK standard not
  reviewed against HBEC's schema
- [ ] 7. Software Security Engineering — the new Financial/Payment Webhook
  Security section's gaps are not hypothetical for HBEC: they're the exact
  findings of `dev-logs/2026-05-21-payment-microservice-audit.md` (missing
  Paynow signature verification, called a "critical vulnerability"; no
  webhook idempotency; a reused-across-trust-domains secret). That audit's
  own research pass found no later document confirming these were closed.
  Needs a direct check against the current `PAYMENTS/` codebase, not another
  paraphrase of the audit.
- [ ] 8. E2E Testing — Playwright config exists for the student frontend;
  not gated in CI as of this adapter's creation
- [ ] 16. AI Agent Orchestration and Delegation — HBEC is the guide's own
  flagship applies_to case (this session's delegation IS the evidence), but
  no adapter section exists yet formally recording HBEC's practice against
  the guide's specific framework (DoD, 3-Step Delegation, Blueprint pattern)
- [ ] 17. AI/LLM System Observability and Behavioral Correctness — same
  situation: HBEC is the source of every example in the guide (the silent
  model-fallback incident, the empty-RAG finding, the 3 agent-behavior
  bugs), but none of the guide's recommended additions (per-request
  model/tier logging, retrieval hit/miss logging, a golden-transcript
  regression suite) have actually been built into HBEC yet — the guide
  exists because of HBEC's history, not because HBEC already does this.

## Review cadence

Re-open this adapter each review cycle. If guide 10 is updated in the
library (e.g. the registry-push variant of the promotion pattern gets
written up), re-port the changed parts here.

- **Adapter version:** 0.4 — ran guide 2 (Project Documentation) against
  HBEC's actual repo state; found the canonical doc filenames absent at
  root despite real substance existing under other names, and confirmed
  AGENTS.md's telemetry mandates are substantially honored in real code.
- **Last synced:** 2026-08-11

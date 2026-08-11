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

### 10. Deployment And Maintenance
- **Ported sections:** the new **Immutable Artifact Tagging and Build-Once
  Promotion** section (added 2026-08-11, same session that produced this
  adapter — HBEC's incident is the reason that section exists at all).
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

- [ ] 1. SDLC — HBEC has `CODEBASE_AUDIT.md` but no formal gate model / ADRs
- [ ] 4. SRE — no SLOs or error budgets defined; production resiliency has
  been reactive (see `dev-logs/HBEC/` incident history) rather than budgeted
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

- **Adapter version:** 0.2 — updated same day after guides 5b/7 gained new
  sections and guides 16/17 were created, all from HBEC's own incident
  history (see `GUIDE_CHAIN_CRITIQUE_2026-08-11.md`).
- **Last synced:** 2026-08-11

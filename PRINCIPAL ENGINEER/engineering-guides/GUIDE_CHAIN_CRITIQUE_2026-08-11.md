# Guide Chain Critique — 2026-08-11

> This is a living document, same as the guides it critiques. Its job is to turn
> real incident history into a prioritized backlog of guide edits — not to be a
> one-time audit that goes stale. Re-run this kind of pass periodically (see
> `growth_tracker.md`'s review cadence) rather than trusting it forever.

## Methodology

Reviewed, in full, against the 15 existing guides:
- All 25 dated incidents in `dev-logs/HBEC/` (2026-05-07 → 2026-07-21)
- 4 root-level `dev-logs/` audit/incident docs (full-system-audit, payment-microservice-audit,
  production-incident-summary, hbec-production-resiliency)
- 9 files in `dev-logs/Lessons/` (AI-Orchestration/, Architectural-Thinking/)
- 8 audit documents living in the HBEC repo itself (`SYSTEM-AUDIT.md`, `PROBLEM.md`,
  `CODEBASE_AUDIT.md`, `DEAD_CODE_REPORT.md`, `QUALITY_BASELINE.md`,
  `VPS_SYSTEMD_LOCKUP_DIAGNOSIS.md`, `scaling_concurrency_report.md`, `productionreport.md`)
- This session's own firsthand deploy-pipeline incident (staging build silently skipping
  2 services, fixed 2026-08-11 — see `PROJECT_ADAPTER_HBEC.md`)

## Cross-cutting throughlines (show up everywhere, not just one guide's problem)

1. **Config/env drift with no fail-fast validation is the single most-repeated root
   cause in the whole corpus.** Dev secrets in production (`hbec@123`, no crash-on-boot
   check), a JWT secret that differs across 3 services, missing env vars/build-args,
   `ALLOWED_HOSTS` too narrow for the actual traffic sources — different symptoms, same
   shape: nothing forced the mismatch to be loud at boot time instead of discovered in
   production.
2. **Generated/derived configuration silently drifts from its source, and nobody diffs
   the output before deploying.** This session's own incident (`staging_overrides.yml`
   missing 2 of 9 service patches) is one instance. The Docker network-mismatch
   regression (`2026-07-10` → recurred `2026-07-13`, explicitly "similar to the admin
   backend issue") is another — same underlying compose-merge defect, left unfixed after
   the first incident, so it fired again on a different service.
3. **Backup/restore scope before a destructive operation is incomplete, and the
   destructive operation runs anyway.** `2026-07-21-hbec-missing-diagrams-and-rollback-bug.md`:
   the CD rollback job backed up `.env` and `docker/secrets/` but not `docker/keys/`, then
   ran `rm -rf /opt/hbec/*` — deleting the JWT keys a fix had *just* restored that same
   morning. This is the exact reasoning this session applied today when extending the
   rollback backup list to include `.last_good_sha` — but the general principle was never
   written down anywhere, so it had to be rediscovered.
4. **Findings get discovered reactively by dedicated audit passes, not prevented
   upfront.** Dead code, a missing PRD/EngineerApproach.md, a missing migration,
   hardcoded secrets — all found *after the fact* in audit sessions, not caught by any
   standing process.

## Guides needing refinement

### 10. Deployment And Maintenance — highest priority
Already extended today with the immutable-tagging/build-once section. Still missing,
backed by real incidents:
- **A named "backup scope must be exhaustive before any destructive wipe" rule.**
  Currently only implicit in this session's own `.last_good_sha` fix. Cite the
  `2026-07-21` JWT-keys regression directly as the worked example of what happens
  when it's skipped.
- **"Service unreachable via gateway" triage checklist.** Four separate incidents
  share this symptom with four *different* root causes (Caddy `handle_path` vs
  `handle`, CSP headers, a stale healthcheck path, a container that never started).
  The value here isn't one fix, it's an ordered checklist so the next occurrence
  gets triaged in minutes instead of rediscovering the same four suspects from
  scratch.
- **Deployment-verification patterns from `Lessons/Architectural-Thinking/`** —
  the Staging/Smoke/Blue-Green comparison and the "False Positive Trap" (checking
  only HTTP 200 misses asset integrity, `localhost`-leaked env bundles, and
  dependency health) — this content already exists and just needs porting in.
- **A short "Host-Level Failure Modes" section.** `VPS_SYSTEMD_LOCKUP_DIAGNOSIS.md`
  is a real incident (systemd unresponsive, zombie mounts, `sudo reboot` doesn't
  even work, requires the hosting provider's panel) at a layer *beneath* everything
  else this guide covers. One incident so far, but it's the kind of thing that's
  useless to rediscover mid-outage.

### 5b. Secure Application Configuration
- **Fail-fast startup validation**, concretely: HBEC's own
  `_validate_production_secrets()` pattern (crash the container on boot if a
  production secret is missing or still a known default) is already invented and
  proven — port it in as the guide's flagship example. Directly addresses
  throughline #1 above, which recurred at least 4 separate times across the
  reviewed history.

### 7. Software Security Engineering
- **A dedicated Financial/Payment Webhook Security section** — or see the new-guide
  proposal below; the payment-microservice audit alone surfaced 6 concrete,
  compliance-relevant gaps (missing Paynow signature verification called a
  "critical vulnerability enabling spoofed payment confirmations," a webhook
  secret reused across trust domains, no idempotency on `paynow_reference`
  causing double-processing, no retry/at-least-once delivery, no
  transaction-level observability, naive fixed-interval polling instead of
  backoff).

### 1. SDLC
- **A technical-debt audit cadence section.** Backed by `DEAD_CODE_REPORT.md`'s
  own self-correction (`apps/sbp/` was initially flagged dead, then corrected to
  "KEEP — was incorrectly flagged") — worth stating explicitly that audit tooling
  itself needs a verify-before-delete step, not just periodic sweeps.
- **A "foundational docs exist before you need them" note.** `productionreport.md`
  found `EngineerApproach.md` and the root `PRD.md` missing and had to create
  them *during* a hardening pass — the guide should say these belong at project
  start, not discovered absent under pressure.

### 15. Code Integration
- **A "single source of truth for cross-file constants" principle.** Three
  separate incidents are the same shape: a value duplicated across files instead
  of imported from one place, and the copies silently diverged — `API_BASE`
  duplicated (Bug #1 in `PROBLEM.md`), a localStorage key name differing between
  two files (`hbec_auth` vs `hbc_auth_token`, Bug #2a), and a copy-pasted invalid
  ORM field (`select_related("release")`) found in *two separate views* hours
  apart on `2026-07-21`, meaning the first fix didn't trigger anyone checking for
  the same mistake elsewhere.

### 9. Performance Engineering
- Minor addition: "the wall is often the LLM provider's rate limit, not your
  code" — `scaling_concurrency_report.md` states this almost verbatim ("Primary
  Bottleneck: LLM Rate Limits... This is the single biggest constraint, not the
  code," hitting a wall at ~90 concurrent chatters against a 90 RPM free-tier
  cap). Also worth a one-paragraph note on capacity-cost-tier estimation, which
  the report does concretely ($40/mo → $260-810/mo at higher tiers).

### 4. Site Reliability Engineering
- **Shallow vs. deep health checks**, direct from `Lessons/Architectural-Thinking/health-check-patterns.md`:
  the "Zombie Service" concept (a service returns 200 from a load-balancer-facing
  shallow check while its actual DB/Redis/upstream dependencies are down) plus a
  ready-made FastAPI code blueprint for a `/health/deep` endpoint. This is fully
  drafted content sitting in the Lessons folder, not something to write from
  scratch.

## Missing guides (new, evidence-backed)

### Proposed: "16. AI Agent Orchestration and Delegation"
None of the 15 existing guides centrally address how a human architect delegates
work to AI coding agents — guide 1 (SDLC) mentions "agent-driven workflow" in
passing, guide 11 (SE Verification) mentions reviewing agent-generated code, but
neither is *about* the delegation loop itself. `Lessons/AI-Orchestration/` has
real, generalizable material already:
- The Builder→Architect identity shift (verification becomes the premium skill,
  not typing)
- A concrete **Definition of Done for agent tasks**: behavioral proof (a real
  test/curl against the target environment, not "it should work"), structural
  integrity, observability, knowledge persistence
- A **3-Step Delegation framework**: a concrete Directive (never vague), an exact
  Verification Script, a Standard Reference the output will be checked against
- **"Directives over Suggestions"** and a Blueprint-repo pattern (standards +
  active/completed directives + verification scripts as one LLM-optimized
  source of truth)
- The **Reverse Engineering Path**: three audit lenses (security, concurrency/
  performance, failure injection) for challenging AI-generated code instead of
  trusting it
This session's own heavy use of parallel subagents (5 research agents for this
very critique, 6 agents to wire the manifest) is itself a live example of exactly
the pattern this guide would formalize.

### Proposed: "17. AI/LLM System Observability and Behavioral Correctness"
Distinct from guide 4 (SRE watches uptime/latency) and guide 8 (E2E watches
functional correctness) — this is about a system that is *up* and *passes its
tests* while silently producing wrong or degraded generative output, which
neither of those catches:
- `2026-07-21`'s own incident: a blank `GOOGLE_API_KEY` caused a silent fallback
  to a weaker model, which then produced materially worse output (missing
  diagrams) — nothing alerted on the quality drop, only a human noticing the
  output looked wrong.
- `SYSTEM-AUDIT.md`'s "LLM Provider — Single Point of Failure" (no cloud fallback
  configured beyond one provider) and "Empty RAG Pipeline" (Qdrant has zero
  vectors, so the LLM answers from parametric knowledge and "may hallucinate" —
  a grounding-correctness failure indistinguishable from a working system unless
  someone specifically checks retrieval, not just chat responses).
- `PROBLEM.md`'s three agent-behavior bugs (#9 stateless chat, #10 wrong agent
  routing, #11 bypassed semantic memory) — the code ran without error in all
  three; the defect was behavioral, not functional.

### Considered and rejected as separate guides
- **Host-OS reliability** — real (see `VPS_SYSTEMD_LOCKUP_DIAGNOSIS.md`), but one
  incident so far; a section inside guide 10 is proportionate, a whole guide
  isn't yet.
- **Dead-code/tech-debt hygiene** — real pattern, but process-weight not
  technical-depth; better as a section in guide 1 than its own guide.
- **FinOps/capacity-cost-planning** — one data point (`scaling_concurrency_report.md`);
  a paragraph in guide 9, not a guide.

## Recommended priority order

Ranked by (a) how many separate incidents point at the same gap and (b) whether
the gap is a *regression* (already burned the team once) vs. a *near-miss*:

1. **10. Deployment** — backup-scope rule + gateway-triage checklist (2 confirmed
   regressions between them)
2. **5b. Secure Application Configuration** — fail-fast startup validation (the
   most-repeated root cause overall, 4+ separate incidents)
3. **17. AI/LLM Observability** (new) — the one domain with zero existing guide
   coverage and a live incident (07-21) that fell through every existing net
4. **7. Security** — payment webhook section (compliance/fraud-risk severity,
   even though incident *count* is lower than #1/#2)
5. **16. AI Agent Orchestration** (new) — strong material already exists in
   Lessons/, lower urgency since it's process guidance rather than a fix for a
   recurring failure
6. **15. Code Integration**, **1. SDLC**, **9. Performance**, **4. SRE** — smaller,
   well-scoped additions each backed by 1-3 incidents; good candidates to batch
   together in one pass once 1-5 are done.

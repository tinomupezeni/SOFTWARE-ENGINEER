# Cross-Project Dev-Log Read-Through

**Date:** 2026-11-14 (started) / 2026-11-23 (completed)
**Project:** Global Engineering
**Type:** Audit
**Status:** Completed

## Summary
This report records the start of a repository-wide read-through of issue logs to identify recurring errors and failure patterns across projects. It establishes a dated audit trail so later reviews can determine when the logs were last read as a whole.

## Context / Trigger
The user asked whether there was a record of the last all-logs reading, then clarified that today's read-through should be recorded now.

## Scope
The intended scope is the issue-log entries under `Architecture_and_Design/`, `Backend_and_API/`, `Database_and_State/`, `DevOps_and_Infrastructure/`, `Frontend_and_UI/`, `Integrations_and_Auth/`, and `Mobile_Apps/`. This entry records that the read-through has started; it does not claim that every entry has been read or that recurrence counts have been established.

## Method
Read the issue logs across technical-area folders, group repeated symptoms and root causes across projects, and record the review date, coverage, and recurrence findings here. Keep this report updated when the review is complete.

## Decisions & Findings
- The repository had recurrence-control guidance and summarized recurring lessons, but no identified current dated record stating when all issue logs were last read together.
- This entry is the dated record for the review initiated on 2026-11-14.
- **Architecture and Design sector reviewed:** 40 Markdown files under `Architecture_and_Design/` (including issue logs, audits, lessons, and principle notes).
- Repeated pattern: **design intent and implementation drift apart.** Examples include unbuilt Redis/background jobs, absent crew tables and constraints, implemented features still marked missing, stale system/client diagrams, obsolete proxy code after consolidation, and ADR decisions not propagated to downstream docs.
- Repeated pattern: **architecture decisions were made without validating operational or domain constraints.** Examples include WebSockets on constrained mobile networks, optimistic concurrency assumptions against Postgres connection limits, and latency injection placed on the hot request path.
- Repeated pattern: **redundancy and safety mechanisms existed in name, but not in effective behavior.** Examples include fallback model aliases sharing the same provider keys, and multiple parallel practice-session architectures with only one connected to the live user path.
- Repeated pattern: **invariants were left in documentation or application logic instead of enforced at the correct boundary.** The sector includes missing composite uniqueness constraints and an audit trail implementation that bypasses the previously chosen database-level design.
- Engineering practice to improve: treat ADRs and architecture diagrams as versioned contracts with owners and status (proposed, implemented, retired); reconcile them against code, deployment configuration, and real request paths during implementation and release review.
- Engineering practice to improve: test the key operational assumptions early with measured workloads and production-like limits (connections, latency, flaky networks, provider quotas) before committing to an architecture.
- Engineering practice to improve: define critical invariants and enforce them at the authoritative layer (database constraints, durable queues/outboxes, genuine independent fallback capacity); verify end-to-end that the live path uses the intended component.
- These are qualitative patterns from the sector, not measured recurrence rates. The other six sectors remain unread; repo-wide recurrence findings remain pending.

## Changes Made
- Added this audit record and recorded Architecture and Design sector findings.

## Verification
- Checked the repository map, recurrence-related reports, and report template.
- Read the 40 Markdown files in `Architecture_and_Design/` and recorded sector coverage.
- Confirmed this report remains explicitly marked In Progress.

## 2026-11-23 Continuation — Remaining Six Sectors

The six remaining technical-area folders were swept (grep over each entry's
`## Summary`/`## Root Cause`/`## Prevention / Rule` sections, full reads where
a cluster needed more context), with emphasis on the newest entries
(2026-11-15 through 2026-11-20) since those postdate the last guide update
(`Global-Engineering-Guides-2026-10-17-recurrence-controls.md`).

**Per-sector themes** (full detail retained in session transcript, condensed
here):

- **Backend_and_API** (294 files): incomplete pattern migrations leaving old
  and new logic coexisting (MARITCHO capability model vs. `active_role`);
  duplicated authorization predicates across layers; check-then-act races in
  state transitions; independently-maintained contract pairs (two regexes,
  two write paths, a reshaping proxy) drifting apart with no test spanning
  both sides; a falsy-zero defaulting bug (`x or DEFAULT` on a non-Optional
  numeric); sentinel/exception conflation (`None` meaning both "infra
  failure" and "real negative result"); defensive `max(x,1)` guards hiding a
  genuine zero case; new item/route kinds added without extending a
  hand-maintained allowlist.
- **DevOps_and_Infrastructure** (284 files): secret/env drift after a partial
  `docker compose up -d <service>` recreate (15+ instances); nginx/proxy
  caching a resolved backend address across recreates (4+ unrelated
  projects); deploy scripts/docs claiming behavior they don't actually
  perform; blue/green identity markers going stale; world-readable secrets
  and no-auth exposed services; stateful service (DB/cache) password or
  major-version changes shipped with no migration path (the single most
  repeated exact pattern in the whole folder); unmonitored resource
  exhaustion (disk, FDs, connection pools); health checks that don't check
  the right signal (confirms the already-named "Zombie Service" pattern).
- **Frontend_and_UI** (216 files): UI wired to nothing (largest cluster,
  15+ files) — a button, dialog, or route exists but was never connected to
  its action; API errors silently reshaped into a success-shaped empty
  state; build-time env vars not actually inlined into the Vite/webpack
  bundle (4+ unrelated projects); frontend/backend DTO shape drift without a
  frontend-side contract test; pointer/focus/reactive-state races;
  rebrand/design-token changes breaking contrast without a cross-check;
  stale E2E suites/selectors left unmaintained after the thing under test
  changed, with CI red and ignored; stale build artifacts served instead of
  current source.
- **Database_and_State** (82 files): seed/sync jobs that upsert but never
  reconcile deletions, or delete-then-upsert non-atomically; a distributed
  lock released without an ownership check; check-then-act races (same class
  as Backend_and_API, confirming it's not framework-specific); SQLite test
  environment diverging from Postgres production dialect (recurring since
  September, still unenforced as a CI gate); missing index / unbounded query
  shipped without an EXPLAIN-verified access path; migration DDL not
  idempotent and not atomic with its own `alembic_version` bookkeeping,
  including two branches independently claiming the same revision number;
  deployment readiness checks confirming schema/health but not required
  reference data.
- **Integrations_and_Auth** (55 files) **and Mobile_Apps** (39 files):
  cross-layer contract drift between a mobile client and its backend, each
  side hand-typing field names/routes independently (dominant Mobile_Apps
  theme); authorization/scope gaps where a dependency pattern was copied
  without the gating it implied (missing role guards, an IDOR regression, a
  rejected bidder retaining chat access via a status-less lookup);
  **prompt injection aimed at the coding agent itself** — a fabricated CLI
  "security vulnerability" message and a committed `AGENTS.md` crafted to
  look framework-generated, both genuinely new and previously uncovered by
  any guide; credentials derived from data already visible to the caller, or
  hardcoded, concentrated in one of several parallel user-creation paths;
  mail/webhook sender-identity drift across environments; parity/audit
  tooling (HBEC's Flutter parity map/script) blind to nested routes it
  should have been checking; placeholder UI wired to the nearest real action
  instead of being inert (the Potemkin pattern's UI-affordance flavor).

## Cross-Sector Synthesis

Collapsing all seven sectors (Architecture_and_Design from 2026-11-14 plus
the six above) into the patterns that actually recur *across* sectors, not
just within one:

1. **"Declared but not wired" generalizes far beyond dev tooling.** The
   original Potemkin Tooling finding (SDLC guide) was named for lint/type/
   migration config never actually run. The same shape recurs as unwired UI
   buttons, deploy scripts that don't do what they claim, architecture
   diagrams/ADRs not propagated to code, and new domain primitives
   introduced without migrating the call sites they were meant to replace.
   This is the single largest cross-sector theme by file count.
2. **Authorization logic is duplicated instead of centralized**, so a
   documented end-to-end authorization matrix can be fully correct on paper
   while two different implementations of the same predicate silently
   disagree in code.
3. **Config/secret changes on stateful services are treated as deploys, not
   migrations** — by far the single most repeated *exact* failure signature
   in the DevOps folder, and the clearest case where the existing guide
   named the general principle (build once, deploy everywhere) without
   covering this specific, very common exception.
4. **Contract tests exist but are scoped too narrowly** — service-to-service
   only — and miss the identical drift failure at frontend/backend
   validation pairs, write/read-path pairs, and proxy/origin pairs.
5. **Errors are reshaped into success-shaped states** at both the frontend
   (empty list) and backend (sentinel `None` meaning two different things)
   layers — the same discipline gap expressed twice, independently.
6. **Two genuinely novel findings with no prior guide coverage**: prompt
   injection aimed at the agent itself (CLI output, committed onboarding
   docs), and distributed-lock release without ownership verification.

## Guide Updates Made (2026-11-23)

Per the "Global rules" mandate to operate from and maintain the
`SOFTWARE-ENGINEER` guide library, the above synthesis was converted into
concrete guide additions (not just restated advice) in the same session:

- `1. SDLC.md` — new "§4 Potemkin Tooling Generalizes" section broadening
  the dev-tooling-specific finding into the general "declared but not wired"
  pattern, with a CI-grep-ban guardrail for superseded-pattern migrations.
- `7. Software Security Engineering.md` — new "Authorization Logic Must Be
  Singular" section (shared-predicate + cross-path contract test guardrail)
  and new "Prompt Injection Targeting the Coding Agent Itself" section (the
  first guide coverage of this failure class).
- `10. Deployment And Maintenance.md` — new "Stateful Services Require a
  Migration Path" section and new "Reverse Proxies Must Not Cache a Backend
  Address Across Recreates" section.
- `11. SE Verification.md` — new "Contract Checks Must Cover Internal
  Boundaries" section and new "Error States Must Preserve Their Real Shape"
  section.
- `6. Database Engineering.md` — new "Check-Then-Act Races and Lock
  Ownership" section and new "Seed/Replication Jobs Must Reconcile, Not Only
  Upsert" section.
- `Lessons/CHEAT_SHEET.md` — three new numbered lessons (incomplete
  migrations, stateful-service config-as-migration, agent-directed prompt
  injection) and the header date range extended through November.

No application code in any tracked project was changed; this is
documentation-only, same scope as the 2026-10-17 recurrence-controls update.

## 2026-11-23 Continuation (2) — Lower-Volume Findings Converted

The findings deferred above were converted into guide sections in the same
session, on request:

- `20. Development Tasks Guide.md` — new "§14 Boundary-Value and Sentinel
  Exhaustiveness" (falsy-zero defaulting, defensive-clamp-hides-real-zero,
  sentinel/exception conflation) and new "§15 UI State Must Not Assume a
  Single Input Stream or a Static Prop" (pointer/multitouch races, stale
  memoized values, per-attempt state leaking across attempts).
- `5. Secure Application Configuration.md` — new "Build-Time Environment
  Variables Must Be Verified as Actually Inlined" section (the Vite/webpack
  static-substitution failure mode, distinct from the existing forbidden-
  string bundle scan).
- `12. HCI.md` — new "Design-Token Changes Must Assert Contrast and
  Distinctness" section (WCAG contrast + perceptual-distance checks on
  palette/rebrand changes).
- `3. Mobile App Agent-First Development Guide.md` — new "§9 Cross-Platform
  Parity Tooling Must Be as Rigorously Verified as the Screens It Checks"
  checklist (parity map/script blind spots on nested features).
- `18. Build Once Deploy Everywhere.md` — added a checklist item for the
  frontend-only-change case (stale served bundle with a healthy backend).

## Follow-ups / Deferred
- Consider whether any of the guide files touched across both passes today
  should be rewired into specific projects' `CLAUDE.md`/`AGENTS.md` per the
  manifest's own "don't copy the whole guide, copy the parts that bite"
  instruction — not done in this session, which was limited to the central
  guide library.

## References
- `index.md`
- `reports/Global-Engineering-Guides-2026-10-17-recurrence-controls.md`
- `Lessons/CHEAT_SHEET.md`
- `Architecture_and_Design/` (40 files reviewed)

---

**Completed By:** Codex
**Duration:** In progress

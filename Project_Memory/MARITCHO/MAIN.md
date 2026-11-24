# MARITCHO — Memory Index

**Last updated:** 2026-11-24
**Project repo:** /home/shadowe/Projects/MARITCHO (GitHub: Rest-creator/MARITCHO)
**One-line what-it-is:** An "inDrive-style" marketplace matching buyers who
post jobs (trade/skill, suburb, budget) to local workers who quote and get
booked — backend (Python, clean-architecture use cases) + Next.js web
frontend + Flutter mobile app.

Read this file first, every session, before touching the codebase. It
should be enough to understand what the project is and why it's built the
way it is without reading source. If something here is stale or wrong,
fix it in the same session you notice — don't leave it for later.

## What this project is
Maritcho connects buyers needing a job done (plumbing, electrical, etc.)
with workers for hire, matched by trade/skill and suburb. Buyers post a job
(trade, suburb/address/GPS, description, pricing mode — FIXED / NEGOTIABLE
/ AFTER_VISIT, photos), get matched to candidate workers, book one, track
the job through BOOKED → IN_PROGRESS → COMPLETED (or DISPUTED), and leave a
review. Non-standard constraints: offline-first (WhatsApp integration, PWA),
designed for inexpensive Android devices and small data bundles, and voice/
photo input preferred over complex forms. In worker-vs-buyer conflicts, the
project explicitly defaults to "design for the worker's worst day."

## Current state
- Backend: FastAPI-style clean-architecture app under `backend/app/apps/`
  (jobs, workers, accounts…), each split into `domain/` (entities, use
  cases, services), `infrastructure/` (SQLAlchemy models/repositories), and
  `interface_adapters/` (routers, schemas, dependencies).
- Frontend: Next.js app under `frontend/src/`, feature-folders under
  `features/` (jobs, employer, worker, accounts…), React Query for data
  fetching (`core/query/`), Playwright E2E + visual regression tests under
  `frontend/e2e/`.
- Mobile: Flutter app exists per AGENTS.md mobile architecture guidelines
  (feature-first `/features/feature_name/{data,domain,presentation}`,
  Cubit-based unidirectional data flow) — not yet explored in depth in this
  memory set.
- Deploy: `deploy/production/` with a `restk-vps` production target
  (recent commit "deploy: default to the restk-vps production target").
- **2026-11-24:** PR #14 ("support typing and GPS location in suburb
  options") reviewed — added `pricing_mode` (FIXED/NEGOTIABLE/AFTER_VISIT)
  and worker police-clearance vetting to the job/worker domain, plus GPS-pin
  location entry on the frontend. Review found and fixed 4 bugs directly on
  the PR branch (commit `319e337`); 3 issues left open as architectural
  (repository save() has no optimistic lock, GPS-only location fabricates a
  fake address string, trade-change-while-MATCHED isn't re-validated) plus
  one logging-standard nit, all posted as a PR review comment. See bug-log
  entries prefixed `MARITCHO-2026-11-24-*` in `Backend_and_API/` and
  `Frontend_and_UI/`.

## Map
- `architecture/` — what the system looks like now (components, data flow,
  boundaries). Derivable from code in principle, kept here so an agent
  doesn't have to re-derive it every session.
- `decisions/` — **why** it's built this way, where "why" isn't visible
  from reading the code (alternatives considered, constraints, trade-offs
  accepted). Don't duplicate code-derivable facts here.
- `implementation/` — notes on specific non-obvious mechanisms (a tricky
  hook, an integration quirk) worth remembering without re-reading the
  code each time.
- `prompts/significant-tasks.md` — prompts that produced non-obvious
  architectural output worth reusing or referencing, not a log of every
  prompt.
- `change-history/` — dated entries, one per session/change that altered
  architecture or decisions. Not a diary of every commit — only entries
  that would otherwise force a re-read of git history to understand "how
  did we get here."

## Known gaps / don't trust this for
This memory set was created during a PR-review session (2026-11-24) that
only touched the `jobs`/`workers` domains and the job-posting frontend
flow. `architecture/`, `decisions/`, and `implementation/` are not yet
populated beyond this index — treat any architectural claim about areas
other than job posting/editing/pricing/location as unverified until a
future session fills them in. Flutter mobile app internals are untouched
here; see `AGENTS.md`'s "Mobile Architecture Guidelines" in the repo root
for the standing conventions instead.

## Related
- Bug/issue log entries for this project: see `SOFTWARE-ENGINEER`
  technical-area folders, filename prefix `MARITCHO-`.
- Reports: see `SOFTWARE-ENGINEER/reports/`, filename prefix `MARITCHO-`.

# Repo map

Read this first, instead of scanning the whole tree. It tells you where
to look for what — the actual content lives in the files it points to,
not here.

## What this repo is

A cross-project engineering memory: bug/issue logs, completed-initiative
reports, a stack-agnostic engineering guide library, and general
working-process notes for how to run a session or task.

**What it is not:** a place for one project's own planning artifacts
(ADRs, procedural workflow docs, architecture decisions). Those belong in
that project's own repo. If you find one here, it's misplaced — check the
originating project's repo for the canonical copy before assuming this
one is authoritative.

## What are you trying to do?

**Debugging something, want to check for a known pattern first**
→ the matching technical-area folder below, filtered by the project's log
prefix (see `README.md`'s "Projects Tracked" list). Bug logs are named
`[PROJECT]-YYYY-MM-DD-brief-description.md`.

**Just found or fixed a bug/misconfiguration, need to log it**
→ copy `templates/issue-template.md` into the matching technical-area
folder (`Architecture_and_Design/`, `Backend_and_API/`,
`Database_and_State/`, `DevOps_and_Infrastructure/`, `Frontend_and_UI/`,
`Integrations_and_Auth/`, or `Mobile_Apps/`), same naming convention.
One entry per distinct issue. Commit and push immediately — don't batch.

**Just finished an audit, refactor, or engineering decision (no bug
involved, or a bug found along the way already has its own log entry)**
→ copy `templates/report-template.md` into `reports/` (flat, not by
technical area — a report usually spans more than one). Same naming
convention, same immediate commit discipline.

**Need a stack-specific engineering standard** (database, security,
deployment, testing, SRE, mobile, performance, SDLC, observability, etc.)
→ [`Principal_Engineer/engineering-guides/MANIFEST.md`](./Principal_Engineer/engineering-guides/MANIFEST.md)
is the real index for this subsystem: each guide's scope, the stack it
assumes, when it applies, and which projects have already absorbed which
guide. Don't copy a whole guide into a project — copy the parts that bite,
per the manifest's own instructions.

**Need to know how an agent should run a session or task, start to end**
→ three things together, not one:
- [`WORKING-PROCESS.md`](./WORKING-PROCESS.md) — general discipline (read
  the standing rules first, verification before claiming done, never
  fabricate a value, match scope to what was asked, state results
  directly).
- [`Principal_Engineer/engineering-guides/16. AI Agent Orchestration and Delegation.md`](<./Principal_Engineer/engineering-guides/16. AI Agent Orchestration and Delegation.md>)
- [`Principal_Engineer/engineering-guides/19. Issue-to-Verified-Production Engineering Workflow.md`](<./Principal_Engineer/engineering-guides/19. Issue-to-Verified-Production Engineering Workflow.md>)
- [`Principal_Engineer/engineering-guides/20. Development Tasks Guide.md`](<./Principal_Engineer/engineering-guides/20. Development Tasks Guide.md>)

**Want the fast, memorizable version of recurring lessons, not the full
technical detail**
→ [`Lessons/CHEAT_SHEET.md`](./Lessons/CHEAT_SHEET.md).

**Want reference material on writing a Claude skill**
→ [`References/`](./References/) — vendored third-party repos (not this
project's own work; each is a snapshot, `.git` stripped, kept only as
reading material).

**Setting up a new project from scratch, want an adapter into this
guide library**
→ [`Principal_Engineer/templates/PROJECT_GUIDE_ADAPTER.md`](<./Principal_Engineer/templates/PROJECT_GUIDE_ADAPTER.md>),
and check `engineering-guides/` for an existing `PROJECT_ADAPTER_*.md`
before writing a new one.

## Full folder map

| Path | Purpose |
|---|---|
| `README.md` | Human-facing intro: purpose, structure, how to log an issue/report |
| `index.md` | This file |
| `WORKING-PROCESS.md` | General agent/session working discipline |
| `Architecture_and_Design/` | Bug/issue logs — architecture & design |
| `Backend_and_API/` | Bug/issue logs — backend & API |
| `Database_and_State/` | Bug/issue logs — database & state |
| `DevOps_and_Infrastructure/` | Bug/issue logs — DevOps & infra |
| `Frontend_and_UI/` | Bug/issue logs — frontend & UI |
| `Integrations_and_Auth/` | Bug/issue logs — integrations & auth |
| `Mobile_Apps/` | Bug/issue logs — mobile apps |
| `reports/` | Completed-initiative reports (flat, cross-cutting) |
| `templates/` | `issue-template.md`, `report-template.md`, a Vite-frontend `Dockerfile` template |
| `Principal_Engineer/` | Stack-agnostic engineering guide library — see its own `engineering-guides/MANIFEST.md` |
| `Lessons/` | General, cross-project lessons + the cheat sheet |
| `References/` | Vendored third-party reference material (not authored here) |

## Governing rules

This repo's own logging discipline is defined once, in
`/home/shadowe/.claude/CLAUDE.md` (global rules, all projects) — treat that
file as the source of truth if anything here ever seems to disagree with
it. In short: log every bug/misconfiguration found or fixed, and every
completed engineering initiative, automatically, without being asked;
follow this repo's own templates; commit and push each entry immediately,
not batched.

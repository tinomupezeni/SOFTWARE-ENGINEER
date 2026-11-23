# Development Issues & Solutions Log

**For an agent:** start at [`index.md`](./index.md) — it maps this whole
repo so you don't have to read everything to find what you need.

A centralized repository for tracking production issues, bugs, and their
solutions across all projects — and, separately, reports on completed
engineering initiatives and decisions that weren't a bug but are still
worth a future reader knowing about. It also holds a stack-agnostic
engineering guide library and general working-process notes — see
`index.md` for the full map.

## Purpose
- Document critical issues and their resolutions
- Record engineering initiatives, audits, and decisions — even ones that
  found no bug — so the reasoning behind them isn't lost
- Build a knowledge base for future debugging
- Track patterns and recurring problems
- Share learnings across projects

## Structure

```
SOFTWARE-ENGINEER/
├── index.md                  # map of this repo, for an agent
├── WORKING-PROCESS.md         # general session/task discipline
├── Architecture_and_Design/   # bug/issue logs, by technical area
├── Backend_and_API/
├── Database_and_State/
├── DevOps_and_Infrastructure/
├── Frontend_and_UI/
├── Integrations_and_Auth/
├── Mobile_Apps/
├── reports/                   # completed-initiative reports
├── Project_Memory/            # per-project living context (see below)
├── templates/                 # issue/report/project-memory templates
├── Principal_Engineer/        # stack-agnostic engineering guide library
├── Lessons/                   # general cross-project lessons + cheat sheet
└── References/                # vendored third-party reference material
```
*(Bug/issue logs are stored in the technical-area directories above and
named `[PROJECT]-YYYY-MM-DD-issue-name.md`. Reports live flat in `reports/`,
same naming convention, since a report usually spans more than one
technical area.)*

### Project_Memory/ — the one exception to "no per-project subfolders"

Bug logs and reports stay prefix-based (no per-project subfolder) because
they're an append-only cross-project log, searched by technical area.
`Project_Memory/` is different in kind: it's a *living, per-project*
context snapshot — current architecture, standing decisions, non-obvious
implementation notes — meant to let an agent orient on a project without
re-reading its whole codebase. That only works as one folder per project,
so it's the deliberate exception to the convention above.

Structure per project (see `templates/project-memory-template/`):
```
Project_Memory/[PROJECT]/
├── MAIN.md                    # read this first — index + current state
├── architecture/               # what the system looks like now
├── decisions/                  # why it's built this way (not code-derivable)
├── implementation/             # non-obvious mechanism notes
├── prompts/significant-tasks.md
└── change-history/             # dated entries, only when they change arch/decisions
```

Rules:
- Update the relevant file **in the same session** that changes
  architecture or a standing decision — don't batch this for later, it
  rots fast otherwise.
- `decisions/` holds the *why*, not facts re-derivable by reading code.
  Don't duplicate code-derivable facts here — that's what makes this
  trustworthy instead of just another stale doc.
- A bug found while working in a project still gets its own bug-log entry
  per the normal convention; `Project_Memory/` cross-references it rather
  than duplicating it.
- One folder per project tracked here (see "Projects Tracked" below).

### Bug/issue logs vs. reports
- **Bug/issue log** (technical-area folders): a specific bug, misconfiguration,
  design flaw, or root-cause finding — something concrete that was broken.
- **Report** (`reports/`): a completed engineering initiative or decision —
  an audit, a refactor, a cleanup pass, an architecture choice — logged even
  when nothing was broken, because the scope, method, and reasoning behind
  the work are worth keeping. A bug found *during* a report's work still
  gets its own bug-log entry; the report cross-references it rather than
  duplicating it.

## Projects Tracked

ARCHCODE, ARCHI, ATELIER, Attendance, CANOPYRX, chemglee-concept-site, CLUBZERO, CRM, crucible,
Email-Sender, event-spark, FRUGAL_CORE, HBCA, HBEC, KAREN, LEC, LoanManagement, MARITCHO,
Market-Link, OREPULSE, PFMCP, ProjectFlow, RESTK, SavensBlog, shipwright, TESC, tese-marketplace,
ZCHPC, ZCHPC-ERP, ZCHPC-WEB, ZIMDASH — one bug-log/report prefix per project, not
a subfolder per project (see Structure above). This list is generated from
the actual filenames in use; if you add a new project's first entry, add
its prefix here too.

## How to Use

### Automatic (Recommended)
Claude Code is configured (via `/home/shadowe/.claude/CLAUDE.md`, the
global rules file) to automatically create issue logs and reports when it
finds or fixes a bug, or completes an engineering initiative — in any
project, without being asked. Just work normally.

### Manual
**Bug/issue:**
1. Copy template: `templates/issue-template.md`
2. Name it: `[TECHNICAL_CATEGORY]/[PROJECT]-YYYY-MM-DD-brief-description.md`
3. Fill in all sections
4. Commit and push

**Report:**
1. Copy template: `templates/report-template.md`
2. Name it: `reports/[PROJECT]-YYYY-MM-DD-brief-description.md`
3. Fill in all sections
4. Commit and push

## Quick Links

- [Repo map for an agent](./index.md)
- [Issue Template](./templates/issue-template.md)
- [Report Template](./templates/report-template.md)
- [Reports](./reports/)
- [Engineering Guide Library](./Principal_Engineer/engineering-guides/MANIFEST.md)
- [Working Process](./WORKING-PROCESS.md)

---

**Last Updated:** 2026-09-29

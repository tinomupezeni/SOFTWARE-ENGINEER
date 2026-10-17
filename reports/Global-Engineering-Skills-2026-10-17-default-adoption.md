# Default Agent Skill Adoption

**Date:** 2026-10-17
**Project:** Cross-project engineering standards
**Type:** Architecture Decision / Adoption
**Status:** Completed

## Summary
Added safe project-adoption tooling to the standalone `engineering-skills`
repository and applied the portable engineering baseline to HBEC's existing
agent instructions. The rollout deliberately avoided creating or modifying
instruction files in projects where the target file or worktree state was not
safe to change implicitly.

## Context / Trigger
The portable engineering skills were already published, but projects still
needed a controlled way to adopt the default baseline without silently
overwriting local instructions or mixing changes with dirty worktrees.

## Scope
Included adapter-specific instruction snippets, a safe baseline installer,
adapter command metadata, validation, source freshness checks, and the first
project integration in HBEC. TESC, TESE-MARKET, and SMEPulse were not modified
because they did not have an existing root `AGENTS.md` or `CLAUDE.md` suitable
for an implicit append, and their worktrees contained unrelated changes.

## Method
Validated the standalone pack and source freshness, reviewed project-local
instruction files and worktree status, tested the installer against a temporary
fixture, and applied the installer only where an existing instruction file was
present. Commits were isolated so unrelated project changes remained untouched.

## Decisions & Findings
- The installer updates the first existing root `AGENTS.md` or `CLAUDE.md`.
- It refuses to create a new instruction file, preventing accidental project
  policy creation.
- Re-running the installer is idempotent and does not duplicate the baseline.
- Adapter snippets remain reviewable artifacts rather than automatic edits.
- HBEC was safe for initial adoption because it already had `AGENTS.md`; the
  other three projects require explicit instruction-file and worktree review
  before adoption.

## Changes Made
- Published `tinomupezeni/engineering-skills` commit `a001aaf`:
  - Added `scripts/install-baseline.js`.
  - Added adapter-specific `AGENTS-SNIPPET.md` files.
  - Added verified project commands and compose metadata to adapters.
  - Documented the review-first adoption workflow.
- Published HBEC commit `e87b6450`:
  - Added the engineering skills baseline to `AGENTS.md`.

## Verification
- `npm run validate` passed with 15 skill surfaces.
- `npm run source:check` passed at canonical guide commit
  `40485a09f1d4f1d300cf59fc173e3b63c26fc077`.
- `git diff --check` passed for the standalone changes and HBEC update.
- Installer fixture test confirmed first-run installation and idempotent
  second-run behavior.
- Both standalone and HBEC commits were pushed successfully.

## Follow-ups / Deferred
- Review and explicitly adopt snippets in TESC, TESE-MARKET, and SMEPulse.
- Decide whether those projects should add a root `AGENTS.md`, `CLAUDE.md`, or
  another supported instruction include.
- Add ecosystem-specific discovery smoke tests and optional pull-request
  freshness automation.
- Consider formalizing a strict schema for adapter YAML fields.

## References
- `engineering-skills` repository: https://github.com/tinomupezeni/engineering-skills
- Standalone adoption commit: `a001aaf`
- HBEC adoption commit: `e87b6450`
- `Principal_Engineer/engineering-guides/MANIFEST.md`
- `reports/Global-Engineering-Skills-2026-10-17-standalone-distribution.md`
- `reports/Global-Engineering-Skills-2026-10-17-adoption-tooling.md`

---

**Completed By:** Copilot
**Duration:** One session

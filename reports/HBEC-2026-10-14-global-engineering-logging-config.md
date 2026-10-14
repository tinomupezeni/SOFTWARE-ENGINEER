# HBEC Global Engineering Logging Configuration

**Date:** 2026-10-14
**Project:** HBEC
**Type:** Architecture / Engineering Process Decision
**Status:** Completed

## Summary

The repository configuration now explicitly mirrors the user-level Claude
engineering-memory and reporting rules. Agents working in HBEC are directed to
record bugs and misconfigurations as issue logs, record completed engineering
initiatives as reports, consult the central engineering guides before complex
work, and commit/push each completed central log entry immediately.

## Context / Trigger

The global Claude configuration already required this behavior, but HBEC's
checked-in `CLAUDE.md` and `AGENTS.md` only described repository-local
telemetry requirements. The missing local reminder made the process dependent
on user-level configuration and less visible to contributors or other agents.

## Scope

Included:

- Root `CLAUDE.md`
- Root `AGENTS.md`
- A central report documenting the configuration decision

Excluded:

- Changes to application logging or telemetry implementation
- Changes to the user-level Claude configuration, which already contains the
  authoritative rule
- Changes to nested service-specific agent files

## Method

The user-level `/home/shadowe/.claude/CLAUDE.md`, the
`SOFTWARE-ENGINEER` repository's `README.md`, `index.md`, issue template,
report template, and engineering-guide manifest were read first. The HBEC
configuration files were then updated with a concise checked-in mirror of the
global requirements.

## Decisions & Findings

- The user-level Claude file remains the authoritative source for the full
  rule.
- HBEC's root configuration now makes the rule discoverable in repository
  context.
- Issue logs remain organized by technical area, not by project directory.
- HBEC entries use the `HBEC-YYYY-MM-DD-brief-description.md` naming
  convention.
- Completed initiatives use the central repository's flat `reports/` folder.

## Changes Made

- Added a **Global Engineering Logging** section to `HBEC/CLAUDE.md`.
- Added a **Global Engineering Memory and Reporting** section to
  `HBEC/AGENTS.md`.

## Verification

- Confirmed both HBEC configuration files contain the central repository path,
  issue/report template requirements, engineering-guide requirement, and
  immediate commit/push requirement.
- No runtime or application behavior changed; no test suite was required.

## Follow-ups / Deferred

- Nested service-specific agent files can add narrower rules when a service
  needs them; they do not replace the root rule.

## References

- `/home/shadowe/.claude/CLAUDE.md`
- `HBEC/CLAUDE.md`
- `HBEC/AGENTS.md`
- `SOFTWARE-ENGINEER/templates/issue-template.md`
- `SOFTWARE-ENGINEER/templates/report-template.md`
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/MANIFEST.md`

---

**Completed By:** Copilot
**Duration:** One session

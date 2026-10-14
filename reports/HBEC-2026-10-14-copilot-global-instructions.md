# Copilot Global Engineering Instructions

**Date:** 2026-10-14
**Project:** HBEC
**Type:** Configuration / Engineering Process Decision
**Status:** Completed

## Summary

Copilot CLI now has a global instruction file mirroring the cross-project
engineering-memory, issue-reporting, and engineering-guide requirements already
defined in the user's global Claude configuration.

## Context / Trigger

The global rule existed for Claude Code but was not present in Copilot CLI's
global instruction location. As a result, Copilot had no dedicated global
instruction file requiring issue logs, initiative reports, guide consultation,
or immediate publication of engineering records across projects.

## Scope

Included:

- `/home/shadowe/.copilot/copilot-instructions.md`
- Documentation of the configuration change in this report

Excluded:

- Repository-local Copilot instruction files
- Changes to application code or repository configuration
- Changes to `/home/shadowe/.copilot/config.json`, which stores runtime
  settings rather than agent instructions

## Method

The Copilot CLI documentation was consulted to identify the supported global
instruction path. The existing global Claude rule and the
`SOFTWARE-ENGINEER` repository's README, index, and report template were then
used as the source of truth for the mirrored instructions.

## Decisions & Findings

- Copilot's supported global instruction file is
  `/home/shadowe/.copilot/copilot-instructions.md`.
- The mirrored rules apply across projects and sessions.
- Issue logs remain organized by technical area.
- Initiative reports remain in the flat `reports/` directory.
- The global Claude file remains authoritative; Copilot now carries the same
  operational requirements in its own supported instruction file.

## Changes Made

- Created `/home/shadowe/.copilot/copilot-instructions.md` with:
  - automatic issue and misconfiguration logging;
  - automatic initiative and decision reporting;
  - mandatory consultation of the global engineering guides;
  - immediate commit and push requirements.

## Verification

- Confirmed the file exists at Copilot's documented global instruction path.
- Confirmed it contains the central repository path, templates, technical-area
  directories, report directory, guide manifest, and commit/push requirements.
- No application behavior changed; no runtime test suite was required.

## Follow-ups / Deferred

- Copilot may additionally load repository-local
  `.github/copilot-instructions.md` or scoped instruction files when a project
  needs narrower rules. No such file was added to HBEC.

## References

- `/home/shadowe/.copilot/copilot-instructions.md`
- `/home/shadowe/.claude/CLAUDE.md`
- `SOFTWARE-ENGINEER/index.md`
- `SOFTWARE-ENGINEER/templates/report-template.md`
- Copilot CLI instruction-file documentation

---

**Completed By:** Copilot
**Duration:** One session

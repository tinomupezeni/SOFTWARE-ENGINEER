# Local Copilot Engineering Skills Enablement

**Date:** 2026-10-17
**Project:** Local Copilot CLI environment
**Type:** Configuration / Adoption
**Status:** Completed

## Summary
Installed all 12 portable engineering skills from the public
`tinomupezeni/engineering-skills` repository for GitHub Copilot at global user
scope and added global routing instructions requiring `engineering-baseline`
for every engineering task.

## Context / Trigger
The skills repository was published, but the local Copilot CLI had not yet
been configured to discover or automatically apply the skills when the user
made a normal request such as “fix this issue.”

## Scope
Included global skill installation for GitHub Copilot and the global
`~/.copilot/copilot-instructions.md` routing rule. This did not add
project-specific adapters, modify application repositories, or create a hard
CI enforcement mechanism.

## Method
Inspected the skills installer and existing global skill state, listed the
public package, installed all portable skills using the explicit
`github-copilot` agent identifier, updated the global Copilot instruction file,
and verified installed paths and agent associations.

## Decisions & Findings
- The supported agent identifier is `github-copilot`, not the display label
  “GitHub Copilot.”
- All 12 public engineering skills are installed globally under
  `~/.agents/skills/`.
- `engineering-baseline` is explicitly required for every engineering task,
  including ordinary issue-fix requests.
- Specialist skills are selected based on the baseline classification.
- Skills and instructions guide agent behavior; tests, CI, deployment gates,
  and repository policy remain the hard enforcement mechanisms.

## Changes Made
- Installed globally for GitHub Copilot:
  `agent-delegation`, `ai-behavioral-correctness`, `configuration-parity`,
  `contract-integrity`, `database-change-safety`, `deployment-truth`,
  `distributed-consistency`, `engineering-baseline`, `issue-to-production`,
  `observability-correctness`, `security-boundaries`, and `task-contract`.
- Added the `Portable engineering skills` section to
  `/home/shadowe/.copilot/copilot-instructions.md`.

## Verification
- `npx skills list --global --agent github-copilot --json` reported all 12
  skills with source `tinomupezeni/engineering-skills`.
- Confirmed each installed skill contains `SKILL.md` under
  `/home/shadowe/.agents/skills/`.
- Confirmed the global instruction requires automatic baseline routing.
- The `SOFTWARE-ENGINEER` worktree remained unchanged except for this report.

## Follow-ups / Deferred
- Restart an existing Copilot CLI session if it was already running before
  installation, so it reloads global skill discovery and instructions.
- Keep CI and repository checks as the enforcement layer for measurable
  requirements.
- Periodically run the skills updater after reviewing upstream changes.

## References
- Public skills repository:
  https://github.com/tinomupezeni/engineering-skills
- Global Copilot instructions:
  `/home/shadowe/.copilot/copilot-instructions.md`
- Global skill root: `/home/shadowe/.agents/skills/`
- Public pack commit: `981f545`

---

**Completed By:** Copilot
**Duration:** Same session

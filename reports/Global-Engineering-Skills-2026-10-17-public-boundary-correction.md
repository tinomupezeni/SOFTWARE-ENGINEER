# Public Skills Pack Boundary Correction

**Date:** 2026-10-17
**Project:** Cross-project engineering standards
**Type:** Architecture Decision / Cleanup
**Status:** Completed

## Summary
Corrected the public `engineering-skills` repository so it contains reusable
agent skills and generic tooling, not project-specific adapters or instruction
snippets. The four local project adapters added during the adoption phase were
removed, while the generic adapter template was retained.

## Context / Trigger
The public repository is intended for any developer to install and use.
Project-specific commands, environment facts, and agent instructions for HBEC,
TESC, TESE-MARKET, and SMEPulse were incorrectly committed to that distribution
boundary.

## Scope
Removed the four project-specific adapter directories and their snippets,
updated the public README, and recorded the repository-boundary rule. The
portable skills, bundles, generic validation, source freshness checks, and
generic adapter template were retained. Existing HBEC project adoption was not
reverted because it is a target-repository change and was separately published.

## Method
Inspected the public repository contents and package documentation, identified
the portable-versus-project-specific boundary, logged the issue in the
canonical issue directory, removed only the explicitly named adapter files,
and reran the pack and freshness validation.

## Decisions & Findings
- `engineering-skills` contains portable skills, bundles, generic maintenance
  tooling, and templates only.
- Project-specific adapters and snippets must live in the target project or a
  separately scoped integration repository.
- The generic `adapters/ADAPTER-TEMPLATE.yaml` remains as guidance without
  publishing local project facts.
- The removal does not change the 15 installable skill surfaces.

## Changes Made
- Published `tinomupezeni/engineering-skills` commit `981f545`.
- Removed the HBEC, TESC, TESE-MARKET, and SMEPulse adapter manifests and
  `AGENTS-SNIPPET.md` files.
- Updated `engineering-skills/README.md` to document the public boundary.
- Added issue log:
  `Architecture_and_Design/ENGSKILLS-2026-10-17-public-pack-contained-project-specific-adapters.md`

## Verification
- `npm run validate` passed: 15 skill surfaces.
- `npm run source:check` passed at canonical guide commit
  `40485a09f1d4f1d300cf59fc173e3b63c26fc077`.
- `git diff --check` passed.
- Confirmed `adapters/` contains only `ADAPTER-TEMPLATE.yaml`.
- Public repository cleanup was pushed successfully.

## Follow-ups / Deferred
- Keep project-specific adoption data in target repositories or a separately
  scoped integration repository.
- Add a CI policy that rejects project-specific adapter directories if the
  public repository later grows more adapter content.
- Revisit whether the generic installer belongs in this public pack or in a
  separate adoption-tooling repository.

## References
- Issue log:
  `Architecture_and_Design/ENGSKILLS-2026-10-17-public-pack-contained-project-specific-adapters.md`
- Public cleanup commit: `981f545`
- `engineering-skills/adapters/ADAPTER-TEMPLATE.yaml`

---

**Completed By:** Copilot
**Duration:** Same session

# Standalone Engineering Skills Distribution

**Date:** 2026-10-17
**Project:** SOFTWARE-ENGINEER
**Type:** Architecture Decision / Distribution
**Status:** Completed

## Summary
Created the public standalone repository
`tinomupezeni/engineering-skills` as an installable distribution of portable
agent skills derived from this repository's engineering guides. SOFTWARE-
ENGINEER remains the canonical engineering knowledge source; the standalone
repository is the curated, installable skill surface.

## Context / Trigger
The engineering guides are valuable across agents and projects, but long
reference documents are not reliably activated as default agent behavior.
The proposed solution was to extract focused skills with explicit triggers,
evidence requirements, bundles, and project adapters while preserving the
guide library as the source of institutional knowledge.

## Scope
Included:

- 12 portable core skills;
- 3 installable bundles;
- source-to-skill mapping manifest;
- project-adapter template and initial adapters for HBEC, TESC, TESE-MARKET,
  and SMEPulse;
- metadata validation script;
- public GitHub repository, README, package metadata, and MIT license.

Excluded:

- Automatic synchronization from the canonical guide repository;
- project-local installation or agent configuration changes;
- complete project command discovery for the initial adapters;
- CI workflows beyond local skill-surface validation.

These exclusions keep the first distribution reviewable and prevent unverified
project assumptions from becoming default agent behavior.

## Method
Mapped guide clusters to reusable agent behaviors rather than converting each
guide one-for-one. Kept `engineering-baseline` as the default router and
separated specialist controls for contracts, deployment, data, configuration,
observability, security, distributed consistency, delegation, and AI behavior.
Added manifests that record the canonical source repository and source commit.

## Decisions & Findings

- `tinomupezeni/SOFTWARE-ENGINEER` remains the canonical source of engineering
  guidance.
- `tinomupezeni/engineering-skills` is the public distribution repository.
- Skills are curated outputs and must not silently overwrite authored content
  during synchronization.
- The first distribution contains 12 core skills and 3 bundles, for 15
  installable skill surfaces.
- Project adapters remain opt-in and must provide commands and environment
  facts without secrets.
- Executable CI and deployment gates remain a follow-up; skills alone provide
  behavioral guidance but cannot guarantee enforcement.

## Changes Made

Created and pushed commit `62727ac` to:

`https://github.com/tinomupezeni/engineering-skills`

The repository includes:

- `skills/`
- `bundles/`
- `adapters/`
- `manifests/source-map.yaml`
- `manifests/pack.yaml`
- `scripts/validate-skill-pack.js`

## Verification

- `npm run validate` passed with `Validated 15 skill surfaces.`
- `git diff --check` passed in the standalone repository.
- The standalone repository was created as public and pushed to GitHub.
- The canonical SOFTWARE-ENGINEER worktree remains separate from the
  standalone repository.

## Follow-ups / Deferred

- Add a reviewed synchronization workflow from guide changes to skill updates.
- Add CI validation for skill metadata, bundle references, adapter schemas, and
  source-map freshness.
- Populate project adapters from verified project-local documentation.
- Add install smoke tests for supported agent skill installers.
- Rewire the baseline skill into project-local `AGENTS.md` or equivalent files
  so adoption becomes the default rather than an optional installation step.

## References

- `Principal_Engineer/engineering-guides/MANIFEST.md`
- `reports/Global-Engineering-Guides-2026-10-17-recurrence-controls.md`
- `https://github.com/tinomupezeni/engineering-skills`

---

**Completed By:** Copilot
**Duration:** One implementation session

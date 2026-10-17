# Engineering Skills Adoption Tooling

**Date:** 2026-10-17
**Project:** SOFTWARE-ENGINEER
**Type:** Tooling / Process Improvement
**Status:** Completed

## Summary
Added reviewable adoption tooling to the standalone
`tinomupezeni/engineering-skills` repository. The pack now validates skill
metadata, bundle references, adapter manifests, and source freshness against
the canonical engineering-guide repository without silently regenerating or
overwriting curated skill content.

## Context / Trigger
The first standalone skill-pack release established portable skills and
bundles, but it did not yet protect the distribution from malformed metadata,
missing bundle surfaces, incomplete adapters, or unnoticed changes in the
canonical guide library. A synchronization mechanism needed to preserve the
canonical-source boundary while making drift visible.

## Scope
Included:

- enhanced local skill-pack validator;
- GitHub Actions validation workflow;
- canonical source freshness check;
- JSON source freshness report;
- package scripts and README documentation.

Excluded:

- automatic skill regeneration;
- automatic commits or pull requests from the canonical repository;
- project adapter command discovery;
- runtime installation tests for every agent ecosystem.

## Method
Added deterministic checks using Node's standard library and GitHub's public
commits API. Validation inspects every skill and bundle frontmatter, confirms
manifest references resolve, and checks adapter manifests for required
sections. Freshness reporting compares the source-map commit with the latest
commit affecting the canonical engineering-guide path. A source change reports
review required rather than modifying skill content.

## Decisions & Findings

- Source synchronization is intentionally review-only; curated skills must not
  be overwritten by a mechanical generator.
- Abbreviated and full Git SHAs are treated as equivalent when they identify the
  same canonical commit.
- The default CI gate validates pack integrity but does not fail solely because
  the canonical guide repository has newer commits; guide changes require a
  deliberate skill review.
- The standalone repository now has a clear path to future automation without
  coupling its release process to the source repository.

## Changes Made

Published standalone repository commit `9636d61`:

`https://github.com/tinomupezeni/engineering-skills`

Added:

- `.github/workflows/validate.yml`
- `scripts/check-source-freshness.js`
- `scripts/report-source-freshness.js`
- enhanced `scripts/validate-skill-pack.js`
- `npm run source:check`
- `npm run source:report`

## Verification

- `npm run validate` passed: `Validated 15 skill surfaces.`
- `npm run source:check` passed against the canonical guide commit.
- `git diff --check` passed.
- GitHub Actions workflow was committed and pushed with the tooling.

## Follow-ups / Deferred

- Add pull-request automation that opens a review issue when source freshness
  detects a newer canonical guide commit.
- Populate adapters from verified project repositories and add adapter schema
  tests for commands and environments.
- Add install smoke tests for supported agent skill installers.
- Wire the baseline skill into project-local agent instructions by default.

## References

- `https://github.com/tinomupezeni/engineering-skills`
- `reports/Global-Engineering-Skills-2026-10-17-standalone-distribution.md`
- `Principal_Engineer/engineering-guides/MANIFEST.md`

---

**Completed By:** Copilot
**Duration:** One tooling implementation session

# Public Skills Pack Contained Project-Specific Adapters

**Date:** 2026-10-17
**Project:** engineering-skills
**Environment:** Repository design / public distribution
**Severity:** Medium
**Status:** Resolved

## Summary
The public `engineering-skills` distribution contained adapters and agent
instruction snippets for specific private project worktrees. This weakened the
portable/open-source boundary and risked publishing repository-specific
commands and adoption policy in a package intended for any developer.

## Symptoms
- `adapters/` contained manifests and `AGENTS-SNIPPET.md` files for HBEC,
  TESC, TESE-MARKET, and SMEPulse.
- The public README described those project adapters as part of the normal
  distribution.
- The package therefore mixed portable skills with local project integration
  data.

## Environment Details
- **Server/Host:** GitHub
- **Services Affected:** `tinomupezeni/engineering-skills`
- **Related Components:** Public skill distribution, project adoption tooling
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Inspected the published repository contents and README after recognizing that
the package is intended for broad open-source installation.

### 2. Root Cause Analysis
The adoption phase added verified local project commands and snippets directly
to the standalone distribution instead of keeping them in project repositories
or a private/local integration layer.

```bash
cd /home/shadowe/Projects/engineering-skills
find adapters -maxdepth 2 -type f -print
git log --oneline -4
```

### 3. Key Findings
- The portable `skills/` and `bundles/` surfaces were not affected.
- The four named adapters were project-specific and unnecessary for installing
  the general skills.
- The generic installer can remain because it does not embed project facts.

## Root Cause
The repository boundary was treated as both a portable skill package and a
project-adoption registry. That conflated reusable engineering controls with
local commands, environment details, and instruction snippets.

## Prevention / Rule
**Guardrail:** The public skill repository may contain only portable skills,
bundles, generic tooling, and adapter templates; project-specific adapters and
snippets must live in the target project or a separately scoped integration
repository.

This repository-boundary rule prevents local commands and project policy from
being distributed as if they were universally applicable skill content.

## Solution

### Immediate Fix
Remove the HBEC, TESC, TESE-MARKET, and SMEPulse adapter directories and the
README's project-adoption instructions from the public skill pack.

### Long-term Fix
Keep project adoption as an explicit, reviewable operation in each target
repository. If a shared registry is later needed, publish it as a separate
repository with clear scope and access expectations.

## Prevention
- [x] Repository boundary documented
- [x] Project-specific files removed from public distribution
- [x] Generic adapter template retained
- [ ] Add CI policy preventing project-specific adapter directories

## Related Issues
- None

## References
- `engineering-skills` commit `a001aaf`
- `engineering-skills/README.md`
- `engineering-skills/adapters/ADAPTER-TEMPLATE.yaml`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session

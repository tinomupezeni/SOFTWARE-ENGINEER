# Architecture Documentation Drift

**Date:** 2026-10-16
**Project:** SMEPULSE
**Environment:** Development
**Severity:** Low
**Status:** Investigating

## Summary
The repository's checked-in architecture and testing documentation describes an older
application layout that no longer matches the active source tree and Docker Compose
configuration. This can send contributors toward removed applications and obsolete
commands when onboarding or troubleshooting the platform.

## Symptoms
- `SYSTEM_OVERVIEW.md` refers to `citizen-app`, `government-app`, and `agent-portal`.
- The active repository instead contains `citizens-portal`, `gov-portal`, `partner-portal`,
  `admin-portal`, and `pos-admin`.
- `TESTING.md` still documents Agent Portal tests and paths that are absent from the
  current tree.
- `ARCHITECTURE.md` documents the intended backend layers but not the complete set of
  currently deployed services.

## Environment Details
- **Server/Host:** Local development repository
- **Services Affected:** Documentation and developer onboarding
- **Related Components:** FastAPI backend, Django POS backend, portals, Docker Compose
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Compared the root documentation and project structure with the active application
directories and Docker Compose service definitions.

### 2. Root Cause Analysis
The platform appears to have undergone a V2 naming and service-layout transition,
but the older architecture and testing documents were not updated alongside the
source tree and deployment configuration.

```bash
find . -maxdepth 2 -type d
find backend/src -maxdepth 3 -type f -name '*.py'
```

### 3. Key Findings
- `docker-compose.yml` deploys the FastAPI backend, Django POS backend, blockchain
  API, WhatsApp bot, government portal, partner portal, and admin portal.
- The source tree contains no `citizen-app` or `agent-portal` directories.
- Root `package.json` scripts also target removed `citizen-app` and `agent-portal`
  paths, so the documented and scripted development entry points are stale.

## Root Cause
Documentation and root orchestration scripts were left on the pre-V2 application
layout while the active services were renamed, removed, or introduced.

## Prevention / Rule
**Guardrail:** Add a CI documentation consistency check that validates every
workspace path referenced by root scripts and maintained guides exists in the
repository.

This catches renamed or removed applications at pull-request time instead of
allowing onboarding commands and architecture diagrams to drift silently.

## Solution

### Immediate Fix
No source or documentation changes were made during this read-only assessment.

### Long-term Fix
Update `README.md`, `SYSTEM_OVERVIEW.md`, `TESTING.md`, `ARCHITECTURE.md`, and the
root `package.json` scripts to reflect the active V2 service layout.

## Prevention
- [ ] Add a path-reference consistency check to CI
- [ ] Update architecture and testing documentation
- [ ] Replace stale root development/build/test scripts

## Related Issues
- None recorded.

## References
- `README.md`
- `ARCHITECTURE.md`
- `SYSTEM_OVERVIEW.md`
- `TESTING.md`
- `package.json`
- `docker-compose.yml`

---

**Resolved By:** Pending
**Time to Resolution:** Pending

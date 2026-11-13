# Web Builder Node Version Below Dependency Minimum

**Date:** 2026-11-13
**Project:** LEC Biotec
**Environment:** Development build and CI configuration
**Severity:** Medium
**Status:** Resolved

## Summary
The web Docker builder and CI selected Node 20 while the committed `lint-staged@17.3.0` package requires Node 22.22.1 or newer. `npm ci` in the production image build emitted an `EBADENGINE` warning, so the dependency tree was being installed on an unsupported Node version.

## Symptoms
- Docker `npm ci` reported `lint-staged@17.3.0 required node >=22.22.1; current node v20.20.2`.
- The root package declared `node >=20`, which allowed the unsupported combination.

## Environment Details
- **Server/Host:** Local Docker build on Ubuntu 26.04
- **Services Affected:** Web image builder, web CI jobs, local package engine policy
- **Related Components:** `Dockerfile`, `.github/workflows/ci.yml`, `package.json`, `package-lock.json`
- **Time First Observed:** 2026-11-13

## Investigation Steps

### 1. Initial Diagnosis
Ran a local web image build after the web verification and browser suites passed.

### 2. Root Cause Analysis
Compared the image base and CI Node major with the installed package's `engines` metadata.

```bash
docker build -t lec-preflight-web:8d3feb7 .
node -p "JSON.stringify(require('./node_modules/lint-staged/package.json').engines)"
rg -n 'node:20|NODE_VERSION|>=20' Dockerfile .github/workflows/ci.yml package.json
```

### 3. Key Findings
- The Docker builder used `node:20-alpine`; CI used Node 20.
- `lint-staged@17.3.0` declares `node >=22.22.1`.
- The local host's Node 22.22.1 had passed the web verification and browser suites.

## Root Cause
The dependency's minimum Node version rose without the repository's engine declaration, CI version, and Docker builder version moving together.

## Prevention / Rule
**Guardrail:** Keep `package.json`'s `engines.node`, CI `NODE_VERSION`, and the Docker builder's Node major aligned with the highest minimum engine in the locked dependency tree.

This makes unsupported dependency installs visible at the package boundary and keeps CI on the production builder's major version.

## Solution

### Immediate Fix
Raised the root engine minimum to 22.22.1 and moved the web builder and CI to Node 22.

### Long-term Fix
Add an engine compatibility check to the release gate so a future dependency update cannot silently raise the minimum above the selected builder and CI version.

## Prevention
- [x] Configuration changed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code change applied

## Related Issues
- None.

## References
- `Dockerfile`
- `.github/workflows/ci.yml`
- `package.json`
- `package-lock.json`

---

**Resolved By:** Codex
**Time to Resolution:** Same session

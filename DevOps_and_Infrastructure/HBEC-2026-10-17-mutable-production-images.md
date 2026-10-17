# Mutable Production Image References

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Production deployment configuration
**Severity:** Medium
**Status:** Resolved in source; deployment validation pending

## Summary
The production Compose file contains `ollama/ollama:latest` and multiple application image references defaulting to `${TAG:-latest}`. If deployment does not override and verify these values by immutable digest, a registry-side tag change can run unreviewed code in production.

## Symptoms
- Production image selection remains tag-based in the Compose source.
- The audit could not establish the actual deployment substitution or digest verification behavior.

## Environment Details
- **Server/Host:** Production Docker Compose deployment
- **Services Affected:** `docker-compose.production.yml`
- **Related Components:** Container provenance, registry pulls, deployment scripts
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Inspected production image declarations and their default tag expressions.

### 2. Root Cause Analysis
The Compose file accepts mutable image tags at the production boundary, including `docker-compose.production.yml:1261` and application defaults at lines 737, 852, 935, 1044, 1118, 1745, 1800, 1982, and 2027.

### 3. Key Findings
- `docker-compose.production.yml:1261`
- `docker-compose.production.yml:737,852,935,1044,1118,1745,1800,1982,2027`

## Root Cause
Production artifact identity is not enforced by the Compose file itself.

## Prevention / Rule
**Guardrail:** Production deployment validation must reject mutable tags and require reviewed image digests or immutable commit-addressed references.

This prevents a tag mutation from changing the artifact selected by a deployment.

## Solution

### Immediate Fix
Production Compose now fails fast when `TAG` is absent instead of silently falling back to `latest`, and the Ollama image must be supplied through `OLLAMA_IMAGE` as a reviewed immutable digest. The deployment workflow's tag input also no longer defaults to `latest`.

### Long-term Fix
Render the production Compose configuration with the real deployment environment, confirm that every `TAG` is a commit-addressed immutable release tag, and add CI enforcement for digest-only third-party images.

## Prevention
- [ ] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## References
- `docker-compose.production.yml:1261`
- `docker-compose.production.yml:737,852,935,1044,1118,1745,1800,1982,2027`

---

**Resolved By:** Pending
**Time to Resolution:** Pending

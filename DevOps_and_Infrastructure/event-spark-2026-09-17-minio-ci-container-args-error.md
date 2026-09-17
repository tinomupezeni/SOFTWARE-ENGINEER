# Backend CI MinIO Container Args Error

**Date:** 2026-09-17
**Project:** event-spark
**Environment:** Development / CI
**Severity:** High
**Status:** Resolved

## Summary
The backend CI pipeline never successfully ran because the GitHub Actions workflow file contained an invalid `args:` key for the MinIO service container, causing GitHub to reject the file entirely and produce a 0-second "workflow file issue" on every push.

## Symptoms
- Backend CI workflow fails immediately (0 seconds execution time).
- GitHub reports a "workflow file issue".
- No tests were actually executed in CI.

## Environment Details
- **Server/Host:** GitHub Actions
- **Services Affected:** Backend CI Pipeline (MinIO service container)
- **Related Components:** `.github/workflows/backend.yml`
- **Time First Observed:** Since initial setup.

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the GitHub Actions execution logs which indicated a workflow syntax/schema validation error rather than a test failure.

### 2. Root Cause Analysis
Inspected the `backend.yml` workflow file and found that the `minio/minio` service container definition included an `args:` key. This key is not supported in the GitHub Actions service container schema. It was placed there because the `minio/minio` image requires a `server /data` command to start properly, but service containers do not have a valid way to supply startup commands.

### 3. Key Findings
- GitHub Actions rejects workflow files with invalid schema keys like `args:` for service containers.
- The `minio/minio` image does not start automatically without commands.
- The `--health-cmd` for readiness was also problematic as it ran inside the container which did not have `curl` installed.

## Root Cause
The CI workflow file used an unsupported `args:` parameter for a service container to try and start `minio/minio`.

## Prevention / Rule
**Guardrail:** CI workflow definitions should be validated locally with tools like `actionlint` before committing, and the first run of any new CI workflow must be manually inspected to ensure it actually executes tests rather than failing at the parser level.

Validating workflows locally catches schema errors immediately.

## Solution

### Immediate Fix
Swapped the service container image from `minio/minio` to `bitnami/minio`, which is designed to start itself automatically without requiring explicit container startup arguments. 

Moved the readiness check from a `--health-cmd` (which lacked `curl`) to a dedicated workflow step that tests connectivity using tools available on the runner.

### Long-term Fix
Ensure all service containers in GitHub Actions use images that can start with purely environment-variable based configuration (like Bitnami images).

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- PR #2 in `winstonjthinker/event-spark`

---

**Resolved By:** Antigravity
**Time to Resolution:** Fixed in PR #2

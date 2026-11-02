# Green Color Marker Hides Mixed Image Commits

**Date:** 2026-11-02
**Project:** TESC
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

## Summary
The inactive green color's `.sha_green` marker identifies only the backend image commit, while its two frontend containers run different image tags. A single marker therefore does not describe the whole color's artifact set.

## Symptoms
- `.sha_green` is `c6bac5c`.
- `backend-green` and `celery-worker-green` use `c6bac5c`.
- `frontend-client-v2-green` uses `e096a00`; `frontend-admin-v2-green` uses `2d5e497`.

## Environment Details
- **Server/Host:** `tesc-prod` (`10.50.200.35`)
- **Services Affected:** Inactive green deployment identity and promotion verification
- **Related Components:** `.sha_green`, `scripts/bluegreen-deploy.sh`, green image tags
- **Time First Observed:** 2026-11-02 09:42 UTC

## Investigation Steps
### 1. Initial Diagnosis
Read `active_color`, `.sha_blue`, and `.sha_green`, then inspected every colored container's configured image.

### 2. Root Cause Analysis
Compared the single green marker with Docker's per-service image tags and container creation times.

```bash
cat active_color .sha_blue .sha_green
docker inspect --format '{{.Name}} {{.Config.Image}} {{.Created}}' backend-green celery-worker-green frontend-client-v2-green frontend-admin-v2-green
```

### 3. Key Findings
- Blue is active and all four blue services use `94bf94e`.
- Green's backend pair was created later than its two frontend containers.
- The current cutover guard checks running state and marker presence, not per-service image identity.

## Root Cause
The marker tracks one SHA per color, but the deployed color can be updated per service without reconciling all four image identities.

## Prevention / Rule
**Guardrail:** Before cutover, require all four target-color containers' image tags to match the target color marker or record and verify an explicit per-service release manifest.

This prevents a marker from claiming a uniform release when the running color is mixed.

## Solution
### Immediate Fix
No production deployment changed during this read-only architecture inspection. The mismatch is documented for the next green promotion.

### Long-term Fix
Add a per-service image identity gate to the cutover script, or adopt a release manifest that supports intentional component-specific commits.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Live `docker inspect`, marker files, and `scripts/bluegreen-cutover.sh`, 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending

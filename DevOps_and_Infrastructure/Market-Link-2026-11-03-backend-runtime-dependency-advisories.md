# Backend Runtime Dependency Advisories Found During Release Build

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** VM release image build and local npm audit
**Severity:** High
**Status:** Open; separate dependency remediation required

## Summary
The release build reported 11 (4 moderate, 6 high, 1 critical) npm advisories. The critical package entries are proxy-addr.

## Symptoms
- `npm install` reported advisories while building the release image.

## Environment Details
- **Server/Host:** `agromarket-vm`; local audit
- **Services Affected:** Backend dependencies
- **Related Components:** `backend/package-lock.json`
- **Time First Observed:** 2026-11-03 release build

## Investigation Steps

### 1. Initial Diagnosis
Reviewed npm's advisory summary using `npm audit --omit=dev --json` without changing dependencies.

### 2. Root Cause Analysis
The current dependency tree contains packages in reported vulnerable ranges. These were present in the merged package definitions or transitive tree; the release task did not introduce a dependency upgrade.

### 3. Key Findings
- The critical advisory concerns IP spoofing in proxy-addr; high advisories include Nodemailer, axios, and Multer.
- Functional tests and image builds passed; the audit findings need separate review for reachability and safe upgrade paths.

## Root Cause
Dependency versions have not been refreshed against current security advisories.

## Prevention / Rule
**Guardrail:** Include `npm audit --omit=dev` in release review and track remediation of critical runtime advisories.

This surfaces risks that functional tests cannot detect.

## Solution

### Immediate Fix
Recorded the advisory findings for targeted dependency remediation. No forced upgrade was applied during the functional redeployment.

### Long-term Fix
Upgrade affected direct and transitive dependencies with regression testing; replace the production frontend development server with a static production server.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `DevOps_and_Infrastructure/Market-Link-2026-11-03-env-backup-in-docker-build-context.md`

## References
- `backend/package-lock.json`

---

**Resolved By:** Pending
**Time to Resolution:** Pending

## Verification

- npm audit summary captured on 2026-11-03; dependency remediation remains open.

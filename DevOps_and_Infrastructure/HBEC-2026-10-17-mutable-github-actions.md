# Mutable GitHub Actions in Security and Deployment Workflows

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** CI/CD source configuration
**Severity:** High
**Status:** Investigating

## Summary
Active workflows reference third-party GitHub Actions by mutable tags or branches, including `appleboy/ssh-action@v1`, `trufflesecurity/trufflehog@main`, and `aquasecurity/trivy-action@master`. A compromised or retagged upstream reference could execute attacker-controlled code in a runner with deployment secrets.

## Symptoms
- Deployment steps pass database, JWT, signing, provider, and administrator secrets into a mutable SSH action.
- Security scanning steps use mutable branch/tag references.

## Environment Details
- **Server/Host:** GitHub Actions runners and deployment VPS
- **Services Affected:** `.github/workflows/cd.yml`, `.github/workflows/security-scan.yaml`
- **Related Components:** CI supply chain, deployment credentials
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Inspected all active workflow `uses:` references and the environment passed to deployment actions.

### 2. Root Cause Analysis
The workflows do not pin the referenced third-party actions to reviewed immutable commit SHAs.

### 3. Key Findings
- `.github/workflows/cd.yml:132,135-153`
- `.github/workflows/security-scan.yaml:35,54`

## Root Cause
CI trusts mutable upstream names at a privilege boundary where action code can read deployment secrets.

## Prevention / Rule
**Guardrail:** CI policy must reject third-party action references that are not full, reviewed commit SHAs.

This makes the executed action content deterministic and reviewable.

## Solution

### Immediate Fix
Resolve the current action versions through a trusted process and review the resulting SHAs before replacing the mutable references.

### Long-term Fix
Add a CI policy check for immutable action pinning, restrict deployment jobs to protected branches/environments, and minimize secrets available to each job.

## Prevention
- [ ] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## References
- `.github/workflows/cd.yml:132,135-153`
- `.github/workflows/security-scan.yaml:35,54`

---

**Resolved By:** Pending
**Time to Resolution:** Pending

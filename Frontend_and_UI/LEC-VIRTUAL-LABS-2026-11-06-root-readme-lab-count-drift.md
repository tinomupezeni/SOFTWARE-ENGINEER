# Root README Lab Count Drift

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Environment:** Development repository documentation
**Severity:** Low
**Status:** Resolved

## Summary
The root README stated that the application contained 20 labs, while the repository's catalog and living
repository map contained 28 labs. This could mislead contributors and operators about the available catalog.

## Symptoms
- `README.md` reported "20 labs".
- `intelligent_memory_management/architecture/repo-layout.md` reported 28 labs.
- The backend catalog contains 28 non-example manifests.

## Environment Details
- **Server/Host:** Local Git repository
- **Services Affected:** Documentation and contributor understanding only
- **Related Components:** Root README, lab catalog documentation
- **Time First Observed:** 2026-11-06

## Investigation Steps

### 1. Initial Diagnosis
Compared the root README with the project memory index and repository layout.

### 2. Root Cause Analysis
The README was not updated after the biology labs expanded the catalog from 20 to 28.

```bash
find backend/labs/catalog -mindepth 2 -maxdepth 2 -name '*.json' ! -path '*/_example/*' | wc -l
```

### 3. Key Findings
- The backend catalog count is 28.
- The living repository map already documented 28 labs.
- No application behavior depended on the stale README value.

## Root Cause
The root README lab-count summary lagged behind the catalog expansion.

## Prevention / Rule
**Guardrail:** Add a documentation consistency check that compares the documented lab count with the validated
manifest count during CI or release verification.

This catches catalog growth without requiring a contributor to remember every summary document.

## Solution

### Immediate Fix
Changed the root README from 20 labs to 28 labs.

### Long-term Fix
Use `manage.py validate_labs` and a count check as part of release documentation verification.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation updated
- [ ] Code changes required

## Related Issues
- None.

## References
- `README.md`
- `intelligent_memory_management/architecture/repo-layout.md`
- `backend/labs/catalog/`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session

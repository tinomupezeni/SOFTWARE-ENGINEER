# Flutter parity map omits current AI papers and Interactive routes

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development working tree
**Severity:** Low
**Status:** Investigating

## Summary
The web and Flutter parity check exits with two `UNMAPPED` findings because the current Flutter router includes `/exams/:subjectId/ai` and `/interactive`, but `scripts/parity/parity_map.yaml` has no rows for them. The generated report describes the AI papers route as missing and does not reflect the Interactive placeholder.

## Symptoms
- `python3 scripts/parity/web_flutter_parity.py --no-report` exits 1 with two unmapped Flutter routes.
- The checked-in parity report is stale relative to the live router.

## Environment Details
- **Server/Host:** Local workspace
- **Services Affected:** Parity audit and mobile handoff guidance
- **Related Components:** `STUDENT/mobile_flutter/lib/core/navigation/router.dart`, `scripts/parity/parity_map.yaml`, `STUDENT/mobile_flutter/planning/semantic/web_flutter_parity_report.md`
- **Time First Observed:** 2026-11-05

## Investigation Steps

### 1. Initial Diagnosis
Read the current router and parity report during a Flutter handoff review.

### 2. Root Cause Analysis
```bash
python3 scripts/parity/web_flutter_parity.py --no-report
```

### 3. Key Findings
- The router has both routes in the current uncommitted working tree.
- The checker correctly identifies routes absent from the map.
- `/interactive` currently opens a placeholder, so mapping it as complete feature parity would be misleading.

## Root Cause
The router evolved without a corresponding map update and report regeneration.

## Prevention / Rule
**Guardrail:** Run the parity checker as a required check whenever `router.dart` changes. It identifies new routes before a stale mapping can be accepted.

## Solution

### Immediate Fix
None in this read-only handoff session.

### Long-term Fix
Classify both routes accurately in the map, regenerate the report, and wire the checker into the relevant validation path.

## Prevention
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `reports/HBEC-2026-11-05-web-flutter-parity-audit-tool.md`

## References
- `scripts/parity/README.md`

---

**Resolved By:** Pending
**Time to Resolution:** Pending

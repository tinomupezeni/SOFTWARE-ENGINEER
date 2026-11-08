# Learner partition backfill prints raw stdout

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development source review; staging and production not exercised
**Severity:** Low
**Status:** Investigating

## Summary
PR #117 adds a command that emits a plain-text report with print(), despite HBEC AGENTS.md requiring JSON serialization for stdout and forbidding print() statements. The maintenance wrapper captures the child output and includes it in a structured log, but direct invocation still emits raw text.

## Symptoms
- Running scripts/tag_learner_partitions.py --dry-run or without the flag writes a non-JSON line to stdout.

## Environment Details
- **Server/Host:** Local checkout and fetched PR heads.
- **Services Affected:** DevOps and Infrastructure.
- **Related Components:** PR #117; AGENTIC_HARNESS/scripts/tag_learner_partitions.py:32-46; AGENTS.md
- **Time First Observed:** 2026-11-08 PR review.

## Investigation Steps

### 1. Initial Diagnosis
Read PR #117 and #118 diffs and adjacent runtime code.

### 2. Root Cause Analysis
Traced the changed operation through its data, request, or deployment boundary.

### 3. Key Findings
- Running scripts/tag_learner_partitions.py --dry-run or without the flag writes a non-JSON line to stdout.
- This is source-level evidence; no target-environment rehearsal was performed.

## Root Cause
The new CLI report bypasses the repository's JSON logging convention.

## Prevention / Rule
**Guardrail:** Add a lint or CI rule for print() in deploy scripts and require the configured JSON logger for operational reports.

This guardrail exercises the failure path that the PR's current sequential or happy-path tests omit.

## Solution

### Immediate Fix
No fix made in this review. Replace print() with the configured structured logger and keep dry-run counts as fields.

### Long-term Fix
Keep the regression proof in CI and verify the exact deployed artifact before promotion.

## Prevention
- [ ] Add the guardrail above.
- [ ] Verify in staging with the intended migration and app revisions.
- [ ] Confirm the target environment after promotion.

## Related Issues
- PR #117 and PR #118 are stacked.

## References
- PR #117; AGENTIC_HARNESS/scripts/tag_learner_partitions.py:32-46; AGENTS.md

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing

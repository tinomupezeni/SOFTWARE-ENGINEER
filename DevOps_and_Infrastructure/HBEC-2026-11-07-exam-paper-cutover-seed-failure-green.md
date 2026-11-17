# Exam paper cutover seed failure reports success

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** PR #113 source review; deployment not exercised
**Severity:** High
**Status:** Investigating

## Summary
PR #113 adds `scripts/deploy/seed-exam-papers.sh` to the cutover workflow after traffic has moved. The script exits zero when seed files are missing, copying fails, or `seed_on_deploy` fails, and always exits zero at the end. The cutover job can therefore report success while the promised exam-paper content was not seeded.

## Symptoms
- Missing seed directory and failed copy paths emit a warning then `exit 0`.
- A failed `seed_on_deploy` emits a warning; the final command is `exit 0`.
- The workflow calls the script without checking a content postcondition.

## Environment Details
- **Server/Host:** PR head `1c96d3057` (#113).
- **Services Affected:** Admin seed pipeline and student paper availability after cutover.
- **Related Components:** `scripts/deploy/seed-exam-papers.sh`, `.github/workflows/cd.yml`.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Read the new script and its call site in the cutover workflow.

### 2. Root Cause Analysis
All release-critical failure branches deliberately return success; no subsequent deployed paper count or seed status is asserted.

```bash
git show origin/review-pr-113:scripts/deploy/seed-exam-papers.sh
git diff master...origin/review-pr-113 -- .github/workflows/cd.yml
```

### 3. Key Findings
- The seed is part of the PR's production feature promise.
- Traffic is already moved when the script runs, so failure needs an explicit failed/degraded release state and recovery path.
- A green workflow currently cannot prove paper seeding succeeded.

## Root Cause
The deployment script treats a required content state transition as optional warning output and suppresses its exit status.

## Prevention / Rule
**Guardrail:** A deployment test must force the copy and command paths to fail and assert the cutover workflow reports failure or an explicit degraded state that blocks release completion. A successful run must assert the intended papers are present.

## Solution

### Immediate Fix
Pending on PR #113; block the seed-on-deploy claim until the release reports failure honestly and verifies content state.

```bash
# No fix applied in this read-only review.
```

### Long-term Fix
Make seeding a pre-cutover gate where possible. If it must run after traffic moves, propagate failure into the workflow, alert and provide rollback/retry, and verify exact seed versions in the target admin database and student path.

## Prevention
- [ ] Add negative script/workflow tests.
- [ ] Propagate seed failure and verify the content postcondition.
- [ ] Rehearse cutover and recovery in the target environment.

## Related Issues
- PR #113.

## References
- `scripts/deploy/seed-exam-papers.sh` in PR #113, lines 14–41.
- `.github/workflows/cd.yml` in PR #113, cutover seed call.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` returns nonzero for missing seed files, copy failures, and command failures so GitHub cutover reports degraded status. Local negative shell checks passed for missing files and failed copies; target cutover remains pending.

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing

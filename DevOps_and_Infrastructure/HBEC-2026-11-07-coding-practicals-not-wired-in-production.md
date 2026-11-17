# Coding practicals are not wired in production Compose

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** PR #113 source review; production not exercised
**Severity:** Medium
**Status:** Investigating

## Summary
PR #113 adds the coding practical API and a sandbox service to development Compose, but production Compose has no code-runner service, no `CODE_RUNNER_URL` or secret for the harness, and no runner network. The practical check path will return 503 after the PR deploys through the production Compose workflow. The PR description acknowledges this gap.

## Symptoms
- `docker-compose.yml` adds a `coding` profile and runner service.
- `docker-compose.production.yml` has no corresponding service or harness configuration.
- `run_program()` returns unavailable when the URL or secret is unset; the API maps that to HTTP 503.

## Environment Details
- **Server/Host:** PR head `1c96d3057` (#113).
- **Services Affected:** Student coding practicals, Agentic Harness and code runner.
- **Related Components:** Development and production Compose, runner client and coding router.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Compared PR development and production Compose and traced the runner client fallback.

### 2. Root Cause Analysis
The production release manifest does not include the service, network or required configuration for the new API path.

```bash
git show origin/review-pr-113:docker-compose.yml
git show origin/review-pr-113:docker-compose.production.yml
git show origin/review-pr-113:AGENTIC_HARNESS/app/shared/code_runner.py
```

### 3. Key Findings
- The API returns a clear 503 rather than a false grading verdict.
- The advertised practical feature is unavailable in the target deployment.
- No production user journey has been verified.

## Root Cause
The feature's runtime dependency was added only to the development deployment configuration.

## Prevention / Rule
**Guardrail:** A release manifest parity check must assert every enabled student-facing dependency has a production service/network/config path, and a coding-practical smoke test must execute a program through the deployed harness and runner.

## Solution

### Immediate Fix
Pending on PR #113; either wire and verify the runner in production or explicitly defer the student-facing coding feature from this release.

```bash
# No fix applied in this read-only review.
```

### Long-term Fix
Add the hardened runner service and secret to production Compose, connect the harness to its internal network, and verify the exact deployed artifact and end-to-end program check.

## Prevention
- [ ] Add production manifest parity validation.
- [ ] Provision and validate runner secret.
- [ ] Run deployed coding-practical journey before promoting the feature.

## Related Issues
- PR #113.

## References
- `docker-compose.yml` in PR #113, `code-runner` service.
- `AGENTIC_HARNESS/app/shared/code_runner.py` in PR #113, lines 97–103.
- `AGENTIC_HARNESS/app/interactive_learning/coding/router.py` in PR #113, lines 144–150.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` adds per-color runner services on an internal network, a persistent generated token, image build/tag checks, and a deploy smoke that runs a program from the target harness through its runner. Compose and color validator passed locally; target VPS verification remains pending.

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing

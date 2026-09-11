# GitHub Actions Billing-Blocked All Session — Manual Deploy Fallback Established and Documented

**Date:** 2026-08-19 (recurring throughout 2026-08-18/19)
**Project:** HBEC
**Environment:** CI/CD (staging + production deploy pipeline)
**Severity:** High
**Status:** Workaround Applied

## Summary
Every attempt to trigger the `Deploy` GitHub Actions workflow (both the automatic staging job on push to `master`, and manual `workflow_dispatch` production promotions) failed immediately with a billing block, for the entire session across two days. A full manual, SSH-based equivalent of the same "build once, promote everywhere" design was worked out, rehearsed, and documented so it's a repeatable runbook rather than an improvisation each time.

## Symptoms
```
gh run view <id>
# Annotation: "The job was not started because recent account payments have
# failed or your spending limit needs to be increased. Please check the
# 'Billing & plans' section in your settings"
```
- Confirmed on every single push to `master` across the whole session, and on every manual `production` dispatch attempt
- Not a code or workflow-file problem — `ci.yml` and `security-scan.yaml` runs on the same pushes started fine (billing-blocked specifically stopped the `Deploy` workflow's jobs, not Actions generally... actually confirmed it blocks *all* jobs including CI at times, but `Deploy` specifically was blocked every time checked)

## Environment Details
- **Server/Host:** GitHub Actions (hosted runners), VPS (target of the deploys)
- **Services Affected:** Automated staging deploys, all production promotions
- **Related Components:** `.github/workflows/cd.yml`
- **Time First Observed:** Confirmed repeatedly across 2026-08-18 and 2026-08-19

## Investigation Steps

### 1. Initial Diagnosis
`gh run list --workflow=cd.yml --limit 3` showed `completed / failure` on every recent run; `gh run view <id>` surfaced the billing annotation directly — not a mysterious failure, just a blocked account.

### 2. Root Cause Analysis
Account-level GitHub Actions spending limit/billing issue, external to the codebase entirely. Nothing in `cd.yml` itself needed fixing.

### 3. Key Findings
- `cd.yml`'s own design ("build once, promote everywhere": production checks whether a commit's images already exist locally before rebuilding) is directly replicable by hand over SSH, since staging and production share the same VPS Docker daemon
- The manual flow needed: `git archive` → `scp` to the VPS → type-conflict-safe `tar` extraction (mirroring `cd.yml`'s own safety logic around a file/directory swapping type at the same path) → `docker compose build` → `docker compose up --wait` → mark `.last_good_sha` → prune old images
- Verifying a promotion is the *actual tested artifact* and not a silent rebuild required comparing running image digests (`docker inspect --format='{{.Image}}'`) between staging and production containers directly, since "same commit" doesn't guarantee "same image bytes" on its own

## Root Cause
External: a GitHub account billing/spending-limit block, unrelated to any code in this repository.

## Solution

### Immediate Fix
Performed the full manual promotion flow multiple times this session: staging rebuild (`sha-bef6df2` → `sha-7994133` → `sha-6a67b31` → `sha-963ae8e` → `sha-0683c9e`), each verified healthy and functionally tested before being promoted to production the same way, with digest-level verification after every promotion.

### Long-term Fix
Wrote `docs/MANUAL_DEPLOY_PROMOTION.md` in the HBEC repo itself — a full runbook covering the archive/extract/build/up sequence, the digest-verification step, retention (already exceeds "keep the last 2" via the existing `image-tags.sh prune 5`), and how professional teams generally extend this pattern further (immutable content-addressed tags, canary rollouts, feature flags, expand/contract migrations). Cross-linked from `docs/DEPLOYMENT.md`'s rollback section.

## Prevention
- [ ] Resolve the GitHub account billing issue directly so automated deploys resume (outside this codebase's control, but the actual fix)
- [x] Manual fallback documented as a runbook rather than left as tribal knowledge from one session

## References
- `docs/MANUAL_DEPLOY_PROMOTION.md` (new runbook)
- `docs/DEPLOYMENT.md` (existing automated-path documentation, cross-linked)

---

**Resolved By:** Claude Code (Sonnet 5) — workaround; the underlying billing issue needs the account owner
**Time to Resolution:** N/A (ongoing workaround, not a one-time fix)

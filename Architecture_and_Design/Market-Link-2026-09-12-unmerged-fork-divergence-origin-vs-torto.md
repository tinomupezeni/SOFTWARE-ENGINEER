# Two Unmerged Forks of Market-Link Diverged for Months — Neither Side Is a Strict Superset

**Date:** 2026-09-12
**Project:** Market-Link (agromarket)
**Environment:** Production (agromarketing-vm VPS, `10.50.101.17`)
**Severity:** High
**Status:** Resolved (owners chose to cut over to one fork — see `DevOps_and_Infrastructure/Market-Link-2026-09-12-production-cutover-to-torto-fork.md`)

## Summary
Project owners reported "what's currently deployed is an old version." Investigation confirmed the deployed codebase and a second, independently-developed fork (`PearsonMunasheTorto/Market-Link`, referenced on the VPS as the `torto` git remote) had diverged for months with no merge in either direction. Neither branch was simply "ahead" of the other — each had real, unmerged features the other lacked, so "old version" was really "missing features that only exist on the other fork," not a straightforward stale-deploy problem (that separate, simpler stale-image problem was also present and is logged separately, see Related Issues).

## Symptoms
- Owners perceived the live app as outdated/missing functionality.
- No single commit or branch, when inspected in isolation, explained the complaint — the deployed `main` was actually ahead of `origin/main` by 11 commits and included the most recent upstream commit (2026-09-05).

## Environment Details
- **Server/Host:** agromarketing-vm (10.50.101.17)
- **Services Affected:** `marketlink_frontend`, `marketlink_backend` (feature completeness, not availability)
- **Related Components:** `/home/user/Documents/agromarket` (deployed checkout), `torto` remote → `https://github.com/PearsonMunasheTorto/Market-Link.git`
- **Time First Observed:** 2026-09-11/12 (during the stale-image investigation, then confirmed by explicit request to compare the two)

## Investigation Steps

### 1. Initial Diagnosis
Cloned `PearsonMunasheTorto/Market-Link.git` fresh to a scratch location and compared its `main` (`efbb551`, 2026-08-22) against the deployed checkout's `main`.

### 2. Root Cause Analysis
```bash
cd /home/user/Documents/agromarket
git fetch torto
git diff --stat main torto/main
git diff --name-status main torto/main
git diff --numstat main torto/main
git ls-tree -r --name-only main | sort > /tmp/main_files.txt
git ls-tree -r --name-only torto/main | sort > /tmp/torto_files.txt
comm -13 /tmp/main_files.txt /tmp/torto_files.txt   # files only in torto
comm -23 /tmp/main_files.txt /tmp/torto_files.txt   # files only in deployed main
git merge-base main torto/main    # -> empty: no common ancestor found
```

### 3. Key Findings
- 42 of 43 shared source files differed; only `backend/scripts/make-admin.js` existed exclusively on one side (deployed `main`, an ops-only admin-creation script — torto never had it).
- `git merge-base` found **no common ancestor** between `main` and `torto/main`, despite both containing commits with identical messages/dates/authors for the project's early history — the two histories were built from the same original work but reconstructed independently (rebase/re-import), not by branching from a shared commit.
- torto had real features the deployed app lacked entirely:
  - `backend/controllers/authController.js` (+384/−18): email verification via Nodemailer/Gmail, role normalization (farmer/agro_dealer/buyer), farmer-specific required-field validation (farmName, cropCategories, farmSize).
  - `backend/services/marketDataService.js` (+32/−0): an entire `analyzeTrend()` 7-day price-trend function, absent from deployed `main`.
  - Large net additions in `chatController.js`, `FarmerDashboard.tsx`, `Register.tsx`, `Login.tsx`, `AddProduct.tsx`, `MarketplaceListing.tsx`, `ProductDetails.tsx`.
- Deployed `main` had things torto lacked:
  - `frontend/src/pages/AboutUs.tsx` (+23/−79 going main→torto): deployed version had *more* content here.
  - Emmanuel's 2026-09-05 wording-fix commit (`origin/main` tip `2c1bbcc`) and this week's rebase/React-18 dependency fixes — torto's last commit was 2026-08-22, before any of that existed.

## Root Cause
Two developers (or two working copies) built out the same MarketLink app in parallel — one via `origin` (Manzini-Emmanuel/agromarket), one via a separate fork (PearsonMunasheTorto/Market-Link) — without a shared branch strategy or regular merges. Each accumulated real, valuable, non-overlapping work. No CI or PR process existed to force reconciliation, so the split was invisible until someone compared them directly.

## Prevention / Rule
**Guardrail:** Designate exactly one canonical repository+branch as deployable, enforce branch protection (PR-only merges, no direct pushes) on it, and add a scheduled CI job that fetches any other remote referenced anywhere in deploy scripts/docs and fails loudly if `git merge-base` against canonical `main` is empty or has diverged past a small commit threshold.

That check would have caught this within days of the two histories splitting instead of after months of parallel, unreconciled work.

## Solution

### Immediate Fix
Not a code fix — this was a decision point. Reported the full file-by-file, feature-by-feature comparison to the project owner. Owner decided to cut the production deployment over to the `torto` fork outright (accepting the loss of deployed-only content, primarily the Sep 5 wording fixes) rather than perform a manual merge. See `DevOps_and_Infrastructure/Market-Link-2026-09-12-production-cutover-to-torto-fork.md` for the cutover itself.

### Long-term Fix
- Establish one canonical repository and branch for Market-Link; treat any other fork as a PR source, not a parallel production candidate.
- Before any future "deploy from fork X" decision, diff feature-by-feature first (as done here) rather than assuming either side is a strict superset.

## Prevention
- [ ] Pick and document one canonical GitHub repo for Market-Link; archive or formally merge the other fork
- [ ] Add branch protection / PR review so future feature work can't silently diverge for months
- [ ] Re-check whether torto's unique auth/market-trend features (identified above) should be ported into the now-deployed fork, since neither side had everything

## Related Issues
- [[Market-Link-2026-09-11-stale-images-not-rebuilt]] — the simpler, separate cause of "old version" (images not rebuilt in 3 weeks), found in the same investigation.
- [[Market-Link-2026-09-10-frontend-build-json-syntax-stuck-rebase]] / [[Market-Link-2026-09-11-react-version-mismatch-frontend-build]] — issues specific to the (now-archived) `origin`-based deployment.
- [[Market-Link-2026-09-12-production-cutover-to-torto-fork]] — the resulting deployment action.

## References
- `torto` remote: `https://github.com/PearsonMunasheTorto/Market-Link.git`
- `origin` remote (now archived deployment's origin): `https://github.com/Manzini-Emmanuel/agromarket.git`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** ~1 hour of comparison across two sessions

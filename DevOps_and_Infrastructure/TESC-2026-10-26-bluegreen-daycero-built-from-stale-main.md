# Day-Zero Blue-Green Cutover Briefly Served a Regressed Build (built from stale `main`)

**Date:** 2026-10-26
**Project:** TESC
**Severity:** High (brief, real production regression — live users could have
seen an older dashboard missing recently-shipped features for the duration
of the cutover)
**Status:** Fixed; corrected cutover re-verified and live

## Symptoms / Discovery Context

Immediately after the first day-zero blue-green cutover on `tesc-prod`
(documented as "executed and verified" in
`reports/TESC-2026-10-26-blue-green-production-deployment-guide.md`), the
user reported the live dashboard (`https://tesc.zchpc.ac.zw/dashboard`) was
missing a "Current Enrollment" stats card and its helper text that had been
present before the cutover.

## Root Cause

The `main` branch did not actually reflect what was deployed to production.
`tesc-prod`'s real running images were tagged `fcf6985` — a commit that is
**only reachable via `staging`**, not an ancestor of `main`'s tip at the
time (`c720786`). `main` was 166 commits behind the actual deployed
baseline. This was an existing, pre-session drift (not introduced by this
session) — nothing had kept `main` in sync with what was actually shipped to
`tesc-prod` over time; prod had evidently been deployed from `staging`
commits directly on past occasions, without ever updating `main` to match.

The day-zero blue-green migration built its first "blue" image set from
`main` (after cherry-picking just the 3 blue-green scaffold commits onto
it), on the reasonable-looking but wrong assumption that `main` represented
current production code. It didn't — so "blue" was missing ~166 commits of
already-live functionality, including the "ui: clarify student metric card
definitions" commit (`3211214`) that added the "Current Enrollment" card and
its helper text. The cutover briefly made this regressed build the one
serving 100% of public traffic.

**This was caught within minutes** because the user actively checked the
dashboard right after the cutover and noticed the missing card — not because
any automated guardrail flagged it. None of the existing checks
(`check_compose_colors.py`, `verify_expand_contract.py`, the Healthy
container checks) would have caught this, since they all check structural/
migration correctness, not "does this build actually contain the features
the current deployment has."

## Fix

1. **Immediate rollback**: restored the git-committed (pre-cutover)
   `nginx/nginx.conf` via `git checkout -- nginx/nginx.conf` on `tesc-prod`
   and reloaded nginx — reverting traffic to the original, untouched
   unsuffixed containers within about 2 minutes of the bad cutover.
2. **Root-cause verification**: confirmed `fcf6985` (the real deployed
   commit) is not an ancestor of `main`'s prior tip, and confirmed the
   enrollment-card commit (`3211214`) *is* an ancestor of `fcf6985` - i.e.
   the real deployed code already had this feature, and the "blue" build
   simply hadn't been built from it.
3. **Rebuilt the base correctly**: cherry-picked the same 3 blue-green
   scaffold commits onto `fcf6985` directly (not `main`) — resolving one
   real merge conflict in `docker-compose.yml`/`nginx/nginx.conf` by
   reapplying the already-verified-correct content from the earlier
   drift-fix (`e4fbf03`). `main`'s branch pointer was NOT force-updated to
   this corrected history automatically — the harness's own auto-mode
   safety classifier blocked the force-push as a destructive git action,
   correctly requiring separate human sign-off (tracked as a follow-up in
   the companion report, not yet decided).
4. **Verified byte-for-byte equivalence before retrying cutover**: compared
   the rebuilt `frontend-client-v2-blue`'s built JS bundle against the
   live, un-touched original container — identical file size (1,782,234
   bytes) and identical asset hash (`index-51DLyVbi.js`), confirming an
   exact match rather than trusting git history alone.
5. **Re-ran the cutover** after explicit user confirmation. Verified via a
   real HTTP request through nginx (not just internal `docker exec` checks)
   that the live page now references the same asset hash and that the
   served JS contains "Current Enrollment".

## Verification
- `curl -H "Host: tesc.zchpc.ac.zw" http://localhost/` → 200, references
  `assets/index-51DLyVbi.js` (same hash as the original stack).
- `curl .../assets/index-51DLyVbi.js | grep "Current Enrollment"` → present.
- `docker exec backend-blue` cache + `Student.objects.count()` (86,895,
  matching the shared live DB) both pass.
- Old stack (`backend`, `celery-worker`, `frontend-client-v2`,
  `frontend-admin-v2`) confirmed still running, untouched, throughout the
  entire incident and fix (`docker ps` uptime unchanged at "Up 2 days").

## Process takeaway
**Before building a "blue"/replacement image set from any branch, verify
that branch's tip is actually an ancestor of (or identical to) what's
currently live — don't assume a branch named for an environment ("main" /
"production") is kept in sync with that environment in practice.** The
correct check is comparing the branch tip against the deployed image's own
commit-SHA tag (`git merge-base --is-ancestor <deployed-sha> <branch>`), not
trusting repository/branch naming conventions.

## References
- `reports/TESC-2026-10-26-blue-green-production-deployment-guide.md` — the
  day-zero migration this incident occurred during.
- TESC commits: `082616d` (the regressed build, reachable from stale
  `main`), `94bf94e` (the corrected build, based on `fcf6985`), pushed as
  branch `bluegreen-correct-base`.

---

**Found By:** User (live dashboard check immediately post-cutover)
**Fixed By:** Claude Sonnet 5 (session with tinomupezeni)

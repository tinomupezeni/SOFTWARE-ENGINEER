# TESC active_color Marker Drifted to the Wrong Value, Risking a Future Deploy Overwriting Live Traffic

**Date:** 2026-10-26
**Project:** TESC
**Severity:** High (would have caused `bluegreen-deploy.sh` to target the actually-live color for the next deploy, not a cosmetic bug)
**Status:** Fixed

## Symptoms / Discovery Context
Before starting a new blue-green deploy (for the complexity-reduction refactor work), checked `active_color` on `tesc-prod` as a routine pre-flight step. It read `green`. Cross-checked against ground truth (`nginx.conf`'s actual upstream, the real served JS bundle hash via `curl`) and found **`blue` is the color actually serving 100% of live traffic** - the marker was simply wrong.

## Root Cause
`active_color` is only ever supposed to be written by `scripts/bluegreen-cutover.sh`, after a real traffic cutover succeeds. Earlier in this session, during the full-staging-to-prod promotion, `echo green > active_color` was run manually as a **bootstrap trick** to make `bluegreen-deploy.sh` compute its build target as the intended color - at that specific moment this was correct (active really was `green` then, before the corrected cutover to `blue` ran later the same session). The file was never updated again after subsequent `bluegreen-deploy.sh` runs (which only ever touch the *idle* color and never rewrite `active_color`), so it silently carried a stale value from several deploys ago once the color situation had moved on.

Had a future `bluegreen-deploy.sh` run been executed trusting this marker, it would have read `active_color=green`, computed `TARGET_COLOR=blue`, and attempted to build+recreate the `*-blue` containers - the ones actually serving live traffic - believing it was safely targeting the idle color.

## Fix
Verified ground truth three independent ways before trusting any correction: `nginx.conf`'s literal `set $upstream_backend http://backend-blue:8000` upstream, `docker ps` container ages (blue containers "Up 3 hours" vs green "Up about an hour", consistent with blue being the older, stable, cut-over color), and the actual served frontend bundle's asset hash matching blue's known build. Corrected `active_color` to `blue` and re-synced both `.sha_blue`/`.sha_green` markers to the real image tags each container is actually running (`docker inspect <container> --format '{{.Config.Image}}'`), rather than trusting either the stale marker file or memory of what should have happened.

## Process takeaway
**A manually-written marker file used as a bootstrap trick must be treated as a known liability, not a one-time convenience** - it diverges from reality the moment real operations continue past the bootstrap step, with no built-in mechanism to catch the drift. Before any blue-green operation that trusts `active_color`, verify it against at least one independent ground-truth source (nginx's actual config, or the real served response), the same discipline already established earlier today for not trusting git branch names/history alone.

## Verification
- `nginx.conf` and `docker ps` both confirmed `blue` is live before the fix.
- Post-fix: `curl -H "Host: tesc.zchpc.ac.zw"` → 200, confirming the marker correction itself (a metadata-only change, no container touched) had zero effect on live traffic, as expected.

## References
- `reports/TESC-2026-10-26-blue-green-production-deployment-guide.md` and its incident log - the original day-zero migration this marker's bootstrap step was part of.

---

**Found By:** Claude Sonnet 5 (session with tinomupezeni), as a pre-flight check before starting new blue-green deploy work - not from any user-reported symptom.

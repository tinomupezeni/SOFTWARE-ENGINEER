# Blue-Green Phase 1: Real Differing Code Version Deployed to Green and Cut Over

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Architecture Decision Validation
**Status:** Completed

## Summary
Built a genuinely different Docker image for the Student Backend (a new
code path the baseline image does not have), deployed it to the dry-run's
`green` slot only, and confirmed — through the actual Caddy traffic path,
not direct container access — that the proxy serves different application
behavior depending solely on which color is currently active. Switched
traffic blue → green → blue and confirmed both directions. This was the
one piece Phase 1 and the migration test had not yet exercised: every
earlier test used the *same* image for both colors, so nothing had proven
that an actual version difference survives a cutover. Everything was
reverted; production was untouched throughout.

## Context / Trigger
Direct continuation of
[`HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`](HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md)
and
[`HBEC-2026-10-01-blue-green-expand-contract-migration-test.md`](HBEC-2026-10-01-blue-green-expand-contract-migration-test.md),
both of which named this as the next open gap. User asked directly to
"deploy a different code version to green."

## Scope
**Included**: a new, tiny, clearly-labeled test endpoint added on a
throwaway local git branch; a real Docker image built from that branch;
deploying it to green only (blue stayed on the real, already-tested
`prod-promote-6a151782` image); verifying the difference both via direct
container access and via the dry-run Caddy proxy; a full cutover in both
directions.

**Explicitly excluded**: the branch was never pushed to GitHub, never
opened as a PR, and was deleted immediately after the image was built.
The built image was never pushed to GHCR — it was built directly on the
VPS from a tarball of the modified source and loaded straight into the
local Docker daemon, so it never touched any registry, any CI pipeline, or
any path a real deploy could accidentally pick up.

## Method
1. Created a local-only branch (`bluegreen-dryrun-marker`), added one new
   file (`core/bluegreen_marker.py`) and one new URL entry in
   `config/urls.py` — a GET endpoint returning a fixed JSON marker,
   isolated from every real code path (didn't touch `core/health.py` or
   anything load-bearing). Committed locally for a clean build context.
2. Packaged the modified `STUDENT/hbec_backend/` directory as a tarball,
   copied it to the VPS, and built the image there directly with the
   existing `Dockerfile` (`docker build -t
   hbec-student-backend:bluegreen-dryrun-marker .`) — avoided any registry
   round-trip since GHCR packages here are private and `build-publish.yml`
   is disabled; building locally and loading straight into the VPS's own
   Docker daemon sidesteps both issues entirely. Confirmed local dev
   machine and VPS are both `x86_64` first, so no cross-arch build concern.
3. Recreated only `student-backend-green` against the new image
   (`GREEN_IMAGE=hbec-student-backend:bluegreen-dryrun-marker docker
   compose ... up -d --no-deps student-backend-green`), leaving blue
   completely untouched.
4. Verified directly against each container first (`docker exec ... curl`
   equivalent): blue 404s on the new path, green returns the marker.
5. Verified again through the **actual traffic path** — the dry-run Caddy
   instance — before touching the cutover script: blue active, path
   404s through the proxy.
6. Ran the real `cutover.sh green`, then re-checked the same URL through
   the proxy: 200 with the marker, `X-Deploy-Color: green`.
7. Ran `cutover.sh blue` to reverse it, re-checked: 404 again,
   `X-Deploy-Color: blue` — confirming the mechanic is symmetric, not a
   one-way fluke.
8. Reverted green to the shared baseline image, deleted the throwaway
   Docker image and the VPS-side build directory, deleted the local git
   branch, and confirmed the repo was back to a clean `master` with the
   throwaway file gone from disk.
9. Confirmed real production untouched at the end (unchanged container
   start times, unchanged primary disk usage, live site still `200`).

## Decisions & Findings

### The core blue-green promise holds end-to-end
Every earlier test in this series (Phase 1, the migration test) used
identical images for blue and green, so none of them actually proved the
thing blue-green exists for: that switching the proxy's target genuinely
changes which code answers a request, with no restart of the proxy itself
and no gap in service. This test closes that gap with a real differing
image, not an assumption.

### Building and deploying to a single color, cheaply, without a registry
Because this project's GHCr packages are private and the automated
image-publish workflow is disabled (`build-publish.yml.disabled`, see
`HBEC/CLAUDE.md`'s CI/CD section), a from-scratch image for a single color
can't be produced by just re-running the normal pipeline. Building
directly on the target host from a source tarball — no push, no pull, no
registry auth — is a usable path for a dry run or an emergency one-off,
though a real recurring blue-green workflow should still go through a
proper CI build + registry push rather than this manual shortcut.

### The singleton worker/beat correctly follow the cutover target's actual image
`cutover.sh` resolves `STUDENT_WORKER_IMAGE` from
`docker inspect --format='{{.Config.Image}}' bg-student-backend-<target>`
at cutover time, so when green was running the marker image, cutting over
to green also moved the worker/beat onto that same differing image — the
intended behavior (the active color's background processing should match
its web-facing code), confirmed by observation rather than just reading
the script.

## Changes Made
No permanent changes anywhere. The throwaway branch, its one commit, the
built Docker image, and the VPS-side build directory were all deleted by
the end of the test. `git log` on `master` is unchanged from before this
test began.

## Verification
- Direct container check: blue 404, green 200 with marker, before any
  Caddy involvement.
- Through the dry-run Caddy proxy: 404 while blue was active, 200 with
  the marker and `X-Deploy-Color: green` immediately after `cutover.sh
  green`, 404 and `X-Deploy-Color: blue` again immediately after
  `cutover.sh blue`.
- Green confirmed back on the shared baseline image
  (`ghcr.io/rest-creator/hbec-student-backend:prod-promote-6a151782`)
  after cleanup.
- Local repo confirmed clean: `git log --oneline -1` on `master` shows the
  pre-existing commit, the throwaway branch no longer exists
  (`git branch -D`), and the throwaway file is gone from disk.
- Real production confirmed untouched: `hbec-student-backend`,
  `hbec-admin-backend`, and `hbec-postgres` container start timestamps
  unchanged throughout; primary disk usage unchanged
  (~152G/73%, the same ongoing baseline as the prior two reports);
  `https://student.hbca.tech/` returned `HTTP/2 200` at the final check.

## Follow-ups / Deferred
- This closes out the mechanics this session set out to prove for Phase
  1: shared-DB coexistence, expand-phase safety under color skew, a
  working trigger-based dual-write surviving bulk updates, the
  contract-phase failure mode made concrete, and now a real differing
  code version switched live. The three reports in this series together
  are a reasonably complete proof that the *mechanics* work; moving
  toward a real Phase 2 (real secrets, real/replica database, public DNS,
  a proper CI-built image per color) remains a deliberate, separate
  decision the user has not yet made.
- Not yet tested: the automated `migrate --noinput`-on-boot path (this
  session's migration test was driven by hand via `manage.py migrate`,
  not by a container actually booting with a new migration already
  present in its image).
- Not yet tested: a true zero-downtime window measurement during cutover
  (this test confirmed correctness before/after the flip, not whether any
  in-flight request was dropped during the flip itself).

## References
- [`HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`](HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md)
- [`HBEC-2026-10-01-blue-green-expand-contract-migration-test.md`](HBEC-2026-10-01-blue-green-expand-contract-migration-test.md)
- `HBEC/CLAUDE.md`'s CI/CD section (`build-publish.yml.disabled`, GHCR
  package privacy) — the reason this test built on-host instead of via
  registry.

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continuing directly from the migration test.

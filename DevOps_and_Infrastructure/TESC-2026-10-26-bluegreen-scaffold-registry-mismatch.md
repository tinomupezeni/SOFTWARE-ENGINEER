# TESC Blue-Green Draft Scaffold Assumes a Registry-Pull Model That Doesn't Match Real Prod

**Date:** 2026-10-26
**Project:** TESC
**Severity:** Medium (would have caused a failed/confusing first blue-green deploy, not data loss)
**Status:** Found; not yet fixed (fix tracked in the companion guide, see References)

## Symptoms / Discovery Context

Asked to set up blue-green deployment on the `tesc-prod` VM, guided by a
reference doc in this repo. No TESC-specific blue-green guide existed yet,
so before writing one, read the existing draft scaffold already committed to
the TESC repo (`f8646b4` "Add TESC blue-green deployment foundation",
`198c706` "Enforce expand contract migration gate": `docker-compose.
bluegreen.yml`, `scripts/bluegreen-deploy.sh`, `scripts/bluegreen-cutover.sh`,
`scripts/bluegreen.py`) against the project's own documented real deployment
process (`project_docs/04-infrastructure-and-cicd.md`,
`project_docs/09-deployment-and-operations.md`).

## Root Cause

The draft scaffold was written against an aspirational deployment model —
the same one `DEPLOYMENT.md` at the repo root already explicitly flags as
"never actually adopted":

- `docker-compose.bluegreen.yml` pins every app image to
  `ghcr.io/tinomupezeni/tesc-{backend,frontend,inst}:${IMAGE_TAG:-latest}`.
- `scripts/bluegreen-deploy.sh` calls `docker compose ... up -d --wait`,
  which (for a registry-sourced image tag) implicitly assumes the image is
  either already pulled or compose will pull it — i.e. it assumes prod can
  fetch images from a registry.

Real TESC prod (`10.50.200.35`) does neither of these things:
- Images are built **only on the staging VM** (`10.50.1.37`), verified
  there, then shipped to prod as `.tar` files over SFTP (`docker save` →
  `put` → `docker load`). **Prod never runs `docker compose build` and never
  pulls from a registry** — this is a deliberate, explicitly-stated project
  policy (an agent attempting a `docker push` to a public registry mid-deploy
  was previously flagged and stopped, per `project_docs/10`).
- The live registry, where used at all, is Docker Hub
  (`tinotenda762/tesc-backend`, `tinotenda762/tesc-main`,
  `tinotenda762/tesc-inst`) — not GHCR. Prod has stale, unused
  `ghcr.io/tinomupezeni/*` images left over from an earlier, abandoned
  registry choice (harmless disk usage, not live).

Had the draft scaffold been run as-is against `tesc-prod`, `docker compose
up -d --wait backend_green ...` would have either pulled nothing (no
registry credentials/network path expected for that host) or silently
resolved a stale/non-existent `ghcr.io` tag, defeating the entire point of
the immutable-tag-per-color guarantee the rest of the scaffold (expand/
contract migration gate, active-color marker file) depends on.

## Fix

Tracked as part of
`reports/TESC-2026-10-26-blue-green-production-deployment-guide.md`, which
adapts the HBEC blue-green reference pattern to TESC's actual tar-transfer,
no-registry-pull topology instead of the GHCR-pull model the draft assumed.
The compose file's image references and the deploy script's activation step
need to change from "pull `${IMAGE_TAG}`" to "load the already-transferred
`.tar` for the target color, then `up -d --no-deps` with no pull."

## Verification

Not yet re-verified against a real deploy (no blue-green deploy to
`tesc-prod` has happened yet — this scaffold has never been exercised
outside the two unit tests in `tests/test_bluegreen_deployment.py`, which
only check the nginx-config renderer and compose-file shape, not the actual
image-transfer mechanism).

## References

- `project_docs/04-infrastructure-and-cicd.md`, `project_docs/09-deployment-and-operations.md` — the real, current TESC deployment process.
- `DEPLOYMENT.md` (TESC repo root) — already flags the GHCR/self-hosted-runner pipeline as aspirational/never adopted; the blue-green scaffold inherited the same unadopted assumption.
- `reports/HBEC-2026-10-26-blue-green-production-reference-guide.md` — the pattern this is being adapted from.
- `reports/TESC-2026-10-26-blue-green-production-deployment-guide.md` — the adapted TESC guide and fix plan.

---

**Found By:** Claude Sonnet 5 (session with tinomupezeni)

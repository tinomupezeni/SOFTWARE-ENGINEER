# Production deploy switched from local-build-and-upload to build-on-VPS

**Date:** 2026-11-17
**Project:** MARITCHO
**Type:** Architecture Decision
**Status:** Completed

## Summary
`deploy/production/deploy.sh` previously built the `maricho-backend` and
`maricho-frontend` Docker images locally, then uploaded them to the VPS as
gzip-split chunks over `scp` (`deploy_upload.sh`). On this VPS's current
upload bandwidth (~28KB/s observed), that upload step alone took over an
hour for a ~160MB pair of images, for a deploy that should take minutes.
Switched the pipeline to clone/fetch the repo directly onto the VPS and
run `docker compose build` there instead, eliminating the image-transfer
bottleneck entirely.

## Context / Trigger
While deploying MARITCHO PR #12 (a large feature PR — rebrand, workers
directory, messaging, pgvector search) to production, the local-build deploy
ran for over an hour, almost entirely spent on `scp`-uploading compressed
image chunks to the VPS at a few hundred KB/s. The user asked directly: "why
aren't they just being built on the VPS?" — prompting this change.

## Scope
- In scope: `deploy/production/deploy.sh` (local build+upload → remote
  clone+build), `deploy/production/docker-compose.yml` (add `build:`
  contexts alongside the existing `image:` tags), `deploy/production/README.md`
  (document the new flow), removal of the now-dead `deploy_upload.sh`.
- Out of scope: changing the VPS's actual network/bandwidth situation (not
  something this change can fix — it works around it by not needing to
  transfer ~160MB of image layers over it at all), and the already-separately-logged
  issue that the Caddy security-header config still requires a manual merge
  into the central Caddyfile (unrelated to this change, see
  `Integrations_and_Auth/MARITCHO-...worker-directory-endpoints-missing-role-guard.md`
  review's sibling finding).

## Method
Kept every post-image-ready step of `deploy.sh` unchanged (pre-deploy
`pg_dump` backup, rolling `db`/`redis` → `api`/`frontend` update, Alembic
head check, `pgvector` extension verification, frontend smoke check) —
only the "how do the images get onto the VPS" step changed. This kept the
change reviewable as a single, bounded swap rather than a full pipeline
rewrite.

## Decisions & Findings
- **Why build on the VPS instead of fixing the upload path:** the slow part
  wasn't Docker's build time (the earlier deploys with warm caches built in
  under a minute locally) — it was purely the `scp` transfer of the final
  compressed image to this specific VPS. Building on the VPS converts that
  transfer into a `git fetch --depth 1` (a few hundred KB of diff, not
  ~160MB of image layers) plus local-to-the-VPS `npm ci`/`pip install`,
  which run at the VPS's LAN/loopback speed rather than its (apparently
  constrained) upstream bandwidth.
- **Why not build on the VPS by rsyncing the working tree:** used a real
  `git clone`/`fetch --depth 1 origin <ref>` + `checkout --detach FETCH_HEAD`
  instead, so the exact commit being deployed is explicit and reproducible,
  and a stale/dirty local working tree can never accidentally get deployed.
- **Why `docker compose build` instead of two separate `docker build`
  invocations:** the compose file already defines both services; adding
  `build:` blocks alongside the existing `image:` tags means `docker compose
  build api frontend` produces images tagged exactly as the rest of the
  script (and `APP_VERSION`-pinned `image:` fields) already expect, with no
  separate tagging logic needed.
- **Where `.env` lives:** kept outside the git clone, at
  `~/apps/maricho/.env` (the clone goes in `~/apps/maricho/repo/`), so a
  fresh clone or a `git clean -fdx` (needed to reset the build context
  between deploys) can never touch production secrets.
- **Trade-off accepted:** builds (not just the image copy) now run on the
  VPS, briefly costing it CPU/RAM during `npm run build` and `pip install`.
  That VPS already carries many other tenants' containers, which is a build
  spike these will now share, but it is self-limited to the hands-off deploy
  duration rather than a permanent exposure.

## Changes Made
- `deploy/production/docker-compose.yml`: added `build.context` (`../../backend`,
  `../../frontend`) to the `api`/`frontend` services, plus
  `build.args.NEXT_PUBLIC_WS_URL` for the frontend.
- `deploy/production/deploy.sh`: replaced the local `docker build` +
  `upload_image` steps with a remote `git clone`/`fetch --depth 1 origin
  <ref>` + `checkout --detach FETCH_HEAD` + `docker compose build api
  frontend`, run entirely inside the existing SSH heredoc.
- Removed `deploy/production/deploy_upload.sh` (now unused).
- `deploy/production/README.md`: documented the new flow, that `.env`
  lives outside the clone, and the private-repo git-credentials
  requirement on the VPS.
- Commit `a17f888` on `main`.

## Verification
- `docker compose -f docker-compose.yml config --quiet` with the new
  `build:` blocks validates cleanly against a full fake `.env` set
  (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `SECRET_KEY`,
  `APP_VERSION`, `NEXT_PUBLIC_WS_URL`).
- `bash -n deploy/production/deploy.sh` — syntax clean.
- Not yet exercised end-to-end against the live VPS (the in-flight deploy
  of PR #12 at the time of this change was already using the *old*
  upload-based script and was left to finish rather than interrupted
  mid-upload; the new script will be exercised by the next deploy).

## Follow-ups / Deferred
- [ ] Run the new VPS-build flow for the next actual deploy and confirm
  total wall-clock time and that the VPS doesn't struggle under the build
  load alongside its other tenants.
- [ ] Consider whether CI (GitHub Actions) should run deploys instead of a
  developer's local machine, for a more consistent network path to the VPS
  — noted as a discussed alternative but not adopted here.
- [ ] The Caddyfile-merge-into-central-config step remains manual by
  design; no change intended here.

## References
- `deploy/production/deploy.sh`, `deploy/production/docker-compose.yml`,
  `deploy/production/README.md`
- `Integrations_and_Auth/` and `DevOps_and_Infrastructure/` bug-log entries
  from the PR #12 review (unrelated bugs found in the same session)

---

**Completed By:** tinomupezeni (with Claude Code)
**Duration:** ~20 minutes, alongside an in-flight hour-long deploy using the old mechanism

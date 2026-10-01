# Full Catch-Up Production Promotion (14 Commits) Triggered By A Student-Reported Content Gap

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Production promotion / incident response
**Status:** Completed — all services healthy, verified against real production data

## Context / Trigger
User reported a live production issue: admin had added Sociology topics and
papers the previous day, but students saw nothing new — "sociology topics
were added but theres nothing shared." Investigation (see
`Backend_and_API/HBEC-2026-10-01-topic-paper-additions-never-busted-subjects-cache.md`
for the full root-cause writeup) found the actual bug's fix already existed
in git (`afab7930`) but had never reached production — production was 14
commits behind `master`/staging. Given the choice between promoting just the
narrow fix, the full backlog, or only flagging the gap, the user explicitly
chose **"Full catch-up to today's HEAD"**, since the backlog also included
today's freshly-shipped feedback/content-gap resolve-pending work, the
bulk-communication feature, and the Notifications page (see
`reports/HBEC-2026-10-01-resolved-pending-bulk-communication-notifications-page.md`).

## Scope
Promoted production from `a805de28` to `f43f4711` (14 commits): the cache-bust
fix, a scheduled adopted-paper consistency check, a custom email composer,
an admin-backend `/media/` 404 fix, SEO sitemap/meta work, and today's three
resolved-pending/communication/notifications pieces.

**Explicitly out of scope:** no application code was written or changed as
part of the promotion itself — this report covers the deploy process and the
incidents it surfaced, not new feature work.

## Method
Per explicit user correction mid-session, production promotion here means
**retagging the exact already-tested staging images, never rebuilding**. The
GitHub Actions staging deploy job's own failure was a tangent investigated
briefly and abandoned once the user flagged it — it doesn't gate manual
promotion, since staging had already been manually verified earlier in the
session.

Process followed:
1. Captured running `-staging` container image digests directly (not tag
   names) and retagged them explicitly as `prod-promote-f43f4711` — this step
   itself caught and worked around a real tag collision, see
   `DevOps_and_Infrastructure/HBEC-2026-10-01-failed-ci-run-overwrote-manually-verified-image-tag.md`.
2. Ran `docker compose -f docker-compose.production.yml up -d --wait` with
   the pinned tags.
3. `notifications-backend` immediately crash-looped on a stale Alembic
   version — diagnosed and fixed live, see
   `Database_and_State/HBEC-2026-10-01-notifications-alembic-version-stuck-behind-applied-schema.md`.
4. Completed the standard post-deploy verification sequence once all
   containers were healthy.

## Decisions & Findings
- **Production deploys never rebuild — only retag already-tested staging
  images.** Explicit user correction this session; now the standing
  practice for every future promotion, not just this one.
- **A tag name is not proof of content.** The `sha-<commit>` collision found
  mid-promotion (see the DevOps entry) means any future promotion must
  verify against a running container's actual digest, not trust a tag by
  name alone — this promotion did so and avoided shipping an unverified
  build.
- **Three genuinely separate issues surfaced in one promotion**, each
  logged on its own per this repo's granularity convention (one entry per
  distinct issue, not a combined write-up): the cache-bust gap (the
  original report), the tag collision (caught during the promotion
  process), and the Alembic drift (triggered by the promotion's restart).
  None of the three shares a root cause with another.

## Changes Made
No application code changed by this promotion. Infrastructure/state changes
made directly on the production VPS:
- All 10 canonical images retagged `prod-promote-f43f4711` and deployed.
- `alembic_version` for `hbec_notifications` stamped `0004` → `0005`
  (migration `0006` then applied automatically on the next successful boot).
- `/opt/hbec/.last_good_sha` updated to `f43f4711`.
- `/opt/hbec/.PROMOTION_NOTES.txt` appended with a full promotion entry.
- `main` fast-forwarded to match `master` (`a805de28..f43f4711`) per this
  repo's own branch convention (bookkeeping only — production promotion is
  never gated on `main`).
- Pruned Docker images older than 72h on the VPS: reclaimed 17.33GB.

## Verification
- All 10 production images confirmed **bit-for-bit identical** to their
  running `-staging` counterparts by direct `docker inspect` digest
  comparison (not tag name) — `student-backend`, `student-frontend`,
  `admin-backend`, `admin-frontend`, `harness`, `harness-ml`, `notifications`,
  `student-worker`, `student-beat`, `notifications-worker` all `MATCH`.
- Full `docker ps` sweep: every production app/worker/beat container
  reports `healthy` or running cleanly (non-critical services like
  `schools-dashboard`/`payments` have no healthcheck defined but are up).
- `scripts/deploy/verify-service-links.sh` — all 10 signed service-to-service
  links OK (admin↔student, admin↔harness, admin↔schools, admin↔payments,
  student↔harness gateway+admin, student↔payments, harness→student,
  payments→student, notifications→student).
- `scripts/check_runtime_secret_drift.py --compose-file
  docker-compose.production.yml` (correct path is `/opt/hbec/scripts/`, not
  `scripts/deploy/`) — clean, 9 groups checked.
- Direct database query confirmed real Sociology rows carry real
  topic/paper counts (19 topics / 22 papers on the live production rows);
  Redis `curriculum:subjects:*` held no stale cache entries at verification
  time, so the fix's effect could not be masked by a leftover cached
  response.
- `notifications-backend`/`-worker`/`-beat` all healthy post-stamp.

## Follow-ups
- Consider hardening `cd.yml`'s staging image-tagging step so a retried/
  failed CI run cannot silently overwrite a different build under the same
  `sha-<commit>` tag (flagged in the DevOps entry, not built this session).
- Consider a periodic Alembic-drift check across services (flagged in the
  Database entry, not built this session).
- Build cache on the VPS remains large (~70GB, ~30GB reclaimable) — not
  pruned this session beyond the 72h image prune, since recent cache is
  still useful for in-flight work.

## References
- `Backend_and_API/HBEC-2026-10-01-topic-paper-additions-never-busted-subjects-cache.md`
- `DevOps_and_Infrastructure/HBEC-2026-10-01-failed-ci-run-overwrote-manually-verified-image-tag.md`
- `Database_and_State/HBEC-2026-10-01-notifications-alembic-version-stuck-behind-applied-schema.md`
- `reports/HBEC-2026-10-01-resolved-pending-bulk-communication-notifications-page.md`
- `DevOps_and_Infrastructure/HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md`

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session

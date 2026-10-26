# HBEC Blue-Green Deploy: Full Reference Guide (Real Production, Post-Cutover)

**Date:** 2026-10-26
**Project:** HBEC
**Type:** Reference Guide / Architecture Documentation
**Status:** Completed (documents a system that is live in real production)

## Summary
HBEC's VPS (`/opt/hbec`) runs a real, live blue-green deployment: two full
sets of every request-serving service, one color serving 100% of public
traffic at any time, the other built and verified in advance and promoted by
a single atomic Caddy reload. This report documents how it actually works end
to end — architecture, every guardrail script and why each exists, the exact
manual runbook (used because GitHub Actions CI is currently billing-blocked),
and the failure modes already hit and fixed — so the pattern can be set up on
another system without re-deriving it from scratch. It consolidates and
supersedes the narrower dry-run reports listed in References below: those
documented building toward this; this documents the thing as it stands today,
confirmed live.

## Context / Trigger
Asked to merge HBEC PR #112 into local master, push it, and deploy it to
production. Verifying the deploy required inspecting the real VPS state
directly (SSH), which revealed the full blue-green system already running in
production — a more advanced, more complete state than the planning
documents in the HBEC repo described (one of them still said "nothing has run
on the VPS yet"). Rather than only perform the one deploy, the user asked for
this state to be captured as a standalone, reusable guide, since the existing
knowledge was scattered across several incremental dry-run reports and a
planning doc that had gone stale relative to reality.

**Always trust the live system over a stale plan file.** This report's own
facts come from reading `/opt/hbec` on the VPS directly (`docker ps`, the
marker files, the actual compose file and scripts), not from the planning
document — which is exactly the discipline this incident illustrates.

## Scope
**In scope:** the real, currently-live blue-green topology on HBEC's
production VPS — architecture, the deploy and cutover scripts, every
guardrail they run, the Caddy mechanism, the manual-ops fallback currently in
use, known failure modes and their fixes, and a runbook for reproducing this
on a different system.

**Out of scope:** the dry-run/isolated proving work that led here (already
reported separately — see References) and the GitHub Actions CI/CD
automation path (`cd.yml`'s `deploy-color`/`cutover`/`rollback-cutover`
jobs), which is currently **not running** — GitHub Actions is billing-blocked
for this repo, confirmed via `gh run list` (nothing executed since
2026-10-05) — so production currently deploys through the manual scripts
described below, not the automated pipeline. Re-enabling that pipeline is a
separate piece of work, not covered here.

## Method
Read the real production state directly rather than trusting documentation:
`ssh` into the VPS, inspected `docker ps`, the color/sha marker files, `git
status`/`git diff` in the `/opt/hbec` checkout (to rule out undocumented
manual hotfixes), then read every script in `scripts/deploy/` in the HBEC
repo that the manual runbook actually calls, plus the relevant slice of
`docker-compose.production.yml` and `docker/caddy/`. Then performed one real
deploy-and-cutover cycle (PR #112) using the exact manual runbook, watching
it live, as the verification that this document is accurate and not
aspirational.

## Decisions & Findings — The System, As It Actually Runs

### 1. Topology: two full colors, one shared backbone
Every request-serving service exists as two containers, `<service>-blue` and
`<service>-green`, both always running:

`student-backend`, `student-frontend`, `admin-backend`, `admin-frontend`,
`harness`, `payments`, `schools-backend`, `schools-dashboard`,
`notifications` — 9 services × 2 colors = 18 containers.

**Not duplicated — shared singletons, one of each:**
- Per-pillar Celery-style workers/beats: `student-worker`/`student-beat`,
  `admin-worker`/`admin-beat`, `notifications-worker`/`notifications-beat`.
  These don't run two copies; instead they get **recreated to follow
  whichever color is live** at cutover time (see §4).
- `harness-embeddings` (GPU-bound ML worker) — same follow-the-active-color
  treatment, for the same reason: it would contend with itself for the GPU if
  duplicated.
- Everything stateful and already shared: `postgres`/`main-pgbouncer`,
  `redis`(+replica+sentinel), `harness-db` (Postgres+pgvector, its own
  image), `qdrant`, `litellm`, the monitoring stack, `gateway` (Caddy).

**One database, one Redis, shared by both colors at all times.** Neither
color gets its own copy of state — this is what makes "always both running"
affordable and is also the source of the one real constraint on migrations
(§6).

### 2. Compose structure: anchors + per-color overrides, gated by profiles
`docker-compose.production.yml` uses one `x-<service>-base`/`x-<service>-env`
YAML anchor per service (e.g. `x-harness-base`, `x-harness-env`), then two
thin blocks per service — `<service>-blue` and `<service>-green` — that
extend the anchor and override only what must differ: `container_name`,
`image:` tag (`${TAG_BLUE}` / `${TAG_GREEN}`), and any peer URL that must stay
pinned to the *same* color.

Each colored service sits behind `profiles: [color-blue]` / `[color-green]`,
so `docker compose --profile color-green up ...` only ever touches green's
containers — there is no accidental unscoped `up -d` that recreates
everything.

**Guardrail — `check-compose-colors.py`** (run in CI and before every manual
deploy): parses the compose file with PyYAML (so anchors/merges are already
resolved) and fails the build if:
1. a colored service's environment points at an **unsuffixed** hostname or at
   the **other** color (the exact class of bug that would let a blue
   container quietly call a stale `:latest` green/original container);
2. any app service is **not** profile-gated (would start on
   `${TAG:-latest}`, a tag nothing builds any more);
3. a worker/beat is not pinned to `TAG_ACTIVE`, or its peer URLs are not the
   `*_ACTIVE` ones (it must always follow whichever color is live, never a
   fixed color).

### 3. Same-color peer pinning (`color-env.sh`)
Every blue service's peer calls must go to other blue services, never green —
otherwise the two colors are not independently verifiable as coherent wholes,
and a half-blue-half-green request path becomes possible during a deploy.

`scripts/deploy/color-env.sh <live-color> [<new-color> <new-tag>]` is the
**one place** these are computed:
- Reads each color's tag from its `.sha_<color>` marker file (never defaults
  to `latest` — a missing marker is a hard error, since "fall back to the tag
  nothing is building any more" is exactly how a stale container gets started
  silently).
- Exports `TAG_BLUE`, `TAG_GREEN`, `TAG_ACTIVE` (whichever color is live) and
  the `*_ACTIVE` peer URLs (`HARNESS_SERVICE_URL_ACTIVE`,
  `STUDENT_SERVICE_URL_ACTIVE`, `STUDENT_BACKEND_URL_ACTIVE`,
  `SCHOOLS_SERVICE_URL_ACTIVE`) — these are what the shared
  workers/beats/`harness-embeddings` are pinned to, so they always call
  whichever color is currently live without needing to know which one that
  is.
- Compose's `${VAR:?}` syntax requires every one of these to be set **even
  for services in profiles that aren't being started** — so this script must
  run before any `docker compose` invocation touches the file at all, not
  just before the colors being deployed.

### 4. The follow-the-active-color singletons
Workers/beats and `harness-embeddings` are **not** blue/green pairs — there's
one of each, and at cutover time they get stopped and recreated pointed at
the newly-active color's peer URLs (via `TAG_ACTIVE` / `*_ACTIVE`, from
`color-env.sh` sourced with the **new** live color). This is a deliberate
one-time-per-cutover recreate, not a long-lived network alias — simpler to
reason about, and the brief restart is acceptable because it's a scheduled,
deliberate event, not something that happens on every deploy (only on
cutover, which is rarer than deploy).

### 5. Image tagging and identity (`record-color-sha.sh`, `verify-revisions.sh`)
- **Tags are always `sha-<7-char-short-sha>`, never `latest`, never a branch
  name.** `.sha_blue` / `.sha_green` marker files on the VPS record which
  7-char SHA each color is currently running.
- **`record-color-sha.sh`** is the *only* sanctioned writer of those marker
  files, and it refuses anything that is not exactly 7 lowercase hex
  characters. (A real incident — `HBEC-2026-10-06-sha-marker-format-
  inconsistency-broke-cutover-followers.md` — happened because a full
  40-character hash got written once; the cutover's follower handoff then
  tried to pull an image tagged with the full hash, which didn't exist,
  silently stopping every worker/beat platform-wide. This script is the fix.)
- **`verify-revisions.sh <sha> <service>...`** is the proof that a `docker
  compose up --wait` "healthy" status is not being mistaken for "running the
  new code." Every image is stamped `org.opencontainers.image.revision=<sha>`
  at build time; this script inspects every **running** container matching a
  compose service label (not by container name) and fails, naming each
  mismatch, unless every one is on the expected SHA. Also **scoped to
  `COMPOSE_PROJECT` (default `hbec`)** — a second compose project on the same
  host using identical service names (e.g. an isolated dry-run stack) was
  once matched too, false-flagging a healthy deploy as a mismatch or vice
  versa (`HBEC-2026-10-06-verify-revisions-cross-project-label-collision.md`).

### 6. Migrations: expand-then-contract is mandatory, not a guideline
Because both colors share one database, a release may only **expand** the
schema (add columns/tables) — never drop, rename, or make a column NOT NULL
— because the color *not* being deployed right now is still reading the old
shape, and a rollback would put old code back against a schema that has
already lost something it needs.

**`check-migrations.py --base <git-ref>`** (run in the manual deploy script
and in CI) inspects every migration file added since the last deployed commit
and fails on destructive operations:
- Django: `RemoveField`, `DeleteModel`, `RenameField`, `RenameModel`,
  `AlterField(null=False)`, or raw SQL containing `DROP`/`RENAME`/`SET NOT
  NULL`.
- Alembic (`upgrade()` only — `downgrade()` is allowed to drop things by
  design): `op.drop_column`, `drop_table`, `rename_table`,
  `alter_column(nullable=False)` or renamed, `op.execute` containing the same
  destructive keywords.

A migration that genuinely *is* the later "contract" step (removing something
both colors have finished migrating off) opts out explicitly, in the file:
`# contract-migration: <reason>`.

### 7. Secrets: one shared secret per signed link, never defaulted, never duplicated
Every service-to-service call is signed (HMAC-based v2 service signatures).
**`preflight-secrets.sh <env-file>`** runs before anything is built or
restarted and refuses the deploy if any of the following holds — printing
variable **names** only, never values:
1. A secret is **missing** (that link would 403 on every call — an outage,
   but at least a loud one).
2. **Two different links share one secret value** — silently lets either
   side forge the other's messages. (A real local-stack finding:
   `PAYMENTS_WEBHOOK_SECRET` once equalled `HARNESS_WEBHOOK_SECRET`, so a
   compromised harness key could forge "subscription active" webhooks.)
3. A secret still equals a **published bootstrap default**
   (`hbec-payments-internal-dev-key` and similar, which `cd.yml`'s
   first-deploy bootstrap uses and which is readable by anyone with the
   source).

The checked secrets: `REPLICATION_HMAC_KEY`, `HARNESS_WEBHOOK_SECRET`,
`PAYMENTS_WEBHOOK_SECRET`, `PAYMENTS_INTERNAL_SECRET`, `SCHOOLS_ADMIN_SECRET`.
(`HARNESS_GATEWAY_SECRET` is deliberately excluded — the student backend only
falls back to it when `HARNESS_WEBHOOK_SECRET` is unset, so requiring the two
to differ would be checking a path that normally isn't live.)

Because both colors share the same live DB and the same live users, **blue
and green must use identical signing secrets** — unlike the old
staging/production split, which could safely diverge.

### 8. Post-deploy proof that the colors can actually talk to each other
`docker compose up --wait` only proves a container is *healthy on its own*.
It does not prove the color's services can successfully call each other —
and a partial deploy (one service restarted by hand, one image that failed
to build) doesn't crash anything in a way that's visible; calls just start
403ing and features quietly stop working for users (this exact failure mode
once meant notifications silently reached nobody).

**`verify-service-links.sh <-blue|-green>`** makes one real, read-only,
fully-signed HTTP call on every documented link for that color (e.g.
admin→student, admin→harness, admin→schools, admin→payments,
student→harness gateway, student→harness learner inbox, ...), retrying a few
times to tolerate a peer that's healthy but still warming up, and fails,
naming the broken link, if any call doesn't succeed.

**`verify-retrieval-data.sh <-blue|-green>`** separately checks the color has
the data it needs to actually serve real requests (not just that it boots).

**`check_runtime_secret_drift.py`** checks the running containers' actual
environment matches the `.env` file's current secret values (catches
"the container is still holding an old secret from before a rotation").

### 9. Caddy: one atomic reload across every public domain
`docker/caddy/Caddyfile` is **generated, never hand-edited** — the comment at
its top says so, and the next cutover/rollback silently overwrites any manual
edit.

**`render-caddyfile.sh <active_color-file> [Caddyfile-path]`**:
- Reads `active_color`, regenerates every public domain's `reverse_proxy`
  target to point at that color's suffixed container
  (`hbec-student-frontend-${COLOR}:80`, etc.).
- **Caddy's gateway container bind-mounts the `docker/caddy/` *directory*,
  not the single Caddyfile.** A single-file bind mount stays pinned to the
  old inode after an in-place edit (`sed -i`, most editors rename-over), so
  the container would keep serving stale config with no visible error. A
  directory mount re-resolves the path every lookup and has no such trap.
  (First found on an isolated dry run's own Caddy —
  `HBEC-2026-10-01-single-file-bind-mount-breaks-on-in-place-edit.md`.)
- **Caddy validates the whole new config before applying any of it** — so one
  `caddy reload` is already an atomic, all-or-nothing event across all five
  public domains (student, admin, payments API, schools, schools API) at
  once. There is no window where some domains point at the new color and
  others still point at the old one.
- The retired `staging-*.hbca.tech` domains are repurposed: they always route
  to whichever color is currently **inactive** — i.e. "staging" now means
  "the thing to check before it goes live," re-pointed automatically every
  time `active_color` flips, rather than a fixed environment.
- `active_color` (and the rollback marker `.cutover_from`) are written **only
  after** the reload has already succeeded — the script that flips traffic
  never decides which color is active on its own; it only describes it.

### 10. The actual state marker files (ground truth, confirmed live on
2026-10-26)
On `/opt/hbec`:
- `active_color` — `blue` or `green`; whichever is currently serving 100% of
  public traffic.
- `.cutover_from` — the color just cut away from; written the moment traffic
  moves, **before** the slower follower-handoff step below it, so that if the
  handoff fails partway, an automatic rollback still knows unambiguously
  which color traffic is *actually* on right now and never "rolls back" onto
  the color that's already live.
- `.sha_blue` / `.sha_green` — the 7-char short SHA each color is running,
  written only by `record-color-sha.sh`.
- `.last_deployed_sha` — base commit for the next `check-migrations.py --base`
  run (first-run-on-this-checkout has no base and skips the check with a
  visible message, rather than silently passing).

## Changes Made (this session)
- No code changes. This session performed one real deploy-and-cutover cycle
  (HBEC PR #112 → `master` → VPS) using the exact manual runbook below, as
  live verification of everything documented here, and wrote this guide.

## The Manual Runbook (what production actually runs today)

**Why manual, not the automated `cd.yml` jobs:** GitHub Actions is currently
billing-blocked for this repo — confirmed via `gh run list`, nothing has
executed since 2026-10-05, despite the VPS already running real blue-green
deploys for commits well after that date. `scripts/deploy/
manual-deploy-color.sh` and `manual-cutover.sh` are explicitly written and
commented as **"manual stand-in for cd.yml's `<job>` job, for use while
GitHub Actions is billing-blocked"** — they run the exact same guardrail
scripts described above, by hand, over SSH.

### Step 1 — before touching anything, verify you won't overwrite the idle
color
The idle color can hold a different commit than you expect if someone
deployed to it and never cut over. Before deploying:
```bash
# On the VPS:
cat /opt/hbec/active_color        # which color is LIVE right now
cat /opt/hbec/.sha_blue /opt/hbec/.sha_green   # what each color is running

# From your own checkout, confirm neither SHA is ahead of what you're about
# to deploy — i.e. both are ancestors of your new history:
git merge-base --is-ancestor <sha_blue>  <your-new-branch> && echo "blue is behind, safe"
git merge-base --is-ancestor <sha_green> <your-new-branch> && echo "green is behind, safe"

# Also confirm the checkout itself has no undocumented local changes:
cd /opt/hbec && git status --porcelain && git diff --stat HEAD
```
If either SHA is **not** an ancestor of what you're deploying, stop — that
color holds work that isn't in your branch, and deploying over it will lose
it. Find out what it is before proceeding.

### Step 2 — deploy to the idle color
```bash
cd /opt/hbec
bash scripts/deploy/manual-deploy-color.sh [git-ref]   # defaults to origin/master tip
```
This builds all 10 images (9 colored services + `harness-ml`, always all 10,
every round — a partial build once left `harness-ml` missing for the exact
commit a cutover needed it at) and starts **only** the inactive color's
containers. The live color and legacy unsuffixed containers are never
touched. Ends with: `NOT yet receiving public traffic — run
manual-cutover.sh when ready.` — i.e. this step alone is already safe to run
at any time, since it never affects what users see.

Runs, in order: compose-color safety check → migration safety check →
build all 10 images (skipped if that SHA is already built locally) →
`harness-db` ensured (version-keyed, never rebuilt or restarted by a normal
deploy) → every `docker/*.override.yml` present applied → `up --wait` the
target color only → `verify-revisions.sh` → `verify-service-links.sh` →
`verify-retrieval-data.sh` → `check_runtime_secret_drift.py` →
`record-color-sha.sh` writes the new marker → old images pruned (keeps 2
newest per service).

### Step 3 — cut traffic over
```bash
bash scripts/deploy/manual-cutover.sh
```
Re-verifies the target color is healthy and on the expected SHA **again**
(trusts nothing from step 2 having stayed true), then does the one atomic
Caddy reload, writes `active_color` + `.cutover_from` immediately after the
reload succeeds (before the slower part below), then stops and recreates the
follow-the-active-color singletons (workers/beats, `harness-embeddings`)
pointed at the new live color, and verifies their revisions too.

The old color is **never stopped or torn down** — it stays exactly as it
was, as the rollback target.

### Rollback
Running `manual-cutover.sh` again (from the new live color back toward the
old one) is the rollback — it's the same script, same guardrails, just run a
second time, because the old color never stopped running.

## Known Failure Modes Already Found and Fixed (don't reintroduce these)
1. **Stale colored service pointing at an unsuffixed/wrong-color hostname.**
   Guarded by `check-compose-colors.py`. Root cause: a shared YAML anchor
   inherited by a colored block didn't get every hostname overridden.
2. **`.sha_<color>` marker holding a full 40-char hash instead of the 7-char
   short form** → cutover's follower handoff tried to pull a tag that was
   never built, silently killing every worker/beat platform-wide.
   `HBEC-2026-10-06-sha-marker-format-inconsistency-broke-cutover-followers.md`.
   Fixed by making `record-color-sha.sh` the only writer, and it refuses
   anything but exactly 7 lowercase hex characters.
3. **`verify-revisions.sh` matching containers across unrelated compose
   projects on the same host** (same service name, different project) →
   false-flagged a healthy deploy. `HBEC-2026-10-06-verify-revisions-cross-
   project-label-collision.md`. Fixed by scoping the check to
   `COMPOSE_PROJECT` (default `hbec`).
4. **Caddy single-file bind mount pinned to a stale inode after an in-place
   edit**, silently serving old routing with no error.
   `HBEC-2026-10-01-single-file-bind-mount-breaks-on-in-place-edit.md`. Fixed
   by mounting the `docker/caddy/` directory instead of the file.
5. **A deliberate per-color `docker/*.override.yml` stopgap silently stopped
   applying** the moment that color's containers were recreated under a
   plain `up`, because only the original deploy command applied it. Fixed:
   both `manual-deploy-color.sh` and `manual-cutover.sh` glob and apply every
   `docker/*.override.yml` present, on every `up` they run.
6. **A new service image missing from `image-tags.sh` and the production
   fallback build** (notifications, historically) — silently never gets
   built or pruned correctly. Any new service added to the color pair must
   be added to both places.
7. **`ReplicationLog`/attempts-counter class of bug is a reminder, not
   specific to blue-green**: any retry-count field must be read-then-
   incremented on the *same* row, never create-then-increment — unrelated to
   this system but a recurring shape worth flagging to whoever extends this
   pattern.

## Verification (this session, 2026-10-26, real production)
- `active_color` before: `blue` (`2d36aa7`, PR #108). Idle: `green`
  (`f8b738d`, PR #106). Confirmed both are strict ancestors of the commit
  being deployed (`1188c54`, PR #112) — nothing would be overwritten.
  Confirmed via `git diff --stat HEAD` in `/opt/hbec` that the checkout had
  no uncommitted tracked-file changes (only build-artifact/backup clutter in
  untracked files).
- `manual-deploy-color.sh` run against green: all 10 images built, all 9
  green services started, `verify-revisions.sh` confirmed all 9 on `1188c54`,
  `verify-service-links.sh` passed every signed link, retrieval-data and
  secret-parity checks passed. Ended: `green is now sha-1188c54 ... NOT yet
  receiving public traffic`.
- `manual-cutover.sh` run: re-verified green (revisions + service links) a
  second time before flipping, Caddy reload succeeded, `active_color` flipped
  to `green`, `.cutover_from` recorded `blue`, singleton workers/beats +
  `harness-embeddings` recreated and reverified on `1188c54`.
- Post-cutover: `active_color` = `green` confirmed on disk;
  `student.hbca.tech` and `admin.hbca.tech` both returned HTTP `200`.
- Blue (`2d36aa7`) is untouched and is the live rollback target.

## Follow-ups / Deferred
- **Re-enable GitHub Actions for this repo** so `cd.yml`'s automated
  `deploy-color`/`cutover`/`rollback-cutover` jobs resume running instead of
  the manual scripts — a billing fix on GitHub's side, outside this report's
  scope, but worth tracking since every deploy right now depends on someone
  running the manual scripts correctly by hand.
- A reusable **"set this up on a new system" checklist** (compose anchors +
  profile gating, the marker files, the guardrail script set, Caddy directory
  mount, the secrets convention) could be extracted from this report into
  its own procedural doc once a second project actually adopts the pattern —
  deferred until there's a concrete second user, so it isn't speculative.

## References
- `HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`,
  `HBEC-2026-10-01-blue-green-phase0-multi-service.md`,
  `HBEC-2026-10-01-blue-green-phase2-step1-real-secrets.md`,
  `HBEC-2026-10-01-blue-green-differing-code-version-cutover.md`,
  `HBEC-2026-10-01-blue-green-expand-contract-migration-test.md`,
  `HBEC-2026-10-01-first-real-bluegreen-cutover.md`,
  `HBEC-2026-10-15-blue-cutover-student-paper-generation-verification.md` —
  the incremental dry-run/proving work this report consolidates and
  supersedes as the current reference.
- `HBEC-2026-10-06-sha-marker-format-inconsistency-broke-cutover-followers.md`,
  `HBEC-2026-10-06-verify-revisions-cross-project-label-collision.md`,
  `HBEC-2026-10-01-single-file-bind-mount-breaks-on-in-place-edit.md` — the
  specific incident logs behind the guardrails in §5–§9 above.
- Key files (HBEC repo): `docker-compose.production.yml`,
  `docker/caddy/Caddyfile` (generated), `scripts/deploy/manual-deploy-color.sh`,
  `scripts/deploy/manual-cutover.sh`, `scripts/deploy/color-env.sh`,
  `scripts/deploy/check-compose-colors.py`, `scripts/deploy/check-migrations.py`,
  `scripts/deploy/preflight-secrets.sh`, `scripts/deploy/verify-revisions.sh`,
  `scripts/deploy/verify-service-links.sh`, `scripts/deploy/verify-retrieval-data.sh`,
  `scripts/deploy/record-color-sha.sh`, `scripts/deploy/render-caddyfile.sh`,
  `.github/workflows/cd.yml` (the automated equivalent, currently not
  running).

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~1 session, including one real production deploy+cutover as
verification

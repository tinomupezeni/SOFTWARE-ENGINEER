# First real blue-green cutover: four days of accumulated work goes live

**Date:** 2026-10-13
**Project:** HBEC Platform
**Type:** Deployment / release
**Status:** Completed

## Summary
Cut production traffic over from `blue` to `green` for the first time this
session, carrying four previously-verified-but-never-live changes: the
7-PR interactive-labs stack, a student paper-generation token-budget fix, a
notifications Redis-drift prevention pair of fixes, and a new cross-board
paper-sharing feature. Executed by hand (GitHub Actions is not currently
triggering `deploy-color`/`cutover` for this repo — a standing, separately
tracked gap), replicating `cd.yml`'s `cutover` job step for step. Verified
clean before and after; one real gap in the manual process was found and
fixed mid-cutover (see the linked DevOps entry) before it affected anything
public-facing.

## Context / Trigger
User instruction: "lets cut over, but first verify nothing is crash
looping then we cut over then verify again stability." Explicit three-step
request — pre-check, execute, post-check — followed exactly.

## Scope
Included: the full cutover sequence (pre-flight revision/link verification,
Caddy flip, `active_color`/`.cutover_from` bookkeeping, singleton
worker/beat/embeddings handoff), plus stability verification before and
after.

Excluded: any new code changes (this was a pure deployment action on
already-merged, already-reviewed work); rollback (not needed — nothing
failed badly enough to warrant it).

## Method
Read `cd.yml`'s `cutover` job in full before touching anything, rather than
improvising from memory of the earlier `deploy-color` replications — the
two jobs differ in important ways (Caddy flip, `active_color`/
`.cutover_from` ordering, the singleton-follower stop-then-start sequence)
that aren't interchangeable.

## Decisions & Findings

### Pre-cutover: zero crash loops, two real-but-orthogonal issues found
`RestartCount` checked across every `hbec-*` container — zero anywhere,
confirming no crash loops. Log sweep on both colors turned up two unrelated,
active issues (full writeups: `HBEC-2026-10-13-gemini-timing-out-both-key-
tiers.md`, and the `NoneType` crash noted inside it) — both flagged to the
user explicitly as *not* blocking the cutover decision, since `litellm` is
a shared singleton serving both colors identically; cutting over neither
causes nor fixes either.

### The cutover itself, step for step
1. Re-verified the gate (`verify-revisions.sh`, `verify-service-links.sh`)
   against green immediately before flipping — not trusting the earlier
   deploy-time verification, since a container could have been restarted
   by hand since then (exactly the principle the real job's own comments
   state).
2. `render-caddyfile.sh` with a staged `active_color_candidate` file,
   confirmed the reload succeeded, **then** wrote the real `active_color`
   and `.cutover_from` markers — never the reverse, matching the real
   job's documented reasoning (a failure between those two steps must
   never leave `active_color` claiming a color that isn't actually live).
3. Singleton followers (`student-worker`/`-beat`, `admin-worker`/`-beat`,
   `notifications-worker`/`-beat`, `harness-embeddings`) stopped then
   recreated on the new color's tag.

### Found and fixed mid-cutover: the follower handoff needs all 10 images, not 9
Step 3 failed partway: `harness-embeddings`' image
(`hbec-harness-ml:sha-9ae1402`) had never been built locally across any of
today's three earlier manual `deploy-color` replications — only the 9
color-paired service images were built each time, since those were the
only ones this session's own changes touched. `docker compose up` on a
multi-service invocation evaluates every named service before starting
any, so the one missing image aborted the whole batch **after** it had
already stopped the other six (already-successfully-resolved) followers.
Caught within the same minute via the post-cutover restart-count check
and the `verify-revisions.sh` gate; fixed by building the missing image
(`Dockerfile.ml`) and re-running the follower `up` in two parts. Full
writeup, including the underlying gap (manual replication of an automated
job can "forget" one of several interchangeable steps a single script
cannot): `HBEC-2026-10-13-manual-deploy-missed-harness-embeddings-image-
build.md`.

Zero public-facing impact — the gap was entirely in background
worker/beat/embeddings containers, never in anything serving `student.
hbca.tech`/`admin.hbca.tech`/etc, and `harness-embeddings`' own code
hadn't changed today regardless.

## Changes Made
- `/opt/hbec/active_color`: `blue` → `green`.
- `/opt/hbec/.cutover_from`: written as `blue`.
- Caddy reloaded; all five public domains now route to green's containers.
- All 9 color-paired services + 7 singleton followers confirmed on
  `sha-9ae1402`.
- `hbec-harness-ml:sha-9ae1402` built and `harness-embeddings` recreated
  on it (the one image this session's manual replications had been
  missing).

## Verification
- Zero `RestartCount` on any container, before and after.
- `verify-revisions.sh`: all 16 services (9 color-paired + 7 followers) on
  `sha-9ae1402`.
- `verify-service-links.sh -green`: every signed service-to-service link
  OK.
- `check_runtime_secret_drift.py`: 12 groups checked, clean (the three new
  `REDIS_URL` groups from today's earlier notifications fix, now actually
  exercised against the live color for the first time).
- All five public domains (`student`, `admin`, `api`, `school`,
  `school-api` excepted — pre-existing DNS gap, unrelated) returning `200`
  throughout and after.
- Log sweep on every now-live service and every follower: clean, no new
  errors since the flip (the two pre-existing issues noted above are
  unchanged by the cutover, confirmed present on both colors before it).
- Error tracker: zero new entries since the cutover timestamp.
- Blue confirmed untouched throughout — still running, still the
  verified rollback target, per the blue-green design's own guarantee.

## Follow-ups / Deferred
- GitHub Actions not triggering `deploy-color`/`cutover` for this repo —
  the root cause of why every deploy and this cutover were done by hand
  today. Still not investigated; flagged repeatedly across today's reports.
- The Gemini-timeout and `analytics/engine.py` `NoneType` issues — both
  logged separately, neither resolved yet.
- Image-tags preflight for manual replications — proposed in the linked
  DevOps entry, not yet built.

## References
- `.github/workflows/cd.yml` (`cutover` job — the process replicated here)
- `HBEC-2026-10-13-manual-deploy-missed-harness-embeddings-image-build.md`
- `HBEC-2026-10-13-gemini-timing-out-both-key-tiers.md`
- `HBEC-2026-10-12-labs-stack-review-merge-deploy.md` (first flagged the
  GitHub Actions gap)

---

**Completed By:** Tinotenda Mupezeni
**Duration:** ~25 minutes (cutover itself ~10 minutes; the mid-cutover
fix and full before/after verification the remainder)

# Seven-PR "labs" stack reviewed against the Code Review guide, merged locally, deployed to the idle blue-green color

**Date:** 2026-10-12
**Project:** HBEC Platform
**Type:** Code review + merge + deployment
**Status:** Completed

## Summary
Seven open PRs (#88-#94), a stacked series building six interactive physics
labs (hydraulic brakes, converging lens, sound, liquid pressure) across the
Workbench simulation / 3D VISUALS model / in-lesson-interactive triad, were
each reviewed against engineering guide 24 (Code Review) before merge, merged
locally into `master` in dependency order, verified with the full local test
suite, pushed, and deployed to the idle (`green`) blue-green color on
production — verified healthy and link-tested, carrying zero public traffic
pending a deliberate `cutover`.

## Context / Trigger
User request: "we have 7 open PRs for HBCA, lets take them run them against
the code review guide n merge on local." Guide 24 ("Code Review") existed in
the SOFTWARE-ENGINEER guide library but had never been entered in
`MANIFEST.md` — added to the manifest first (separate small change, committed
ahead of this work) so it isn't missed again.

## Scope
Included: reviewing and merging PRs #88-#94 on the HBEC repo, running the
affected test suites, pushing to `master`, and deploying the result to the
VPS's idle blue-green color.

Excluded: the `cutover` action (flipping public traffic to green) — not
requested, and this report's "Changes Made" section is explicit that green
is deployed-but-inactive.

## Method
- Determined the PRs' *true* git ancestry (not their GitHub-displayed `base`
  field, which was stale/misleading for #90 and #91): #88 is independent;
  #89→90→91→92→93→94 is one linear stack. Verified via
  `git merge-base --is-ancestor` pairwise.
- Reviewed each PR's own incremental diff (not the cumulative stack) in a
  separate parallel fork per PR, each instructed to apply guide 24's review
  framework plus the relevant HBEC CLAUDE.md sections (3D visual families,
  interactive learning, pillar isolation) — each fork verified claims against
  the actual diff rather than trusting the PR description (phantom-changes
  check per guide 24 §13), independently re-derived the physics by hand, and
  specifically checked harness/FE parameter-validation parity on every
  in-lesson interactive (the class of bug that would let the server and
  client disagree on a correct answer).
- Merged locally in dependency order (`git merge --no-ff`), resolving
  conflicts as they arose rather than batching.
- Ran the full affected local test suites after every merge that touched
  generated artifacts, not just at the end.
- Deployed to the VPS's idle color by hand-replicating `cd.yml`'s
  `deploy-color` job (GitHub Actions is not currently triggering workflow
  runs for this repo — confirmed via `gh api .../actions/runs`, no run exists
  for the pushed commit), since the automated pipeline wasn't available.

## Decisions & Findings

### Review (all 7 PRs)
| PR | Verdict |
|----|---------|
| #88 docs catalogue | APPROVE |
| #89 hydraulic brake | APPROVE |
| #90 converging lens | APPROVE |
| #91 brake 3D + interactive | APPROVE WITH NITS (non-blocking float-equality fragility in a bounded-range check) |
| #92 lens 3D + interactive | APPROVE |
| #93 sound | APPROVE |
| #94 liquid pressure | APPROVE |

No migrations anywhere in the stack (confirmed by diffing for
`*/alembic/versions/*` and `*/migrations/*` across every PR) — the user's
"be guided by the blue-green runbook, especially on the DB part on
expand/contract" instruction therefore had nothing to apply to.

### Merge conflicts — a real, recurring class, not noise
Every merge from #91 onward conflicted on the same five generated-artifact
paths: `AGENTIC_HARNESS/app/shared/data/visual_catalog.json`,
`STUDENT/Frontend/public/axon/catalog.json` + a content-hashed JS chunk
(rename/rename conflict each time), `STUDENT/Frontend/src/features/
interactive-learning/data/kit.generated.ts`, `VISUALS/public/visuals/
catalog.json`, and `VISUALS/src/data/topics.js`. The last one was not a
generated-artifact collision but a genuine content conflict: `master` had
independently gained a `sections` topic (from already-merged work) that the
PR branches, forked earlier, didn't know about, while each PR branch added
its own new topic (`hydraulics`, then `lenses`, then `sound`, then
`liquidPressure`) that `master` didn't know about. Taking either side whole
would have silently dropped the other's topic from the registry.

**Resolution, repeated identically at each step** (matching PR #92's own
documented guidance for exactly this conflict class): union `topics.js`'s
array by hand (keep both the existing and incoming topic), take a
placeholder side for the purely-generated files, then regenerate for real via
`npm run build:kit && npm run sync:hbec` in `VISUALS/` so the merged catalog
reflects every topic from both sides. Verified after each regeneration with
`npm run check` — every run showed only the same 4 pre-existing "blurb too
thin" vector-model warnings every PR's own description had already disclosed
as present on `master`, confirming the resolution introduced nothing new.

### GitHub didn't auto-detect #92-94 as merged
PRs #88-91 were auto-marked "Merged" by GitHub once pushed (their merge
commits reproduced an identical diff/patch-id). #92-94 required real
conflict-resolution commits (the `topics.js` union + catalog regeneration),
which changed the diff shape enough that GitHub's merge-detection didn't
recognize it. Verified the content was genuinely merged via
`git merge-base --is-ancestor origin/<branch> origin/master` (true for all
three) before closing them explicitly via `gh pr close` with a comment
pointing to the actual merge commit and this reasoning.

### GitHub Actions isn't running for this repo currently
`gh api repos/Rest-creator/HBEC/actions/runs` showed no workflow run at all
for the pushed commit (the most recent runs were from 2026-10-05). This is a
standing gap, not something this session caused — flagged to the user, who
directed a manual deploy instead of investigating/fixing CI in the moment.

### Manual deploy-color replication
With CI not running, `deploy-color`'s steps were replicated by hand against
the real `/opt/hbec`:
- **VPS repo ownership was inconsistent** (`root`, `ubuntu`, `winstontino`
  mixed across the tree — a side effect of earlier sessions' sudo-based file
  copies, including this session's own Gemini-key-rotation config deploy
  earlier today). A plain `git pull` as the actual SSH user (`winstontino`,
  confirmed via `whoami`/`id` — not `ubuntu` as assumed from file ownership)
  failed on permission-denied for every path owned by a different user. Fixed
  by normalizing the whole tree to `winstontino:winstontino` (the user
  actually running deploys in this session, already in `sudo`+`docker`
  groups) before retrying. **Three already-dirty tracked files on the VPS
  (`litellm_config.yaml`, `docker-compose.production.yml`, the deleted
  `redis-failover` override) were confirmed byte-identical to what `master`
  already carried** (via `git diff origin/master -- <path>`) before being
  reset — they were this session's own earlier hand-copied changes, now
  properly captured in git history.
- Sourced `scripts/deploy/color-env.sh blue green sha-b1525d4` to get
  `TAG_GREEN`/`TAG_ACTIVE` right without touching blue's tag.
- Ran `preflight-secrets.sh` and `check-compose-colors.py` before building —
  both passed.
- Built all 9 color-paired service images at `sha-b1525d4` (the two the diff
  actually touches, `student-frontend` and `harness`, plus the 7 unrelated
  ones every color must move together — `student-backend`, `admin-backend`,
  `admin-frontend`, `payments`, `schools-backend`, `schools-dashboard`,
  `notifications-backend`). The unrelated 7 built in under a second each via
  Docker layer cache, confirming nothing in them actually changed.
- `docker compose --profile color-green up -d --wait --no-deps <9 services>`
  — all 9 recreated and reported healthy.
- `verify-revisions.sh`: all 9 confirmed on `b1525d4`.
- `verify-service-links.sh -green`: every signed link OK, including
  `student -> harness visuals` (the endpoint these labs actually exercise).
- `check_runtime_secret_drift.py`: OK, 9 groups checked.
- Wrote `.sha_green`, pruned old image tags (nothing to prune, <=5 present).

## Changes Made
- HBEC `master`: 7 merge commits (`d9992926`...`b1525d44`), each citing its
  guide-24 review verdict in the commit message.
- `/opt/hbec` on `hbca-vps`: pulled to `b1525d44`; `green` color's 9 services
  rebuilt and recreated at `sha-b1525d4`; `.sha_green` updated. `blue` (live,
  serving all public traffic) was never touched — confirmed by its
  containers' unchanged uptimes and `student.hbca.tech`/`admin.hbca.tech`/
  `api.hbca.tech` all returning `200` throughout.
- GitHub: PRs #88-91 auto-closed as merged by the push; #92-94 closed
  explicitly with a comment explaining why auto-detection missed them.
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/MANIFEST.md`:
  added the missing guide-24 entry (separate prior commit, same session).

## Verification
- Harness: `pytest tests/interactive tests/interactive_learning tests/shared
  -q -p no:schemathesis` — 1970 passed, 1 skipped.
- Student frontend: `npm run typecheck` — clean (zero errors, full strict
  mode). `vitest run` on the touched workbench/interactive-notes/
  interactive-learning paths — 324 passed across 24 files.
- VISUALS: `npm run check` after every merge — only the 4 known pre-existing
  failures, confirmed via diff that they predate this stack.
- Production deploy verified per the real pipeline's own gates (revision,
  signed links, secret drift), not just "containers are running."

## Follow-ups / Deferred
- **GitHub Actions not triggering for this repo** — a real gap, not
  investigated further in this session (deploy was done manually by explicit
  user direction). Worth a dedicated look: billing, workflow triggers, or
  something else entirely.
- **Cutover not performed** — green is deployed and verified but inactive.
  Flipping public traffic to it is a separate, deliberate action for the
  user to trigger when ready.
- **VPS repo ownership drift** — normalized to `winstontino` for this
  deploy, but the underlying cause (different sessions/tools writing as
  different users via `sudo`) will recur. Worth a standing rule: always
  `chown` back to the deploy user after any `sudo`-based file write to
  `/opt/hbec`, or avoid `sudo` for file writes there when the owning user
  already has write access.

## References
- Guide 24 (Code Review), `SOFTWARE-ENGINEER/Principal_Engineer/
  engineering-guides/24. Code Review.md`
- HBEC PRs #88-#94 (closed/merged)
- HBEC `CLAUDE.md` — "3D visual families", "Interactive learning" sections
  (the standing rules each review was checked against)
- `.github/workflows/cd.yml` (`deploy-color` job — the pipeline replicated
  by hand here)

---

**Completed By:** Tinotenda Mupezeni
**Duration:** ~2 hours (parallel review ~5 min wall-clock; merge conflict
resolution and verification the majority of the time)

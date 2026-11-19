# Ship LEC-091/092: review, merge, production deploy, rollout seed, QA handoff

**Date:** 2026-11-19
**Project:** LEC Biotec
**Type:** Release / Deployment
**Status:** Completed

## Summary
Reviewed, merged and deployed two stacked feature PRs — LEC-091 (product
discovery: catalogue search/category browser, partner logo strip, Services
hub, light hero) and LEC-092 (News & Articles, published from the admin) —
to production, ran their post-deploy seed commands, and handed off
interface-facing verification to QA via ProjectFlow tasks assigned to
mutepfamutsa@gmail.com.

## Context / Trigger
User asked to code-review PRs #62 and #63, merge to `main` if clean, then
separately asked to find and run the deployment script, and create
ProjectFlow QA tickets with test steps for the UI-reliant parts of the
update, assigned to a named teammate.

## Scope
Included: `/code-review` of both diffs, merging to `main`, running
`deploy.sh` against the production VPS, running `manage.py seed_website`
and `manage.py seed_news` (dry run then `--apply`), and authoring/assigning
ProjectFlow QA tasks.

Excluded: writing the first News article content, confirming the partner
logo list (explicitly deferred in PR #62's own "Not in this PR" section),
and any code changes beyond the corrective re-merge described below.

## Method
- Code review via the `/code-review` skill (forked background agent) on
  both diffs before merging.
- CI-gate check (`gh pr checks`) required green before every merge,
  including the corrective PR.
- After deploy, verified the *actual* deployed commands existed
  (`manage.py help`) rather than assuming the merge had reached the running
  image — this is what surfaced the stacked-PR merge bug (see bug-log entry
  below).
- Rollout commands run dry-run first, output inspected against the PR's own
  stated expectations (pages/sections it said it would create), then
  `--apply`.

## Decisions & Findings
- Code review of #62/#63 found no high-confidence correctness bugs; several
  candidate issues were investigated and ruled out as intentional (ADR-018
  menu rule, autoplay/pause behavior, article-list slug dedup).
- **Found and fixed:** PR #63 had been merged into its feature base
  (`winston/LEC-091-website-discovery`) instead of `main`, despite its own
  body instructing a base-branch switch first. Full root cause and
  guardrail recorded separately:
  `DevOps_and_Infrastructure/LEC-2026-11-19-stacked-pr-merged-into-wrong-base.md`.
- `deploy.sh` builds from the local git working tree, not from GitHub —
  this meant the first deploy attempt shipped stale code even after #62 was
  correctly on `main`, because the local checkout hadn't been pulled. Fixed
  by `git pull origin main` before rebuilding.

## Changes Made
- Merged PR #62 (LEC-091) and PR #63 (LEC-092, originally to the wrong base)
  into `main`.
- Opened and merged PR #64, re-targeting #63's diff onto `main` with no
  code changes (carried the already-reviewed commits forward).
- Deployed `main` (commit `5924348`) to the production VPS via `deploy.sh`.
- Ran `manage.py seed_website --apply` on production: created the Services
  hub (`/p/services`) and four category pages (Laboratories, Chemicals,
  Plasticware, Glassware), added `product_grid`/`logo_strip` sections to
  home/about, republished `about`, `home`, `products`, `sectors`, `stem`.
- Ran `manage.py seed_news --apply` on production: created `/p/news` with
  an `article_list` section, added a News link to the Resources menu.
- Created 7 QA tasks in ProjectFlow (project **LEC BIOTEC**) covering every
  interface-dependent area of both features, each with step-by-step manual
  test instructions, all assigned to mutepfamutsa@gmail.com.

## Verification
- CI green on #62, #63 and the corrective #64 (API, Verify, E2E, CI
  success) before each merge.
- Post-deploy: `manage.py help` on the production container confirmed
  `seed_website`/`seed_news` subcommands present after the corrected
  redeploy (absent before — this was the signal that caught the mis-merge).
- Dry-run output of both seed commands matched the pages/sections each PR's
  body said it would install, before applying.
- All target containers (postgres, redis, migrate, worker, beat, api, web)
  reported healthy/started after the final deploy.

## Follow-ups / Deferred
- Partner logos still need the confirmed partner list before the logo
  strip shows anything real (per PR #62).
- First News article content not written — deferred to admin/editorial,
  covered by QA task "Admin — create & publish a News article."
- QA sign-off from mutepfamutsa@gmail.com on the 7 assigned ProjectFlow
  tasks is outstanding.

## References
- PRs: #62, #63, #64 (github.com/winstonjthinker/lec-biotech-ascend)
- Bug log: `DevOps_and_Infrastructure/LEC-2026-11-19-stacked-pr-merged-into-wrong-base.md`
- `docs/decisions/ADR-018-published-categories-are-browsable-before-stock.md`
- `docs/decisions/ADR-019-articles-are-pages-with-an-article-section.md`
- ProjectFlow project: LEC BIOTEC (`db926df1-0ea9-45f6-a4d5-00553d9e1912`)

---

**Completed By:** Claude Code (session for tinotendamupezeni@thuthuka.tech)
**Duration:** ~1 hour

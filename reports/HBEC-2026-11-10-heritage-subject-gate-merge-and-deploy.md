# Merge and production deploy of PR #120 (heritage subject-gate fix)

**Date:** 2026-11-10
**Project:** HBEC
**Type:** Merge + production deploy (manual blue-green runbook)
**Status:** Completed

## Summary
Merged open PR #120 ("Heritage: a monument reaches only the subjects it
names, from a window wide enough to find it") into local and origin
`master`, then deployed it to production using HBEC's manual blue-green
runbook, since GitHub Actions is currently disabled on the repo (billing).
The deploy surfaced an unrelated, pre-existing dependency bug that broke
Celery workers on rebuild; that bug is root-caused and fixed in its own
log entry (see References) and the fix was deployed in a second cutover in
the same session. Production is now live on `aa5fa03c9` with heritage
retrieval fixed and all services, including background workers, verified
healthy.

## Context / Trigger
User asked to check production's running version and open PRs, then
merge PR #120 locally and specifically check the heritage data seeding
side of it, then push and run the deployment runbook.

## Scope
- Merge PR #120 into `master` (included).
- Verify the heritage corpus/seeding claims the PR makes, against the
  actual corpus file and seeding code (included).
- Run local tests covering the change (included).
- Push to `origin/master` and deploy to production via the documented
  manual blue-green path (included, since CI/CD workflows are disabled).
- PR #119 ("17 new Workbench labs") — reviewed only to confirm PR #120's
  base branch (`experimental`) already contained it; not separately merged
  or deployed as its own action in this session (excluded — came along as
  part of #120's branch history, not independently evaluated here).

## Method
1. SSH'd into the VPS to read `active_color`, `.sha_blue`/`.sha_green`, and
   `docker ps` to establish ground truth on what was actually live, rather
   than trusting any doc.
2. Used `gh pr list` / `gh pr view` to read the two open PRs' descriptions
   and diff scope before merging.
3. Fetched PR #120 as a local branch (`pull/120/head`), merged with
   `--no-ff` into `master`, ran the test suites the PR's own description
   named as covering the change, and separately independently verified the
   corpus-level claims (entry counts, `place`-kind count, the gate/window
   constants) directly against the JSON data file and `heritage.py`, rather
   than only trusting the PR's own numbers.
4. Found `cd.yml`/`ci.yml`/`security-scan.yaml` all `disabled_manually` via
   `gh api .../actions/workflows` before assuming anything would trigger
   from the push.
5. Used the project's documented manual-deploy-color.sh /
   manual-cutover.sh scripts (the repo's own stand-in for the disabled
   `cd.yml` jobs), reading each script's header before running it.
6. Confirmed cutover health via each script's own built-in verification
   (`verify-revisions.sh`, `verify-service-links.sh`,
   `verify-retrieval-data.sh`) rather than a separate manual check.

## Decisions & Findings
- **Blue-green state going in:** production (`blue`) was on `7b8b38a`;
  `green` had a stale, never-cutover build at `4a10d5d`.
- **PR #120 was heritage-correctness work, not scope creep:** it fixed a
  subject-matching gate that let 58-84 of 92 monument entries reach every
  subject regardless of relevance, and a search window (8) too narrow to
  surface the right monument once scores flattened (measured: right entry
  often sat at position 9-16). Verified independently: the merged
  `heritage_corpus.json` has 143 entries, 28 of kind `place` (matches the
  PR's own count); `heritage.py` contains `teaches_subject`/`also_teaches`
  gating and `_SEARCH_WINDOW = 32` as described.
  - Root cause write-up: this part of the audit was done directly from
    reading `app/shared/heritage.py` and the data file, not re-derived from
    scratch — the PR description's own measured numbers (31/32 probes
    correct) were treated as a claim to spot-check, not as ground truth on
    their own.
- **Seeding is automatic, not a manual step:** `heritage_seed.py`'s
  `ensure_heritage_seeded()` hashes the corpus file and reseeds Qdrant on
  harness startup only when the digest changes (Redis-cached, one-worker
  lock) — so merging and deploying this PR requires no separate seed run.
  Confirmed live: the deploy's own `verify-retrieval-data.sh` reported
  `heritage_knowledge: 143 points` on both cutovers.
- **GitHub Actions is billing-blocked**, not merely quiet: all three
  workflows show `state: "disabled_manually"` via the Actions API. The push
  to `master` triggered nothing. Decision (user-approved): deploy manually
  via the documented runbook rather than wait on billing.
- **A clean web cutover does not guarantee a clean worker cutover.** The
  first cutover (green, `437d14c`) flipped traffic fine but the singleton
  worker/beat follower handoff failed on an unrelated, pre-existing
  dependency conflict (full root cause in the linked bug-log entry). This
  was diagnosed and fixed forward with a second deploy+cutover cycle in the
  same session rather than left broken or silently rolled back onto a
  color that would have had the same issue anyway.

## Changes Made
- `437d14c67e6b30d8e18d7a60b610009f784061fb` — merge commit for PR #120
  into `master` (92 files; the heritage gate/window fix plus the Workbench
  labs and curriculum-map/paper-lookup work already on its `experimental`
  base branch).
- `aa5fa03c9` — `fix(deps): raise redis-py ceiling so celery workers
  survive a rebuild` (`STUDENT/hbec_backend/requirements.txt`,
  `ADMIN/adminBackend/requirements/base.txt`).
- Both pushed to `origin/master`.
- Production deployed twice in sequence via the manual runbook:
  `blue (7b8b38a) -> green (437d14c)` [web cutover clean, worker handoff
  failed] -> `green (437d14c) -> blue (aa5fa03c9)` [full clean cutover,
  including all 7 worker/beat/embeddings singletons verified healthy].

## Verification
- Local: `tests/shared/test_heritage_monuments.py`,
  `tests/shared/test_experiment_subjects.py` (41 passed);
  `tests/exam_practice/test_generated_paper_subject_fit.py`,
  `tests/shared/test_workbench.py`, `tests/shared/test_workbench_fit.py`,
  `tests/test_isolation.py` (142 passed) — 183 total, all green, inside the
  harness's own `.venv` per project convention.
- Production, first cutover: all 10 colored app services verified on-SHA
  and healthy; all 10 signed service-to-service links verified; heritage
  retrieval data verified present (143 points).
- Production, second cutover (post dependency fix): same 10 app-service
  checks, plus all 7 singleton workers/beats/embeddings verified on-SHA and
  healthy (`student-worker`, `student-beat`, `admin-worker`, `admin-beat`,
  `notifications-worker`, `notifications-beat`, `harness-embeddings`).
- Live smoke check: `https://hbca.tech/` and `/api/health/live/` both
  returned `200` after the final cutover.

## Follow-ups / Deferred
- PR #119 was not independently reviewed or merged as its own action in
  this session (its commits arrived as part of #120's branch ancestry).
  Still open on GitHub as its own PR; worth closing or rebasing once
  someone checks whether it is now fully subsumed by what's on `master`.
- The lock-file guardrail for `STUDENT/hbec_backend` and
  `ADMIN/adminBackend` (named in the linked bug-log entry) is not yet
  implemented — this session fixed the immediate pin, not the systemic
  gap that let it happen.
- GitHub Actions billing is still unresolved; every deploy until then needs
  the manual runbook.

## References
- Bug-log entry for the dependency break found during this deploy:
  `DevOps_and_Infrastructure/HBEC-2026-11-10-redis-py-ceiling-broke-celery-workers.md`
- PR #120: https://github.com/Rest-creator/HBEC/pull/120
- `AGENTIC_HARNESS/app/shared/heritage.py`,
  `AGENTIC_HARNESS/app/shared/heritage_seed.py`,
  `AGENTIC_HARNESS/app/shared/data/heritage_corpus.json`
- `scripts/deploy/manual-deploy-color.sh`, `scripts/deploy/manual-cutover.sh`
- HBEC root `CLAUDE.md` — "Blue-green deploy", "Docker Images (GHCR)"

---

**Completed By:** Tinotenda Mupezeni (with Claude Code)
**Duration:** ~1 hour (PR review through verified second cutover)

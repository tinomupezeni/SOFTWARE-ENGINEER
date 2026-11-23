# HBEC `master` Promotion and Green Deploy (not yet live)

**Date:** 2026-11-23
**Project:** HBEC
**Type:** Audit / Deployment
**Status:** In Progress (deliberately paused before cutover)

## Summary
Promoted `master` to the tip of `experimental` (fast-forward, the 8 PRs merged earlier this session), then ran `scripts/deploy/manual-deploy-color.sh` against the inactive color (green) on `hbca-vps`, per `docs/BLUE_GREEN_CUTOVER_RUNBOOK.md` (GitHub Actions remains billing-blocked). The deploy succeeded at every automated gate. Cutover was deliberately **not** run — the runbook's manual pre-cutover verification step requires a human to sign into staging through a dedicated debug Chrome session with a real test account, which cannot be done by an agent. Blue remains live, unaffected.

## Context / Trigger
Following the PR review and merge session earlier today (`reports/HBEC-2026-11-23-pr-168-to-176-review-batch.md`, `reports/HBEC-2026-11-23-pr-168-to-175-merged-to-experimental.md`), the user asked to find the deployment runbook and deploy the merged work to the inactive color.

## Scope
**In scope:** locating the current runbook, promoting `master`, running the automated inactive-color deploy, verifying its automated checks.
**Out of scope (by design, not oversight):** `manual-cutover.sh` (going live) — deferred pending the manual staging verification step; `manual-rollback-cutover.sh` — not needed, nothing is live yet to roll back.

## Method
1. Located the current runbook: `docs/BLUE_GREEN_CUTOVER_RUNBOOK.md` (confirmed current and authoritative over the older `docs/STAGING_TO_PRODUCTION_RUNBOOK.md`, which `CLAUDE.md` itself flags as describing a pipeline that "no longer exists").
2. Confirmed `origin/master..origin/experimental` was a clean fast-forward (0 commits on `master` not in `experimental`) before promoting — never force-pushed, never rebased.
3. Confirmed GitHub Actions is still non-functional on `master` (`gh run list` — same billing-blocked state since 2026-10-05, consistent with Project Memory).
4. SSH'd to `hbca-vps`, confirmed active color (`blue`) and disk headroom — initially checked the wrong filesystem (`/`, 219GB, 36GB free) before the user caught that Docker's actual data root is `/sdb-disk` (916GB, 446GB free); corrected and confirmed real headroom was never a concern.
5. Ran `scripts/deploy/manual-deploy-color.sh` (no arguments — defaults to `origin/master` tip) as `winstontino` from `/opt/hbec`, per the script's own header (fetch as the invoking user, root only where the working tree/Docker need it).

## Decisions & Findings

### `master` promotion
```
git push origin origin/experimental:master
# b66d1ba0d..cd70a053e  origin/experimental -> master
```
Clean fast-forward, no conflicts, no force-push.

### Deploy to green — every automated gate passed
- All 10 images built (including `harness-ml`'s large CUDA/torch stack, the longest single step at ~11 minutes).
- All 10 green containers reported `Healthy`.
- `verify-revisions.sh`: all 10 services confirmed on `sha-cd70a05`.
- `verify-service-links.sh`: every signed service-to-service link verified (admin↔student, admin↔harness, admin↔schools, admin↔payments, student↔harness ×3, student↔payments, harness↔student, payments↔student, notifications↔student, schools↔student).
- `verify-retrieval-data.sh`: required curated collection present (`heritage_knowledge`, 143 points).
- `check_runtime_secret_drift.py`: OK, 12 groups checked.
- `.sha_green` recorded as `cd70a05`; old sha-tagged images pruned (kept newest 2 per service).
- Script exited 0: `"green is now sha-cd70a05... NOT yet receiving public traffic - run manual-cutover.sh when ready."`

### Why cutover was not run
The runbook's own "Now actually test it" step requires a human-operated Chrome with `--remote-debugging-port=9222` signed into a **real test account** on `staging-student.hbca.tech`, because `tests/uatt`'s `deployed` Playwright project connects to that session over CDP rather than launching its own browser or handling a password — a deliberate design choice (per the project's own config comment) so a flaky automated pass can never wave a release through. An agent has no test account credentials and should not sign into a real student/admin account to fabricate this step. Asked the user how to proceed; they chose to stop here rather than skip the check or run it themselves in this session.

## Changes Made
- `master` fast-forwarded to `cd70a053e` on `Rest-creator/HBEC` (GitHub).
- `green` color on `hbca-vps` rebuilt and verified at `sha-cd70a05` (not live).
- No cutover; `blue` (live, `sha-4b4d5ae`) untouched.
- `Project_Memory/HBEC/MAIN.md` updated: live-artifact table, a new dated current-state entry describing exactly what's deployed-but-not-live and what the next session needs to do.

## Verification
- `mergeStateStatus`/fast-forward confirmed via `git log` before pushing.
- Every automated check above is the script's own output, captured in full in the session transcript — not re-derived or assumed.
- Staging health endpoints manually curled post-deploy (`staging-student.hbca.tech/health/live/`, `staging-admin.hbca.tech/health/live/`) — both `200`, confirming the inactive color is actually reachable through its real domain, not just healthy in isolation.
- Did **not** fabricate or skip the human-verification step; explicitly surfaced the blocker rather than proceeding past it.

## Follow-ups / Deferred
- **Next step for whoever picks this up:** open a debug Chrome (`chrome --remote-debugging-port=9222 --user-data-dir=<dedicated profile> https://staging-student.hbca.tech/`), sign in with a real test account, exercise the features from today's 8 merged PRs specifically (PyMuPDF-based syllabus parsing, the picture kit's girl/boy/child fix, pie chart/histogram/construction/Zimbabwe-map diagrams, hand-drawn whiteboard figures, the restored `hallucination.py` guardrail), then run `cd tests/uatt && DEPLOYED_URL=https://staging-student.hbca.tech npm run test:deployed`. All six deployed checks must pass before cutover.
- Once that passes: `bash scripts/deploy/manual-cutover.sh` on `hbca-vps`, then bake/watch before considering `blue` disposable, per the runbook's own Section 3.
- PR #176 (admin PyMuPDF removal) remains open/draft and is not part of this deploy — its self-disclosed regressions are still unresolved.

## References
- `docs/BLUE_GREEN_CUTOVER_RUNBOOK.md`
- `reports/HBEC-2026-11-23-pr-168-to-176-review-batch.md`
- `reports/HBEC-2026-11-23-pr-168-to-175-merged-to-experimental.md`
- `Project_Memory/HBEC/MAIN.md`

---

**Completed By:** Claude Sonnet 5
**Duration:** ~35 minutes (mostly image build wall-clock time)

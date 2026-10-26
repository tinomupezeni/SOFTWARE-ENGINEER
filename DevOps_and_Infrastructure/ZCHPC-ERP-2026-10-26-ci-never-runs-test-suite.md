# CI pipeline never runs the test suite (pytest is not invoked anywhere)

**Date:** 2026-10-26
**Project:** ZCHPC-ERP
**Environment:** CI (GitHub Actions) / all environments by extension
**Severity:** High
**Status:** Investigating (found during code review of PR #118, not yet fixed)

## Summary
While reviewing PR #118 ("Race test for duplicate email runs on PostgreSQL
only (#108)"), I checked whether gating that test to `connection.vendor ==
"postgresql"` would silently remove it from CI coverage. It turns out the
question is moot for a bigger reason: the repository's only GitHub Actions
workflow never runs the test suite at all, on any database backend.

## Symptoms
- No visible signal distinguishing "test gated to Postgres, still runs in
  CI" from "test never runs in CI" — because no tests run in CI either way.
- A regression test added specifically to guard against the duplicate-email
  race condition (issue #108) has no automated execution path that would
  catch a reintroduction of that bug.

## Environment Details
- **Server/Host:** GitHub Actions (hosted runners)
- **Services Affected:** erp_project (Django/DRF backend) test suite
- **Related Components:** `.github/workflows/deploy.yml`, `erp_project/pytest.ini`, `erp_project/conftest.py`
- **Time First Observed:** 2026-10-26, during review of PR #118

## Investigation Steps

### 1. Initial Diagnosis
PR #118 restricts `test_a_lost_race_on_create_is_duplicate_email_not_a_database_error`
to PostgreSQL via `pytest.mark.skipif(connection.vendor != "postgresql", ...)`.
Per the Principal Engineer code-review discipline (verify CI actually
exercises the backend a test is gated to), I checked what CI runs tests
against.

### 2. Root Cause Analysis
```bash
ls .github/workflows/        # only deploy.yml
cat .github/workflows/deploy.yml   # build/push Docker images + SSH deploy; no pytest step anywhere
grep -rn "ENGINE" erp_project/erp_root/settings.py   # default backend is PostgreSQL; USE_SQLITE opt-in only
```

### 3. Key Findings
- `.github/workflows/deploy.yml` is the only workflow file in the repo. It
  triggers on push to `main` and `workflow_dispatch`, and its only jobs are
  building/pushing Docker images and SSH-deploying to the VM. There is no
  `pytest`/test-run step, and no workflow at all triggers on `pull_request`.
- `erp_project/pytest.ini` and `erp_project/conftest.py` exist and are
  well-formed — the suite clearly runs locally/manually — but nothing wires
  it into CI.
- `erp_root/settings.py:183-200` defaults to PostgreSQL (SQLite only when
  `USE_SQLITE=true` is explicitly set), so a future CI workflow would, by
  default, exercise the Postgres-only-gated test correctly if one were
  added.

## Root Cause
No GitHub Actions workflow in this repository runs `pytest` on pull
requests or pushes. The deploy workflow was built purely as a build/deploy
pipeline, with no test gate inserted before or after the Docker build step.
Regression tests (including concurrency/race-condition guards like #108's)
are therefore not automated: they only run when a human remembers to run
them locally.

## Prevention / Rule
**Guardrail:** Add a `pull_request`-triggered GitHub Actions workflow
(e.g. `.github/workflows/test.yml`) that spins up PostgreSQL as a service
container and runs `pytest` for `erp_project` on every PR before merge is
allowed (branch protection requiring that check to pass).

This closes the gap directly: any test — including Postgres-gated
concurrency regression tests like the one in PR #108/#118 — then has a
guaranteed, enforced execution path instead of depending on a human running
it manually.

## Solution

### Immediate Fix
None yet — this is a finding from code review, not a hotfix. PR #118 itself
is correct and unaffected by this gap (it doesn't newly disable anything
that was previously running in CI, since nothing was).

### Long-term Fix
- Add a CI test workflow (see guardrail above) with a PostgreSQL service
  container matching `erp_root/settings.py`'s production engine, running the
  full `erp_project` pytest suite (including the Postgres-only concurrency
  tests) on every PR.
- Add branch protection requiring that check before merge to `main`.

## Prevention
- [ ] Add `.github/workflows/test.yml` (pytest + Postgres service container)
- [ ] Enable branch protection requiring the new check
- [ ] Documentation to update (CONTRIBUTING / PLAN docs referencing test
      baselines, e.g. "PLAN §9 baseline for master", should note CI status)
- [ ] No application/test code changes required beyond the workflow file

## Related Issues
- PR #118 (https://github.com/tinomupezeni/ZCHPC-ERP/pull/118) — the
  Postgres-only skip this finding was discovered while reviewing.
- Issue #108 — the original duplicate-email race bug the gated test guards
  against.

## References
- `.github/workflows/deploy.yml`
- `erp_project/erp_root/settings.py:183-200`
- `erp_project/pytest.ini`, `erp_project/conftest.py`

---

**Resolved By:** Found by Claude (code review agent) for tinotendamupezeni@thuthuka.tech
**Time to Resolution:** N/A (logged, not yet fixed)

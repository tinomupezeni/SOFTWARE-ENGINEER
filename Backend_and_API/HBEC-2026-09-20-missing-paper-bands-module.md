# Missing paper_bands.py Module Breaks Deployment

**Date:** 2026-09-20
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The staging deployment failed after merging a PR because the `hbec-admin-backend` and `hbec-admin-worker` containers crashed on startup with a `ModuleNotFoundError`. The PR introduced an import statement for a new module (`paper_bands.py`), but the file itself was not committed.

## Symptoms
- `admin-worker` container exited with code 1 during staging deployment.
- Docker logs showed `ModuleNotFoundError: No module named 'apps.curriculum.paper_bands'`.
- The import was located at `apps/exam_papers/views.py` line 19: `from apps.curriculum.paper_bands import past_paper_band_warning`.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** `admin-backend`, `admin-worker`
- **Related Components:** Django backend (`exam_papers` app)
- **Time First Observed:** 2026-09-20 11:00

## Investigation Steps

### 1. Initial Diagnosis
The staging deployment script failed during the container startup phase. Inspecting `docker logs hbec-admin-backend-staging` immediately surfaced the missing module.

### 2. Root Cause Analysis
Checked the local and remote repository for the missing file `ADMIN/adminBackend/apps/curriculum/paper_bands.py`. The file was absent from the `master` branch. The PR that introduced the import had forgotten to `git add` the new file.

```bash
# Commands used for investigation
find . -name "paper_bands.py"
git ls-tree -r origin/experimental | grep paper_bands
```

### 3. Key Findings
- The original PR branch did not contain the file.
- The author pushed the missing file later to an `experimental` branch.

## Root Cause
An incomplete git commit. The author added an import for `past_paper_band_warning` in `views.py` but failed to stage and commit the newly created `paper_bands.py` file before pushing and merging the PR.

## Prevention / Rule
**Guardrail:** We should enforce strict CI checks on pull requests that run the full Django test suite and `manage.py check` before allowing a merge.

A CI action that simply attempts to boot the Django application or run imports would have instantly caught this `ModuleNotFoundError` before it was ever merged to `master`.

## Solution

### Immediate Fix
Fetched the `experimental` branch where the missing file was recently pushed, resolved a frontend conflict in `NoExaminationYet.tsx`, and merged it into `master`. Pushed to `origin` and rebuilt the staging containers.

```bash
git fetch origin experimental
git checkout master && git merge origin/experimental
git push origin master
```

### Long-term Fix
Enable and mandate CI checks (e.g., GitHub Actions) that run tests on every PR.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- Staging deployment was further delayed by a Postgres password drift issue.

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes

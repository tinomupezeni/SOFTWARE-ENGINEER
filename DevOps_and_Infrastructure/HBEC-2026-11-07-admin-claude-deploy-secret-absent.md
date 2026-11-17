# Admin Claude deploy secret is absent

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** GitHub repository configuration and PR #115 source review; production runtime not exercised
**Severity:** High
**Status:** Workaround Applied

## Summary
PR #115 promises that merging and deploying automatically registers `admin/claude` using `ANTHROPIC_API_KEY` from the GitHub Actions secret. The repository's current secret-name list does not include `ANTHROPIC_API_KEY`. The workflow therefore passes an empty value, and `admin_model_ready()` skips registration, leaving the new feature inactive unless a model adapter was added separately.

## Symptoms
- `.github/workflows/cd.yml` maps `ANTHROPIC_API_KEY` from `secrets.ANTHROPIC_API_KEY`.
- `docker-compose.production.yml` defaults the harness value to empty.
- `admin_model_ready()` posts `/model/new` only when that value is truthy.
- `gh secret list --repo Rest-creator/HBEC --json name` returned no `ANTHROPIC_API_KEY` on 2026-11-07.

## Environment Details
- **Server/Host:** GitHub `Rest-creator/HBEC`, PR head `92e01f59a` (#115).
- **Services Affected:** Agentic Harness admin paper generation and upload pipeline.
- **Related Components:** GitHub Actions secrets, deploy workflow, LiteLLM model registration.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Traced the PR's deploy-key claim from workflow to Compose to registration code.

### 2. Root Cause Analysis
The expected secret name is not configured in the repository, so GitHub Actions supplies no key and the registration branch is not entered.

```bash
gh secret list --repo Rest-creator/HBEC --json name --jq '.[].name'
git show origin/review-pr-115:.github/workflows/cd.yml
git show origin/review-pr-115:AGENTIC_HARNESS/app/shared/llm_client.py
```

### 3. Key Findings
- The PR's no-hand-step claim depends on a pre-existing secret that is absent.
- The code fails safely to older routes, which also hides the feature omission unless model registration is checked.
- Secret values were not inspected.

## Root Cause
Release configuration was assumed rather than verified against the GitHub repository.

## Prevention / Rule
**Guardrail:** The deploy preflight must assert that `ANTHROPIC_API_KEY` is configured when the admin-Claude feature is expected and verify `admin/claude` in the deployed proxy before declaring the feature ready. This closes the silent fallback gap.

## Solution

### Immediate Fix
Pending: provision the repository secret through the authorized owner path or revise the PR's release claim and feature gate. No secret value was created in this review.

```bash
# No configuration change applied in this read-only review.
```

### Long-term Fix
Add explicit secret presence and deployed model-registration checks to the release workflow, with a failed or degraded state on omission.

## Prevention
- [ ] Configure the required secret if this feature is to launch.
- [ ] Add deploy preflight for secret presence.
- [ ] Verify the model alias and an admin-only generation call in the target environment.

## Related Issues
- PR #115; the same code is included in PR #113.

## References
- `.github/workflows/cd.yml` in PR #115, secret mapping.
- `AGENTIC_HARNESS/app/shared/llm_client.py` in PR #115, lines 265–296.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` now checks `ANTHROPIC_API_KEY` in the target VPS `.env` before building or starting a color. Missing and placeholder keys fail deploy. The owner will place the key directly on the VPS before the staging deployment; the workflow preserves an existing `.env`. Local negative and positive preflight checks passed. Staging configuration and runtime verification remain pending.

**Target preflight, 2026-11-07:** After syncing local `master` to `bc9eabef1`, a read-only check of `/opt/hbec/.env` on `hbca-vps` reported `anthropic_key=missing` without printing a value. The new deployment preflight will therefore stop the inactive-color deployment until the owner adds the key on the VPS. No deployment was started.

**Configuration update, 2026-11-07:** At the owner's request, the key was added directly to `/opt/hbec/.env` over an echo-disabled SSH stdin stream. The update preserved other entries, replaced any prior Anthropic entry atomically, and set file mode `600`. A read-only check found exactly one configured entry and the committed `preflight-admin-claude.sh` passed against the VPS file. No key value was printed or put in a command argument. Staging registration and provider behavior remain unverified.

**Resolved By:** Pending staging verification
**Time to Resolution:** Ongoing

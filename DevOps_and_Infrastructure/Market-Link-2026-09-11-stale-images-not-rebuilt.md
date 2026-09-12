# Production Running Outdated Code — Docker Images Not Rebuilt for 3 Weeks

**Date:** 2026-09-11
**Project:** Market-Link (agromarket)
**Environment:** Production (agromarketing-vm VPS, `10.50.101.17`)
**Severity:** Medium
**Status:** Resolved

## Summary
User reported the live app was running an old version. The `agromarket-frontend`/`agromarket-backend` Docker images had last been built on 2026-08-22 and were never rebuilt afterward, despite `origin/main` (Manzini-Emmanuel/agromarket) receiving at least one further commit (`2c1bbcc`, 2026-09-05, "changes suggested on wording") and the local checkout's own history moving forward via the rebase documented in `Market-Link-2026-09-10-frontend-build-json-syntax-stuck-rebase.md`. The deployed containers were simply never redeployed after new commits landed — a manual-deploy process gap, not a code defect.

## Symptoms
- User reported the running application showed old content/behavior.
- `docker images` showed `agromarket-frontend:latest` / `agromarket-backend:latest` with `Created` timestamps of 2026-08-22, while the repo's git history had moved well past that point.

## Environment Details
- **Server/Host:** agromarketing-vm (10.50.101.17)
- **Services Affected:** `marketlink_frontend`, `marketlink_backend`
- **Related Components:** `/home/user/Documents/agromarket/docker-compose.yml`; git repo at same path
- **Time First Observed:** 2026-09-11

## Investigation Steps

### 1. Initial Diagnosis
SSH'd in, checked running containers/images:
```bash
docker ps -a
docker images
```
Confirmed the running images were built 2026-08-22 (via `docker inspect ... --format='Created: {{.Created}}'`).

### 2. Root Cause Analysis
Compared the checkout's git history against `origin/main` and the `torto` fork remote:
```bash
cd /home/user/Documents/agromarket
git log --pretty=format:'%h %ad %an %s' --date=iso origin/main -15
git merge-base main origin/main   # -> 2c1bbcc (confirms origin/main is a strict ancestor of local main)
git log --pretty=format:'%h  author:%ad committer:%cd %s' --date=iso origin/main..main
```
Found the checkout's `main` already contained `origin/main`'s latest commit (`2c1bbcc`, 2026-09-05) as an ancestor, plus 11 additional local commits (some very old work rebased in on 2026-09-07 and 2026-09-10, per committer dates — see the linked rebase incident). None of this had ever been baked into a Docker image.

### 3. Key Findings
- Images were 3 weeks stale relative to git HEAD at time of report.
- The deploy process for this VPS is entirely manual (`docker compose build` + `docker compose up -d`, no CI/CD trigger on push/merge).
- A second, independent regression (React 18/19 dependency mismatch — see `Market-Link-2026-09-11-react-version-mismatch-frontend-build.md`) was masked until the rebuild was actually attempted, because nobody had rebuilt since before it was introduced.

## Root Cause
No CI/CD or deploy hook exists for this project — deployment is a manual `git pull` + `docker compose build` + `up -d` on the VPS, performed ad hoc. After 2026-08-22, further commits accumulated (on `origin/main` and locally) with no corresponding rebuild, so the running containers silently fell behind.

## Prevention / Rule
**Guardrail:** Bake the deployed commit SHA into the image (or expose it via a `/version` endpoint) and add a scheduled or pre-deploy check comparing it against the target branch's HEAD, alerting when they diverge.

That's what turns "3 weeks stale, nobody noticed until a user complained" into something a check catches automatically, without needing SSH archaeology through `docker inspect` and `git log` every time staleness is suspected.

## Solution

### Immediate Fix
```bash
cd /home/user/Documents/agromarket
docker compose build --no-cache backend frontend
docker compose up -d
```
Verified both containers came up healthy and serving:
```bash
curl -s -o /dev/null -w 'frontend HTTP %{http_code}\n' http://localhost:3001   # 200
curl -s -o /dev/null -w 'backend HTTP %{http_code}\n' http://localhost:5001/api/products   # 200
```

### Long-term Fix
- Stand up a minimal CI/CD path (even a simple webhook or scheduled pull+rebuild) so deploys aren't a manually-remembered step.
- Track/display the deployed commit SHA (e.g., bake `git rev-parse HEAD` into the image or an `/version` endpoint) so "is prod up to date" can be checked without SSH archaeology.

## Prevention
- [ ] Add a deploy script/CI job triggered on push to `main`
- [ ] Add a `/version` or `/health` endpoint reporting the built commit SHA
- [ ] Document the deploy procedure so it isn't tribal knowledge

## Related Issues
- [[Market-Link-2026-09-10-frontend-build-json-syntax-stuck-rebase]] — the rebase that (eventually) brought `main` current also introduced the dependency mismatch found while rebuilding.
- [[Market-Link-2026-09-11-react-version-mismatch-frontend-build]] — the build failure hit while performing this rebuild.

## References
- `docker-compose.yml`: `/home/user/Documents/agromarket/docker-compose.yml`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** ~45 minutes (including git archaeology to identify safe source of truth)

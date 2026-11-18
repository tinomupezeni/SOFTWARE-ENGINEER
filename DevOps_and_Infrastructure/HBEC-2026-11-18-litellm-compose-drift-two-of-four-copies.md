# litellm v1.84.10 upgrade fixed worker count/health grace in 2 of 4 compose copies, not all 4

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development / VPS setup tooling (not yet live production)
**Severity:** High
**Status:** Resolved

## Summary
PR #154 (`feat/litellm-proxy-upgrade`) bumped the litellm proxy image to
v1.84.10 across four separate compose file copies and claimed "all four
copies" received the accompanying fix for that version's heavier worker
memory footprint and slower cold start. Two of the four copies
(`scripts/docker-compose.production.fixed.yml` and
`STUDENT/Frontend/vps_docker_compose.yml`) kept the image bump but not the
fix, reproducing the exact failure mode the PR exists to prevent.

## Symptoms
Not yet observed in production — caught in code review before merge. Had
either drifted file actually been used to stand up litellm v1.84.10, the
container would either run out of memory under `--num_workers 8` (measured
in this PR at ~1 GB per worker) or be marked unhealthy and restarted by
Docker before its ~100s cold-start completed under the old `start_period: 30s`.

## Environment Details
- **Server/Host:** N/A — caught pre-deploy, in the PR's own repo files
- **Services Affected:** `litellm` service block in 2 of 4 compose files
- **Related Components:** `docker-compose.yml`, `docker-compose.production.yml`
  (correctly fixed by the PR), `scripts/docker-compose.production.fixed.yml`,
  `STUDENT/Frontend/vps_docker_compose.yml` (both drifted)
- **Time First Observed:** 2026-11-18, during code review of PR #154

## Investigation Steps

### 1. Initial Diagnosis
Code review flagged that the PR description claimed uniform treatment across
"all four copies" of the litellm service block, but two files still showed
`--num_workers 8` and `start_period: 30s` after the image bump to v1.84.10.

### 2. Root Cause Analysis
Compared the litellm service block across all four compose files in the PR's
branch. `docker-compose.yml` and `docker-compose.production.yml` both reduced
to `--num_workers 1` and raised `start_period` to `180s`, each with a comment
explaining the measurement behind the change. The other two files had only
the `image:` line's version string changed — a partial find-and-replace that
missed the two settings load-bearing to the version bump actually working.

```bash
grep -n -A25 "^  litellm:" docker-compose.yml docker-compose.production.yml \
  scripts/docker-compose.production.fixed.yml STUDENT/Frontend/vps_docker_compose.yml
```

### 3. Key Findings
- `docker-compose.yml`: `--num_workers 1`, `start_period: 180s`, plus an
  explicit memory limit (1536M) — correct.
- `docker-compose.production.yml`: `--num_workers 1`, `start_period: 180s` —
  correct (this is the file the live CD pipeline actually deploys from).
- `scripts/docker-compose.production.fixed.yml`: still `--num_workers 8`,
  `start_period: 30s` — drifted.
- `STUDENT/Frontend/vps_docker_compose.yml`: still `--num_workers 8`,
  `start_period: 30s` — drifted.

## Root Cause
A multi-file find-and-replace (bumping the image tag across four compose
copies) was applied uniformly, but the accompanying behavioral fix (worker
count, health-check grace period) that the version bump actually requires
was applied by hand to only the two files the author was actively testing
against, and never propagated to the other two.

## Prevention / Rule
**Guardrail:** add a CI check (alongside the project's existing
`check-compose-colors.py`) that diffs the `litellm` service block's
`command`/`healthcheck.start_period` across every compose file in the repo
and fails if they disagree on a pinned image version. A single source of
truth (e.g. a YAML anchor shared across files, or one canonical file the
others `include`) would close this permanently, but a parity check is the
minimum that stops silent drift between hand-maintained copies.

This closes the gap because the root cause was never "wrong values" in
isolation — it was that nothing compared the files to each other, so a
partial edit looked complete to anyone reviewing a single file at a time.

## Solution

### Immediate Fix
Applied the same `--num_workers 1` and `start_period: 180s` (with the same
measurement comments as the correctly-fixed files) to both drifted files.

```bash
# scripts/docker-compose.production.fixed.yml and STUDENT/Frontend/vps_docker_compose.yml
# --num_workers 8 -> 1
# start_period: 30s -> 180s
```

No memory-limit block was added to either file — `docker-compose.production.yml`
(the live deploy source of truth) does not set one either, so none was
introduced to avoid diverging from that file in the other direction.

### Long-term Fix
Reduce the number of hand-maintained litellm compose blocks, or add the CI
parity check described above.

## Prevention
- [ ] Add the compose-parity CI check described above
- [x] Fix applied to both drifted files
- [ ] Documentation to update (none needed — no doc described these two
      files as kept in sync, which is itself part of the problem)
- [x] Code changes required (done)

## Related Issues
- PR #154 (`feat/litellm-proxy-upgrade`), caught in the same review pass that
  also found a duplicated base64-decode helper in `image_client.py`
  (not a bug, left as a cleanup note on the PR).

## References
- `docker-compose.production.yml` litellm block (the correct reference)
- PR #154 description's upgrade runbook

---

**Resolved By:** Claude Sonnet 5 (agent session, on behalf of tinomupezeni)
**Time to Resolution:** Same session as discovery

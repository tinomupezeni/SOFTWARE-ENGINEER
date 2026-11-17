# Deploy script silently truncated mid-run, reported success, left production on stale images

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Production (restk-vps)
**Severity:** High
**Status:** Resolved

## Summary
The first real run of the newly-written VPS-build `deploy.sh` (see the
sibling report on switching to build-on-VPS) built both images
successfully, took the pre-deploy database backup, and then silently
stopped: none of `docker compose up`, the db/api readiness loops, the
Alembic head check, the `pgvector` verification, or the final
`docker compose ps`/`logs` output ever appeared in the log — yet the SSH
command still returned exit 0, and the script printed "Deployment
completed successfully." The running containers were never actually
touched; production stayed on the previous image indefinitely while the
script claimed success.

## Symptoms
- Deploy log shows full `docker compose build` output for both services,
  then `Creating pre-deploy database snapshot: ...` and the (unrelated,
  harmless) Postgres collation-version warning, then nothing until the
  outer script's own "Public frontend smoke check" / "Deployment completed
  successfully" lines.
- `docker ps` on the VPS, checked immediately after, showed all four
  containers still on their pre-deploy image tags and multi-hour `Up`
  durations — nothing had been recreated.
- The public smoke check (`curl` against the live site) still passed,
  because the untouched old containers were still serving fine — which is
  exactly what let the false "success" go unnoticed by the script's own
  logic.

## Environment Details
- **Server/Host:** restk-vps
- **Services Affected:** `deploy/production/deploy.sh`'s remote
  heredoc-over-SSH execution
- **Time First Observed:** 2026-11-17, first real run of the new
  VPS-build deploy script (see
  `reports/MARITCHO-2026-11-17-deploy-pipeline-switched-to-build-on-vps.md`)

## Investigation Steps

### 1. Initial Diagnosis
Compared the deploy log against a manual, step-by-step re-run of the same
commands over separate `ssh` invocations — the manual run worked
perfectly and visibly recreated the `db`/`redis` containers with full
progress output. The only difference was running the commands as a single
long-lived heredoc-delivered script vs. separate short SSH connections.

### 2. Root Cause Analysis
Could not conclusively reproduce the exact failure in isolation, but the
leading mechanism: the remote script was delivered over the same SSH
session's stdin via `ssh ... bash -s <<'EOF' ... EOF`. Several commands
inside that script — `docker compose exec` calls in particular — attach
to their own stdin by default unless explicitly redirected. On a
long-lived SSH session (the full run, including a slow `pip`/`npm`
dependency download, ran several minutes), this created a plausible path
for that stdin to interact with the still-arriving heredoc content and
truncate what the remote `bash -s` ever got to execute, without any of
that surfacing as a nonzero exit code on either end.

### 3. Key Findings
- Trusting a bare SSH exit code to mean "did everything in the remote
  script run" is not actually safe for a long-lived heredoc-delivered
  script that itself runs commands which can touch stdin.
- The script's own final `curl` smoke check is not sufficient evidence of
  a successful rollout either, since it will happily pass against the
  *old*, never-replaced containers.

## Root Cause
Delivering a multi-minute, multi-step remote script over an SSH session's
own stdin, combined with that script running subcommands
(`docker compose exec`) that default to inheriting that same stdin,
without any independent confirmation that the script ran to completion.

## Prevention / Rule
**Guardrail:** `deploy.sh` now generates a unique, unguessable completion
sentinel per run and requires that exact string as the literal last line
of captured remote output before declaring success — a silent truncation
now fails loudly (`FATAL: remote deploy script did not reach its
completion sentinel`) instead of printing "Deployment completed
successfully" for a no-op run.

This closes the gap because the actual failure mode here was "the remote
script stopped running, but nothing said so" — the sentinel check is a
direct, mechanical check for exactly that condition, independent of
whatever the underlying cause of a future truncation might be.

## Solution

### Immediate Fix
No production deploy was attempted again until this was fixed (the prior
run's false "success" was caught by manually verifying `docker ps` on the
VPS rather than trusting the log).

### Long-term Fix
`deploy/production/deploy.sh` (commit `eda2833`):
- Delivers the remote script via `scp` to a file and runs it with
  `bash /tmp/....sh`, instead of piping it through the SSH session's own
  stdin — fully decoupling script delivery from anything the script does
  with stdin.
- Redirects `< /dev/null` on every `docker compose exec`/`build`/`up` call
  in the remote script, so none of them can ever attach to whatever stdin
  the remote shell process has.
- Adds the completion-sentinel check described above.

## Prevention
- [x] Configuration changes needed (deploy.sh rewritten as above)
- [ ] Monitoring/alerts to add (an external check that compares the
      deployed image tag on the VPS against the tag the deploy script was
      asked to deploy, run on a delay after any deploy)
- [ ] Documentation to update (none beyond the existing README, which
      already documents the new flow)
- [x] Code changes required

## Related Issues
- `reports/MARITCHO-2026-11-17-deploy-pipeline-switched-to-build-on-vps.md`
  (the change that introduced this script)
- `DevOps_and_Infrastructure/MARITCHO-2026-11-17-pg15-to-pg16-image-bump-crashed-production-db.md`
  (a separate incident surfaced while investigating this one, from a
  manual recovery attempt — see that entry)

## References
- `deploy/production/deploy.sh`

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** ~40 minutes from discovering the false "success" to a committed, syntax-verified fix

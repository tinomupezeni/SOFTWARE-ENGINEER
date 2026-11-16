# The new DNS-resolution guardrail reported false success on its first real cutover

**Date:** 2026-11-16
**Project:** HBEC
**Environment:** Production VPS (hbca-vps), real cutover run
**Severity:** Medium
**Status:** Resolved

## Summary
`scripts/deploy/check-dns-resolution.sh` (added earlier this session as the
guardrail for `HBEC-2026-11-06-staging-school-api-dns-missing.md`) was wired
into `cd.yml`'s `cutover`/`rollback-cutover` jobs and the manual stand-in
scripts **without `sudo`**. `docker/caddy/Caddyfile` on the VPS is root-owned
(rendered by `render-caddyfile.sh`, itself always invoked with `sudo`). Every
call site ran the check unprivileged, `grep` failed with `Permission denied`
on stderr, the script's own `[ ! -f "$CADDYFILE" ]` guard passed anyway (`-f`
is true for a file that exists but can't be read), the parse loop silently
processed zero lines, and the script printed **"checked 0 hostname(s)...
every rendered hostname resolves"** — a clean, confident false pass on the
first real cutover it ever ran against.

## Symptoms
- `manual-cutover.sh`'s log showed `[dns-check] checked 0 hostname(s) from
  /opt/hbec/docker/caddy/Caddyfile.` / `[dns-check] every rendered hostname
  resolves.` — on a Caddyfile that in fact renders 11+ site blocks.
- Running the identical command with `sudo` immediately afterward showed the
  real result: 11 hostnames checked, all resolving correctly (the earlier
  dead `-api` hostname removal was in fact correct and complete).

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec`.
- **Services Affected:** DevOps/Infrastructure (deploy pipeline guardrail).
- **Related Components:** `scripts/deploy/check-dns-resolution.sh`,
  `scripts/deploy/manual-cutover.sh`,
  `scripts/deploy/manual-rollback-cutover.sh`, `.github/workflows/cd.yml`
  (`cutover` and `rollback-cutover` jobs).
- **Time First Observed:** 2026-11-16, first real `manual-cutover.sh` run
  using this guardrail.

## Investigation Steps

### 1. Initial Diagnosis
Noticed `checked 0 hostname(s)` in the cutover log, which was implausible
for a Caddyfile known to render 11+ site blocks (confirmed earlier in the
same session via `render-caddyfile.sh`'s source).

### 2. Root Cause Analysis
`ssh hbca-vps "head /opt/hbec/docker/caddy/Caddyfile"` (unprivileged)
returned `Permission denied`; the identical command with `sudo` worked.
Every call site of `check-dns-resolution.sh` in this session's own changes
ran it as `bash scripts/deploy/check-dns-resolution.sh ...`, not `sudo
bash ...` — unlike `render-caddyfile.sh`, which every caller already runs
with `sudo`.

### 3. Key Findings
- `[ ! -f "$CADDYFILE" ]` is the wrong test for "can this script actually
  read the file" — `-f` only asks "does a regular file exist at this path,"
  which is true regardless of read permission.
- A guardrail that fails silently into "everything is fine" on a permission
  error is worse than no guardrail: it is actively misleading, and this is
  exactly the failure mode the guardrail itself exists to prevent one level
  up (a route that looks fine and silently isn't).

## Root Cause
The script's own file-existence check didn't distinguish "missing" from
"unreadable," and every call site added this session ran it without the
privilege the Caddyfile actually requires.

## Prevention / Rule
**Guardrail:** `check-dns-resolution.sh` now checks `[ ! -r "$CADDYFILE" ]`
separately from `[ ! -f "$CADDYFILE" ]` and exits 1 (loud failure, not a
silent pass) when the file exists but can't be read. All four call sites
(`cd.yml` ×2, both manual scripts) now run it with `sudo`, matching
`render-caddyfile.sh`'s own existing privilege requirement.

This is the general form of the bug, not just this one script: **a
guardrail's own "nothing to check" path must be distinguishable from "I
couldn't check."** Silent zero-findings and verified-clean must never look
the same on the page.

## Solution

### Immediate Fix
`check-dns-resolution.sh`: added the `-r` check, exits 1 with a clear
"run with sudo" message instead of silently reporting success. All four
call sites updated to `sudo bash scripts/deploy/check-dns-resolution.sh`.
Re-verified live with `sudo` on hbca-vps: 11 hostnames checked, all
resolve — confirming the earlier dead-hostname removal
(`HBEC-2026-11-16-schools-deploy-verification-gaps.md`) is in fact
complete and correct, and nothing else is missing DNS.

### Long-term Fix
None beyond the fix itself.

## Prevention
- [x] `-r` check added; fails loud instead of silently passing.
- [x] All four call sites run the script with `sudo`.
- [x] Re-verified live against the real production Caddyfile.

## Related Issues
- `HBEC-2026-11-16-schools-deploy-verification-gaps.md` — this guardrail
  was added there.
- `HBEC-2026-11-06-staging-school-api-dns-missing.md` — the original
  finding this guardrail exists to catch going forward.

## References
- `scripts/deploy/check-dns-resolution.sh`
- `scripts/deploy/manual-cutover.sh`
- `scripts/deploy/manual-rollback-cutover.sh`
- `.github/workflows/cd.yml`

---

**Resolved By:** Local code fix, 2026-11-16
**Time to Resolution:** Same cutover run as discovery

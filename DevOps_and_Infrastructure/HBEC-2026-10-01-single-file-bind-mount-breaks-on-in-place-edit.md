# A Bind-Mounted Single File Stops Reflecting Edits Made via `sed -i` (or Any Editor That Renames)

**Date:** 2026-10-01
**Project:** HBEC
**Environment:** Development (blue-green dry-run infrastructure, isolated)
**Severity:** Low (caught immediately in an isolated test, zero production impact) — logged because the same vulnerable pattern exists in real production config
**Status:** Resolved (in the dry-run); flagged as a latent risk in real config

## Summary
A Caddy reverse-proxy config file was bind-mounted into its container as a
single file (`file.yml:/etc/caddy/Caddyfile`). A cutover script edited that
file on the host with `sed -i` and ran `caddy reload` to pick up the change.
The container never saw the edit — `caddy reload` kept reporting "config is
unchanged" and traffic kept reaching the old target — because `sed -i`
doesn't edit files in place at the filesystem level; it writes a new file
and renames it over the original. Docker's bind mount for a single file is
bound to the original inode, which the rename operation orphans; the
container goes on seeing the pre-edit content forever, until the container
itself is recreated.

## Symptoms
- Host-side `cat` of the file showed the edited content correctly.
- `docker exec <container> cat` of the same path inside the container still
  showed the pre-edit content.
- `caddy reload` logged `"msg":"config is unchanged"` even though the file
  had definitely changed — because the admin API was reading the config
  through the same stale bind-mounted inode.

## Environment Details
- **Server/Host:** Production VPS, isolated dry-run directory
  (`/sdb-disk/hbec-bluegreen/`), not real production
- **Services Affected:** `bg-caddy-dryrun` (dry-run container only)
- **Related Components:** `docker-compose.bluegreen.yml`'s
  `caddy-dryrun` service, `cutover.sh`

## Investigation Steps

### 1. Initial Diagnosis
A cutover script flipped the proxy target with `sed -i` and reloaded Caddy;
the live response kept showing the old color's header regardless.

### 2. Root Cause Analysis
```bash
docker exec bg-caddy-dryrun cat /etc/caddy/Caddyfile   # showed OLD content
cat /sdb-disk/hbec-bluegreen/docker/Caddyfile.dryrun   # showed NEW content (correct)
```
Confirmed the host file was correctly edited but the container's view of it
was frozen. This is a well-known Docker bind-mount behavior: mounting a
single file binds to that file's inode at mount time; any tool that edits
"in place" by writing a temp file and renaming it over the original (which
is how `sed -i`, most editors, and `mv`-based atomic writes all work) swaps
in a new inode at that path on the host — the container's mount keeps
pointing at the old, now-unlinked inode.

### 3. Key Findings
- Mounting a **directory** instead of the single file avoids this entirely:
  directory entries are resolved fresh on each lookup, so a rename within
  the mounted directory is correctly picked up by anything inside the
  container reading that path.
- **This project's real `docker/Caddyfile` is mounted the same vulnerable
  way** in `docker-compose.production.yml`'s `gateway` service
  (`./docker/Caddyfile:/etc/caddy/Caddyfile:ro`). Today this is safe because
  the real Caddyfile is only ever edited via a fresh `git pull` + container
  recreate (which re-establishes the mount), never edited in place on a
  running container the way the dry-run's cutover script did. But any
  future feature that tries to do a live, in-place Caddyfile edit +
  `caddy reload` (exactly the kind of thing blue-green cutover automation
  would want) will hit this identical bug unless the mount is changed to a
  directory first.

## Root Cause
Docker's single-file bind mount binds to a file's inode, not its path.
`sed -i` (and most "safe" in-place editors) replace a file by writing a new
one and renaming it over the original — which changes the inode at that
path on the host but leaves a single-file bind mount pointing at the old,
now-orphaned inode.

## Prevention / Rule
**Guardrail:** Any bind mount of a config file that a live process might
need to re-read after an in-place edit should mount the **containing
directory**, not the file itself. A single-file bind mount is only safe for
configs that are exclusively updated by recreating the container (a fresh
`docker compose up` re-establishes the mount against whatever file exists
at that path at that moment).

This closes the gap because the directory-mount approach was tested and
confirmed to work for Caddy's `reload` flow in the same session — the fix
is already proven, not theoretical.

## Solution

### Immediate Fix (dry-run infrastructure)
Moved the Caddyfile into its own directory and mounted that directory:
```yaml
# before (vulnerable):
volumes:
  - /sdb-disk/hbec-bluegreen/docker/Caddyfile.dryrun:/etc/caddy/Caddyfile
# after (correct):
volumes:
  - /sdb-disk/hbec-bluegreen/docker/caddy-dryrun:/etc/caddy
```
Re-verified immediately: `sed -i` edit + `caddy reload` correctly picked up
the new upstream target and the live response header changed as expected,
in both directions (blue→green and green→blue).

### Long-term Fix
No change needed to the real `docker/Caddyfile` mount today, since it's
never edited in place on a running container. **If/when blue-green cutover
automation is built against the real gateway**, the real
`docker-compose.production.yml` `gateway` service's Caddyfile mount should
be changed to a directory mount first, or the cutover mechanism should use
Caddy's admin API to push a new config object directly (bypassing the file
entirely) instead of editing the mounted file.

## Prevention
- [x] Fixed in the dry-run infrastructure, verified working.
- [ ] When real blue-green cutover automation is built: change the real
      gateway's Caddyfile mount to a directory mount, or push config via
      Caddy's admin API instead of file edits.
- [x] Documented here so the next person building on this dry-run doesn't
      rediscover the same bug.

## Related Issues
- Part of Phase 1 of the blue-green deployment exploration this session —
  see the accompanying report for the full dry-run build-out.

## References
- `docker-compose.production.yml` (`gateway` service's Caddyfile mount)
- `/sdb-disk/hbec-bluegreen/docker-compose.bluegreen.yml` (fixed version)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Caught and fixed within the same dry-run session, before it could affect anything real.

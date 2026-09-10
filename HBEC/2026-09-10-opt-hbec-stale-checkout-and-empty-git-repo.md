# `/opt/hbec` Is Not the "5 Files" CLAUDE.md Describes — Stale Checkout, Zero-Commit Git Repo

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Production
**Severity:** Low
**Status:** Investigating

## Summary
Found during a pre-promotion readiness audit. `CLAUDE.md`'s CI/CD section
states production is "Container-only — 5 files at `/opt/hbec/`:
`docker-compose.production.yml`, `.env`, `docker/init-db.sql`,
`docker/keys/jwt_*.pem`, `litellm_config.yaml`." The actual directory
contains a full stale source checkout, a non-functional git repo, and years
of accumulated stray files.

## Symptoms
No functional symptom — production runs correctly regardless, since its
compose file has no `build:` context and never reads from these stray files.
Purely a documentation/reality mismatch and a housekeeping backlog.

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec`
- **Services Affected:** none functionally — documentation and operator
  clarity only
- **Time First Observed:** 2026-09-10, during the same readiness audit as
  the shared-`:latest`-tag finding

## Investigation Steps

### 1. Initial Diagnosis
`ls -la /opt/hbec` for a routine "confirm the 5 files" sanity check before a
promotion instead showed `ADMIN/`, `AGENTIC_HARNESS/`, `STUDENT/` full source
trees (last touched Aug 17-24), a `.git` directory, 3 separate
`.claude-backup-*` directories, 5 `.env.bak-*` files, ~20 stray planning/audit
`.md` files, and several screenshots.

### 2. Root Cause Analysis
`git status` inside `/opt/hbec` reported `fatal: your current branch 'master'
does not have any commits yet` — the repo was `git init`'d (a remote is
configured, pointing at the real GitHub repo) but nothing was ever actually
committed there. Every single file, including the compose file and `.env`,
shows as untracked. So this isn't a real deployment checkout that drifted —
it's a directory that had files copied into it at some point, then had `git
init` run without ever being used for version control.

### 3. Key Findings
- Confirmed the stale `ADMIN/`/`AGENTIC_HARNESS/`/`STUDENT/` trees are inert:
  `docker-compose.production.yml` has no `build:` stanza for any app image —
  every service pulls a prebuilt `ghcr.io/rest-creator/hbec-*` image by tag.
  Nothing in production's deploy path reads these directories at all.
  Deleting them would have zero effect on the running stack.
- The broken git repo means there is no way to answer "what commit is
  `/opt/hbec` on" from git — the only ground truth is the running
  containers' image IDs (and even those aren't reliably labeled — see Key
  Findings on the companion tag-sharing entry, where
  `org.opencontainers.image.revision` read back as `"unknown"` on the
  production admin-backend/admin-frontend images).

## Root Cause
Operational drift: at some point files were placed at `/opt/hbec` (likely an
early manual setup step) and never cleaned up as the deploy model matured
into "pull a prebuilt tagged image, no local build context needed."

## Solution

### Immediate Fix
None — not blocking, purely housekeeping. Left untouched this session so it
doesn't interfere with the promotion in progress.

### Long-term Fix
Either remove the stale source trees, backup sprawl, and non-functional
`.git` directory to actually match the documented "5 files" design, or update
`CLAUDE.md` to describe what's really there if there's a reason to keep it
(e.g. as a manual reference checkout) — right now the doc and the reality
directly contradict each other, which will mislead the next person who reads
it expecting a minimal directory.

## Prevention
- [ ] Clean up `/opt/hbec` to match the documented 5-file design, or fix the
      documentation to match reality — whichever is actually intended
- [ ] If a git checkout is wanted there for reference, either actually clone
      it properly or drop the empty `.git` directory so it stops implying
      version tracking that isn't happening

## Related Issues
- Found in the same audit pass as the shared-`:latest`-tag issue
  (`2026-09-10-staging-and-production-share-the-latest-image-tag.md`)

## References
- `/opt/hbec/CLAUDE.md` (the stale copy sitting in this same directory)
- `HBEC/CLAUDE.md`'s "VPS" section under CI/CD Pipeline

---

**Resolved By:** Not yet — documented for a future cleanup pass
**Time to Resolution:** N/A

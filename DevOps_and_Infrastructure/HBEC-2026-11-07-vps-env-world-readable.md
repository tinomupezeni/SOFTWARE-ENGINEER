# VPS environment file exposed service secrets to other local users

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** HBEC VPS `/opt/hbec/.env`
**Severity:** High
**Status:** Resolved

## Summary
The VPS `.env` file held service secrets but was mode `664`, allowing local accounts outside the owner and group to read it. This was found before adding the Anthropic provider key. The key update atomically replaced the file with mode `600`, limiting access to the owner.

## Symptoms
- `stat` reported owner `winstontino`, group `winstontino`, mode `664`.
- The file contains deployment secrets, so the other-read bit was inappropriate.
- No evidence of unauthorized access was observed in this session.

## Environment Details
- **Server/Host:** `hbca-vps`.
- **Services Affected:** All services configured from `/opt/hbec/.env`.
- **Related Components:** Deploy scripts, Docker Compose interpolation, provider and signing keys.
- **Time First Observed:** 2026-11-07, immediately before the Anthropic key update.

## Investigation Steps

### 1. Initial Diagnosis
Checked file ownership and mode without reading any secret value.

### 2. Root Cause Analysis
The deployed `.env` file had retained permissive mode `664`; no file-mode guard was present in the key-provisioning path.

```bash
ssh hbca-vps 'stat -c "%U %G %a" /opt/hbec/.env'
```

### 3. Key Findings
- The owner account could update the file directly.
- The file's mode was `664` before the update and `600` after it.
- The Anthropic preflight passed after the update, with exactly one key entry present.

## Root Cause
The VPS environment file was created or maintained without owner-only permissions, despite storing service credentials.

## Prevention / Rule
**Guardrail:** Deployment preflight should reject `/opt/hbec/.env` unless it is a regular file with mode `600` and an expected owner.

This catches permission drift before any new credential is loaded into the file or containers.

## Solution

### Immediate Fix
Replaced `.env` atomically during the authorized key update, writing the new file with `0600` permissions and verifying its mode afterward. The updater received the key only over SSH stdin; the value was not logged.

```bash
ssh hbca-vps 'stat -c "%a" /opt/hbec/.env'  # 600 after update
```

### Long-term Fix
Add an owner/mode check to the deploy preflight and create new `.env` files with `umask 077`.

## Prevention
- [x] Restrict the current VPS `.env` file to its owner.
- [ ] Add a deploy-time permission check for future changes.
- [ ] Verify configuration parity on the target environment at staging deploy.

## Related Issues
- `HBEC-2026-11-07-admin-claude-deploy-secret-absent.md`.

## References
- `/opt/hbec/.env` metadata check on 2026-11-07.
- `scripts/deploy/preflight-admin-claude.sh`.

---

**Resolved By:** Owner-only file mode applied during key update
**Time to Resolution:** Same work session

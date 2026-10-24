# mywealth-vm key not authorized

**Date:** 2026-10-24
**Project:** Workstation SSH configuration
**Environment:** Development
**Severity:** Low
**Status:** Investigating

## Summary
The `mywealth-vm` SSH alias was added for `user@10.50.23.166` with the
workstation's existing Ed25519 key, but the VM does not yet authorize that
public key. Host-key trust was established after fingerprint confirmation;
passwordless authentication remains pending one-time key installation.

## Symptoms
- `ssh mywealth-vm true` fails with `Permission denied (publickey,password)`.

## Environment Details
- **Server/Host:** 10.50.23.166
- **Services Affected:** SSH access
- **Related Components:** `~/.ssh/config`, `~/.ssh/id_ed25519.pub`
- **Time First Observed:** 2026-10-24

## Investigation Steps

### 1. Initial Diagnosis
Added the alias and verified OpenSSH resolves it to the intended host, user,
port, and identity file.

### 2. Root Cause Analysis

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 mywealth-vm true
```

The host key was initially unknown. After confirming the ED25519 fingerprint
`SHA256:y6tdMvuha4TDfL++dG46vp2aYJy/2GHN6PCRWreZq/k`, the key was added to
`~/.ssh/known_hosts`. Authentication then reached the server but was rejected.

### 3. Key Findings
- Alias resolves to `10.50.23.166`, user `user`, port `22`.
- The workstation key exists at `~/.ssh/id_ed25519`.
- The VM does not yet contain the matching public key in `user`'s
  `authorized_keys`.

## Root Cause
The remote account has not been bootstrapped with the workstation's public SSH
key.

## Prevention / Rule
**Guardrail:** Require a successful `ssh -o BatchMode=yes mywealth-vm true`
check after every new SSH alias setup.

This catches missing remote authorization without falling back silently to
password authentication.

## Solution

### Immediate Fix
Pending one-time password-authenticated installation of the public key.

### Long-term Fix
Keep the alias pinned to the explicit Ed25519 identity file and retain host-key
verification in `known_hosts`.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- None

## References
- `~/.ssh/config`
- `~/.ssh/known_hosts`

---

**Resolved By:** Pending
**Time to Resolution:** In progress

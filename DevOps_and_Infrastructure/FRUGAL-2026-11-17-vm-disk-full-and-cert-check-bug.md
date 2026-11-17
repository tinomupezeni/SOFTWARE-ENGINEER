# mywealth-vm disk filled during Wazuh build; setup script's idempotency check was also wrong

**Date:** 2026-11-17
**Project:** FRUGAL
**Environment:** Development (mywealth-vm)
**Severity:** Low
**Status:** Resolved

## Summary
Two independent small issues surfaced while standing up Wazuh on
`mywealth-vm`: the host's disk filled to 91% mid-build (Docker build
cache), and the cert-generation idempotency check in
`setup_wazuh_stack.sh` mis-detected an existing, correctly-generated
cert directory as missing because of a permissions quirk, causing
needless regeneration on every re-run.

## Symptoms
1. `docker compose build` failed with `no space left on device` partway
   through building the victim image, after the Wazuh stack's images and
   volumes had already landed.
2. Re-running `setup_wazuh_stack.sh` against an already-running stack
   printed "Generating indexer SSL certs" and re-ran the generator
   container instead of skipping, even though certs already existed.

## Environment Details
- **Server/Host:** `mywealth-vm`
- **Services Affected:** Docker build cache, `lab/wazuh/setup_wazuh_stack.sh`
- **Related Components:** `docker builder prune`, `config/wazuh_indexer_ssl_certs/`
- **Time First Observed:** 2026-11-17

## Investigation Steps

### 1. Initial Diagnosis
```bash
df -h /            # 91% used, 4.6GB free
docker system df   # build cache: 2.1GB total, 1.561GB reclaimable
```

### 2. Root Cause Analysis
For (1): Wazuh's images/volumes plus accumulated Docker build cache from
earlier sessions had consumed nearly all headroom on a 49GB disk that
started this session at 66% used.

For (2):
```bash
ls config/wazuh_indexer_ssl_certs/   # Permission denied
```
The cert generator locks the directory down to a uid the invoking user
can't list. The script's check (`[ -z "$(ls -A ... )" ]`) silently read
"Permission denied" as empty output, so it always concluded the certs
were missing.

### 3. Key Findings
- A narrowly-scoped `docker builder prune -f` (dangling build cache only)
  freed 1.5GB without touching any image the user might still want —
  this was deliberately chosen over a broader `-af` prune, which the
  session's own permission classifier correctly flagged as a destructive
  action warranting more caution.
- Checking "did a privileged process already do X" by trying to read
  files that process deliberately locked down is unreliable; a process
  status check (is the thing that would have created/used those files
  already running) is a better proxy when you can't read the files
  directly.

## Root Cause
(1) Accumulated build cache ate into limited disk headroom on a VM that
was already more than half full before this session started. (2) The
idempotency check conflated "can't read" with "doesn't exist."

## Prevention / Rule
**Guardrail:** `setup_wazuh_stack.sh` now checks whether
`single-node-wazuh.manager-1` is already running as its proxy for "certs
already exist and are in use," instead of trying to list a directory the
cert generator intentionally restricts access to.

For disk space: no guardrail added here beyond awareness — this VM's
headroom should be monitored if more container-heavy work (OpenVAS,
future candidates) lands on it.

## Solution

### Immediate Fix
- `docker builder prune -f` freed 1.5GB, enough to complete the build.
- Changed the cert-check condition to `docker ps | grep
  single-node-wazuh.manager-1` instead of listing the certs directory.

### Long-term Fix
None beyond the script fix; disk headroom on `mywealth-vm` is now lower
(6.1GB free after pruning) and worth checking before the next heavy
build (e.g. OpenVAS).

## Prevention
- [x] Configuration changes needed (script logic)
- [ ] Monitoring/alerts to add — worth considering before OpenVAS work
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `reports/FRUGAL-2026-11-17-v1-wazuh-full-stack-on-mywealth-vm.md`.

## References
- `Frugal/lab/wazuh/setup_wazuh_stack.sh`.

---

**Resolved By:** Claude (Sonnet 5), with tinomupezeni
**Time to Resolution:** ~10 minutes

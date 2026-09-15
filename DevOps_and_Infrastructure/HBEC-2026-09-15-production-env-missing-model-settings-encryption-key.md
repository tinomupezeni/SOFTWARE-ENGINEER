# Production `.env` Was Missing `MODEL_SETTINGS_ENCRYPTION_KEY` — Caught by Dry-Run Config Validation Before Any Container Was Touched

**Date:** 2026-09-15
**Project:** HBEC
**Environment:** Production (`/opt/hbec` on `hbca-vps`)
**Severity:** High (would have crash-looped admin-backend on deploy)
**Status:** Resolved

## Summary
While promoting 75 commits' worth of already-staging-verified work to
production (image retag-and-reuse, per the "build once, deploy everywhere"
process), a `docker compose -f docker-compose.production.yml config --quiet`
dry-run validation — run deliberately *before* touching any running
container, as pre-promotion housekeeping — failed because
`MODEL_SETTINGS_ENCRYPTION_KEY` was referenced by `docker-compose.yml` /
`docker-compose.staging.yml` / `docker-compose.production.yml`'s
admin-backend service block but was never present in `/opt/hbec/.env`.
This variable is read by `ADMIN/adminBackend/apps/model_settings/crypto.py`
to derive the Fernet key that encrypts `ApiKeyEntry.encrypted_key` — the
provider API keys the "Model Settings drives live routing" feature (part of
this promotion's commit range) applies to live LiteLLM routing. Without it,
`config/settings/base.py` and `config/settings/production.py` both read an
empty string from `os.environ.get("MODEL_SETTINGS_ENCRYPTION_KEY", "")`,
which `crypto.py` would still derive *a* key from (SHA-256 of an empty
string) rather than erroring outright — so the real risk wasn't a crash
loop on startup, but every future write silently encrypting provider API
keys under a predictable, empty-string-derived key indefinitely, with no
error at any point to reveal it.

## Symptoms
None observed in production — caught pre-deploy by the dry-run, not by any
live failure. Had this shipped unnoticed, the symptom would have been
silent: admin-backend starts fine, Model Settings appears to work, but
every provider API key saved from that point on is encrypted with a key
derived from an empty string — trivially reproducible by anyone who reads
`crypto.py`, effectively storing the keys in cleartext-equivalent form.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec` (production)
- **Services Affected:** `admin-backend` (reads the var directly),
  transitively any provider routing that depends on a correctly-encrypted
  `ApiKeyEntry`
- **Related Components:** `ADMIN/adminBackend/apps/model_settings/crypto.py`,
  `ADMIN/adminBackend/config/settings/base.py:323`,
  `ADMIN/adminBackend/config/settings/production.py:146`
- **Time First Observed:** 2026-09-15, during pre-promotion housekeeping
  checks for the production promotion of commit `2b545f7`

## Investigation Steps

### 1. Initial Diagnosis
Per the user's explicit request to check for necessary housekeeping/
migrations before promoting, ran a config dry-run against production's
compose file and `.env` before bringing up any service:
```bash
docker compose -f docker-compose.production.yml --env-file .env config --quiet
```

### 2. Root Cause Analysis
The dry-run's error named the missing variable directly (compose's
`${VAR:?error message}` required-variable syntax). Traced it to
`docker-compose.production.yml`'s admin-backend block:
```yaml
MODEL_SETTINGS_ENCRYPTION_KEY: ${MODEL_SETTINGS_ENCRYPTION_KEY:?...}
```
then to `crypto.py`, confirming it accepts any string and derives a proper
32-byte Fernet key via `base64.urlsafe_b64encode(hashlib.sha256(raw_key.encode()).digest())`
— so there's no format requirement, only a presence requirement, and this
was a feature that had never been deployed to production before (it
shipped as part of the same 75-commit range being promoted), so this
`.env` gap had simply never been exercised until now.

### 3. Key Findings
- The variable was present in staging's `.env.staging` (that environment
  had already exercised this feature) but had no equivalent entry in
  production's hand-maintained `.env` — a real environment-drift gap, not
  a code bug.
- `docker compose config --quiet` catches a missing required variable
  *before* any container is created or restarted — this is exactly the
  mechanism that turned a would-be silent security gap into a pre-deploy
  blocker with a clear error message.
- Per `HBEC/CLAUDE.md`, `.env` is hand-maintained and never auto-regenerated
  by `cd.yml` on a deploy that already has one — so this class of gap can
  only be closed by a human (or an agent acting under explicit permission)
  reading the compose file's required-variable list and reconciling it
  against the live `.env`, there is no automated sync.

## Root Cause
`docker-compose.production.yml` gained a new required environment variable
(`MODEL_SETTINGS_ENCRYPTION_KEY`) as part of the Model Settings feature's
compose changes, but `/opt/hbec/.env` — hand-maintained, never
auto-regenerated — was never updated to add it, since this was the first
time that feature's compose changes were being promoted to production.

## Prevention / Rule
**Guardrail:** Always run `docker compose -f <compose-file> --env-file
<env-file> config --quiet` as a mandatory pre-flight step before any
promotion or deploy that changes compose files — never bring up containers
first and discover a missing required variable via a crash loop. This is
now a confirmed, repeatable step in the production promotion process (per
the "build once, deploy everywhere" retag-and-reuse flow), not optional
housekeeping.

This closes the gap because the compose files already declare every
required variable via `${VAR:?message}` syntax — the dry-run is the
mechanism that actually reads and enforces that declaration before it's
too late to matter.

## Solution

### Immediate Fix
Generated a fresh random value and appended it to `/opt/hbec/.env`
(confirmed absent first, nothing else in the file touched):
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(48))"
# appended as MODEL_SETTINGS_ENCRYPTION_KEY=<value> to /opt/hbec/.env
```
Re-ran the dry-run to confirm it passed cleanly before proceeding with the
actual promotion.

### Long-term Fix
None needed beyond the fix above — the guardrail above is the durable
prevention; there is no code change that would prevent a hand-maintained
`.env` from drifting, only a process check.

## Prevention
- [x] Configuration changes needed — done (`.env` updated)
- [ ] Monitoring/alerts to add — n/a, caught pre-deploy by design
- [x] Documentation to update — this entry; worth a one-line mention in
      `docs/DEPLOYMENT.md`'s promotion runbook that `config --quiet` is a
      mandatory pre-flight step, not optional
- [ ] Code changes required — n/a

## Related Issues
- None yet filed — first time this feature's compose changes were promoted
  to production.

## References
- `ADMIN/adminBackend/apps/model_settings/crypto.py`
- `ADMIN/adminBackend/config/settings/base.py:323`
- `ADMIN/adminBackend/config/settings/production.py:146`
- `docker-compose.production.yml` (admin-backend service block)
- `/opt/hbec/.env` (production, not in git)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session, caught pre-deploy — minutes to resolve
once identified

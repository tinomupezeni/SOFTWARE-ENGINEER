# No Mechanism Existed to Detect Runtime Drift Between Services on a Shared Secret/Key — Two Prior Incidents Had to Be Caught by a Live Symptom

**Date:** 2026-09-16
**Project:** HBEC
**Environment:** Development/DevOps tooling (applies to staging and production)
**Severity:** Medium (a process gap, not a live bug — closes a detection blind spot two real incidents fell into)
**Status:** Resolved

## Summary
Following the two same-day incidents where `hbec-harness` verified JWTs
against a stale in-memory public key after a partial promotion restart, and
where a stray `.env` file caused `PAYMENTS_INTERNAL_SECRET` (and, it turned
out, `HARNESS_WEBHOOK_SECRET`) to silently disagree between staging
containers, both dev-log entries independently proposed the same guardrail:
compare what every relevant service actually holds at runtime, not just
what the compose file says should be there. That guardrail was never built —
the existing `scripts/check_config_parity.py` (run in CI) only validates the
compose *file* (is a secret wired on both sides, do both sides reference the
same host variable), which cannot see either failure mode: both incidents
had a **perfectly correct compose file** the entire time. The drift was
invisible to any static check by construction — one was a stale value a
long-running process never re-read, the other was two containers loading
from different files despite identical compose configuration.

## Symptoms
None new — this closes a gap identified by two already-resolved incidents
(see References), found via a proactive caching/drift-architecture review
rather than a new live report.

## Environment Details
- **Server/Host:** Applies to both `hbca-vps` targets — `/opt/hbec`
  (production) and `/home/winstontino/HBEC` (staging)
- **Services Affected:** Every service holding one half of a cross-service
  shared secret or key: `student-backend`/`worker`/`beat`, `harness`,
  `payments`, `admin-backend`/`worker`/`beat`, `notifications`/`worker`/`beat`,
  `schools-backend`
- **Time First Observed:** 2026-09-16, during a caching-architecture audit
  that revisited both prior incidents' still-open "Monitoring/alerts to add"
  items

## Investigation Steps

### 1. Initial Diagnosis
Both `HBEC-2026-09-15-harness-jwt-public-key-stale-after-partial-promotion-restart.md`
and `HBEC-2026-09-15-staging-subscription-401-payments-internal-secret-drift.md`
left their "Monitoring/alerts to add" checkbox unticked, with near-identical
proposed guardrails ("a fingerprint check... before finishing any promotion,
compare... loaded by every running service" / "a deploy-time canary check
that signs a payload with each shared secret and confirms the paired
service accepts it"). Neither had been implemented.

### 2. Root Cause Analysis
Read the existing `scripts/check_config_parity.py` + `scripts/service_contracts.py`
in full: it parses `docker-compose.production.yml`/`docker-compose.staging.yml`
with a strict YAML loader and checks, per registered contract, whether both
sides have a secret var set and whether both resolve to the same `${...}`
host variable name. This is a genuinely different and complementary check —
it catches "the file itself is wrong" (e.g. a var missing on one side, or
pointing at the wrong host variable) — but it operates entirely on the
static file. It has no way to observe:
- A process that read a value once at startup and never rereads it (the
  harness JWT case) — the file is fine; the process's memory isn't.
- Two containers that, despite identical compose configuration, were each
  brought up with a different `--env-file` (or none) on different deploy
  commands and so loaded genuinely different live values (the payments
  secret case) — the file is fine; the shell invocation wasn't.

### 3. Key Findings
- A full audit of every cross-service shared secret/key in the codebase
  (JWT keypair, `PAYMENTS_INTERNAL_SECRET`, `HARNESS_WEBHOOK_SECRET`/
  `WEBHOOK_SECRET`, `PAYMENTS_WEBHOOK_SECRET`/`WEBHOOK_SECRET`,
  `REPLICATION_HMAC_KEY`, `SCHOOLS_ADMIN_SECRET`, `ADMIN_JWT_SECRET`/
  `SECRET_KEY`) found `check_config_parity.py` already covers 4 of these 7
  relationships in its static form; it was never extended to the JWT
  key-file pair, `PAYMENTS_INTERNAL_SECRET`, or `REPLICATION_HMAC_KEY`'s
  3-way fan-out (admin-backend signs to both student-backend and harness).
- `HARNESS_GATEWAY_SECRET` (a fallback var read by
  `apps/ai_gateway/services.py`) is confirmed dead code — nothing on the
  harness side ever reads a variable by that name, so it was deliberately
  excluded from the new runtime registry rather than generating noise for a
  divergence with zero runtime effect.
- Both prior incidents' actual diagnosis commands were exactly "exec into
  each container and compare a fingerprint of what's live there" — the fix
  here is to make that a standing, scriptable, repeatable step instead of
  something reinvented by hand under live-incident pressure each time.

## Root Cause
No tooling existed that queried the actual runtime state of services
holding a shared secret/key and compared it across the set that must agree —
only the compose *file* was ever validated, which is a necessary but
insufficient check for this bug class.

## Prevention / Rule
**Guardrail:** `scripts/check_runtime_secret_drift.py` (new), run as the
last step of any promotion or staging deploy, after `docker compose up`
completes and every touched service reports healthy. For each of 7
registered secret/key groups (`scripts/runtime_secrets.py`), it execs into
every live service that must agree and compares either a `printenv`-sourced
value's fingerprint (plain secrets) or a `sha256sum` of the mounted file
(the JWT public key) — the file-hash form is what actually reproduces the
harness incident's failure mode, since `docker exec` reads through that
specific container's own mount table, not a fresh copy of the current host
file, so a container still pinned to a stale bind-mount inode is caught
exactly the way the original manual diagnosis found it. A service that
isn't currently running is skipped for that group rather than treated as an
error, mirroring `check_config_parity.py`'s existing "not applicable here"
philosophy — this keeps the check safe to run right after an intentionally
partial promotion.

This closes the gap because both prior incidents are now a single command
away from being caught automatically at the moment of deploy, rather than
requiring a live user-facing symptom and a manual `docker exec` investigation
to even notice — the exact mechanical check both incidents' own
Prevention/Rule sections already called for, now actually built.

## Solution

### Immediate Fix
- `scripts/runtime_secrets.py` (new) — registry of 7 secret/key groups,
  each naming the Compose service names that must agree and either a single
  `var` (same env var name everywhere) or a per-service `vars` map (names
  differ, e.g. harness's own `WEBHOOK_SECRET` vs. student-backend's
  `HARNESS_WEBHOOK_SECRET`, both required to resolve to the same value).
- `scripts/check_runtime_secret_drift.py` (new) — for each group, execs
  into every named service via `docker compose exec -T`, compares fingerprints
  (never raw secret values — nothing this script does prints an actual
  secret to stdout/logs), and reports any group where live values disagree.
  Exit 0/OK if every group's live services agree (or too few are running to
  compare); exit 1 with a per-group breakdown otherwise.
- `docs/DEPLOYMENT.md` — new "Runtime secret/key drift check" step added to
  the post-deploy "Verify Health" section, with the exact commands for both
  production (`/opt/hbec`) and staging (`/home/winstontino/HBEC`, needs
  `--env-file .env.staging`).
- Verified live: ran against both production and staging (both reported OK,
  7/7 groups, confirming the two prior incidents are in fact fully resolved
  and not still quietly drifted); rebuilt and redeployed `student-backend`
  and `harness` on staging for this session's separate exam-mode fix, then
  re-ran the checker immediately after that partial restart — still OK,
  confirming the tool itself behaves correctly around exactly the kind of
  partial-restart deploy that caused the original JWT incident.

### Long-term Fix
None needed beyond the above. If a new cross-service shared secret is ever
introduced, add it to `scripts/runtime_secrets.py` at the same time it's
added to `scripts/service_contracts.py` — the two registries are
deliberately kept as separate, parallel files rather than merged, since one
validates static config and the other validates live state, and a single
relationship can need different service lists in each (e.g. `notifications-worker`
mounts the JWT public key file for parity purposes but never actually
verifies a JWT itself, since it's not an HTTP-serving process).

## Prevention
- [x] Configuration changes needed — n/a
- [x] Monitoring/alerts to add — done: this is the alerting mechanism itself
      (as a manual/runbook step for now; a future iteration could wire it
      into CD as an automatic post-deploy gate rather than a documented
      manual step)
- [x] Documentation to update — `docs/DEPLOYMENT.md`'s "Verify Health"
      section
- [x] Code changes required — done (see Solution)

## Related Issues
- `HBEC-2026-09-15-harness-jwt-public-key-stale-after-partial-promotion-restart.md`
- `HBEC-2026-09-15-staging-subscription-401-payments-internal-secret-drift.md`

## References
- `scripts/runtime_secrets.py`, `scripts/check_runtime_secret_drift.py`
- `scripts/service_contracts.py`, `scripts/check_config_parity.py` (the
  existing, complementary static checker)
- `docs/DEPLOYMENT.md` — "Runtime secret/key drift check" section

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — designed, built, and verified live
against both production and staging within the hour

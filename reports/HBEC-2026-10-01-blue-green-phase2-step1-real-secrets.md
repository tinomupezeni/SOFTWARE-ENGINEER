# Blue-Green Phase 2, Step 1: Real Secrets Swapped Into the Dry-Run

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Architecture Decision / Infrastructure Proof-of-Concept
**Status:** Completed

## Summary
Replaced every freshly-generated, dry-run-only secret in the blue-green
dry-run's Student Backend stack (Django `SECRET_KEY`, `JWT_SECRET`,
`REPLICATION_HMAC_KEY`, `HARNESS_WEBHOOK_SECRET`, `HARNESS_GATEWAY_SECRET`,
`PAYMENTS_INTERNAL_SECRET`, `PAYMENTS_WEBHOOK_SECRET`, and the JWT signing
keypair) with the real production values, while deliberately keeping every
other variable exactly as isolated as Phase 1 left it: the database is
still the one-time snapshot (not live, not a replica), email/IMAP stay
disabled, cross-service URLs stay pointed at non-resolving stub hosts, and
Caddy stays bound to `127.0.0.1` only. This is the first of three staged
steps toward a real Phase 2, each approved and executed separately rather
than all at once given production has real students on it.

## Context / Trigger
User asked to "start phase 2." Phase 2 as originally scoped in the Phase 1
report bundles several independently risky changes — real secrets, the
real database, public DNS — each with a different blast radius. Asked the
user how to sequence it before touching anything; they chose a staged,
one-variable-at-a-time approach, and for the database specifically, a
periodically-refreshed copy rather than the live database or a streaming
replica. This report covers Step 1 only.

## Scope
**Included**: the real values for the 7 env-var secrets above, and the
real JWT signing keypair, swapped into `docker-compose.bluegreen.yml` /
`.env.bluegreen` for `student-backend-blue`, `student-backend-green`,
`student-worker`, and `student-beat` (the four services sharing the
`&student_env` anchor).

**Explicitly excluded**: the real database (still the Phase 1 snapshot),
real email/IMAP credentials (kept blank — the risk of this dry-run
accidentally sending real email to real students was judged not worth
taking for what this step tests), real cross-service URLs (harness/admin
stay pointed at stub hostnames that don't resolve), and public DNS/Caddy
exposure (still `127.0.0.1:8080` only).

## Method
1. Confirmed production's actual secret variable *names* first
   (`grep -oE '^[A-Z_0-9]+=' /opt/hbec/.env`, names only) before writing
   anything, so the plan referenced real variables rather than assumed
   ones.
2. Fetched the real values and wrote them directly into `.env.bluegreen`
   via a single server-side script (read from `/opt/hbec/.env`, append to
   the target file) — no intermediate `cat`/`echo` of secret values ever
   appeared in any tool output. Verified success via a line count and an
   empty-value check that print only variable *names*, never values.
3. Updated the compose file's hardcoded `dryrun-*-not-for-real-use`
   placeholder strings to `${VAR}` interpolation, one `sed` replacement
   per variable, each targeting a unique, unambiguous string.
4. Copied the real JWT keypair with a same-host `cp` (source and
   destination both on the VPS, so the key material never left the host
   or passed through anything I could see) and verified the copy was
   byte-identical to production via `sha256sum` — a hash comparison
   confirms identity without the file contents ever needing to be printed.
5. Recreated the four affected containers, confirmed both colors healthy
   immediately.
6. Verified the actual thing this step claims: minted a JWT with the real
   private key and verified it with the real public key, inside the
   dry-run, proving the signing material genuinely round-trips — not just
   that an env var is non-empty.
7. Verified the non-goals explicitly, rather than assuming they held:
   confirmed `EMAIL_HOST`/`IMAP_HOST` still blank, confirmed the stub
   hostnames still fail to resolve (so no real cross-service call path
   exists even accidentally), confirmed production's own secret files were
   never modified (hashed, matches the values used for the copy).
8. Re-ran the same zero-impact checks as every prior step in this series:
   real container start timestamps, primary disk usage, live site health.

## Decisions & Findings

### Verifying "the secret works" needs more than checking the env var is set
Confirming `JWT_SECRET` is non-empty doesn't prove it's usable; confirming
a JWT signed with the real private key is actually verifiable with the
real public key does. The round-trip test is the actual claim this step
makes, and it's cheap to run — worth doing explicitly rather than treating
"container is healthy" as proof the secrets work.

### Hash comparison is the right tool for "did I copy the right secret" without exposing it
Every verification in this step that needed to confirm a secret value was
correct did so via `sha256sum` (for files) or an echoed variable *name*
check (for env vars), never by printing the value itself anywhere, including
to my own tool output. This generalizes cleanly to any future step that
needs to confirm real secret material landed correctly.

### The non-goal guardrails needed to be checked, not assumed
`HARNESS_SERVICE_URL`/`ADMIN_SERVICE_URL` were already stub hostnames
before this change and weren't touched by this step's `sed` replacements —
but confirming they still don't resolve (rather than just confirming the
`sed` commands didn't match those lines) catches the actual risk this
guardrail exists for: real secrets being usable to call a real service
this dry-run isn't meant to reach yet.

## Changes Made
On the VPS only, inside the existing disposable dry-run directory
(`/sdb-disk/hbec-bluegreen/`) — no changes to the HBEC repository:
- `.env.bluegreen`: gained 7 new lines (the real secret values), `chmod
  600`.
- `docker-compose.bluegreen.yml`: 7 lines changed from hardcoded
  placeholders to `${VAR}` interpolation.
- `docker/keys/jwt_private.pem` / `jwt_public.pem`: replaced with a copy
  of the real production keypair, `chmod 644`.
- Four containers recreated to pick up the new config.

## Verification
- JWT round-trip (mint with real private key, verify with real public
  key) succeeded inside the dry-run.
- `sha256sum` of the copied keypair matched production's exactly.
- `EMAIL_HOST`/`IMAP_HOST` confirmed still blank inside the running
  container; `harness-stub`/`admin-stub` confirmed to still fail DNS
  resolution from inside the container — no real outbound path exists.
- Production's `.env` and JWT key files confirmed untouched (every access
  to them during this step was read-only: `grep`, `cut`, `cp` *from*
  them, `sha256sum` — never a write).
- Both colors reported `healthy` within one check interval of recreation.
- Zero impact on real production, confirmed the same way as every prior
  step: `hbec-student-backend`/`hbec-admin-backend`/`hbec-postgres`
  container start timestamps unchanged, primary disk usage unchanged
  (152G/73%), `https://student.hbca.tech/` returned `HTTP/2 200`.

## Follow-ups / Deferred
- **Step 2** (next, separately planned): a periodically-refreshed database
  copy (cron/systemd timer re-running the same `pg_dump`/`pg_restore`
  Phase 1 used), explicitly never the live database and never streaming
  replication, per the user's stated preference. Needs its own
  plan/approval before adding a persistent scheduled job to the VPS.
- **Step 3** (after Step 2): public DNS / real traffic switching —
  deliberately last in the sequence.
- Full platform expansion (admin-backend, harness, payments, schools,
  frontends) remains separately deferred.

## References
- [`HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`](HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md)
- [`HBEC-2026-10-01-blue-green-expand-contract-migration-test.md`](HBEC-2026-10-01-blue-green-expand-contract-migration-test.md)
- [`HBEC-2026-10-01-blue-green-differing-code-version-cutover.md`](HBEC-2026-10-01-blue-green-differing-code-version-cutover.md)
- `contracts/service-signature/golden.json` — the HMAC format this step's
  secrets feed into (format already enforced by each service's own tests;
  this step verified the real *values*, not the format again).

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continuing directly from the prior blue-green work.

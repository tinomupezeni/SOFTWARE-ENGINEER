# Harness Verified JWTs Against a Stale Public Key After a Partial-Service-Restart Production Promotion — All Harness-Backed Endpoints 401'd

**Date:** 2026-09-15
**Project:** HBEC
**Environment:** Production (`hbca-vps`, `/opt/hbec`)
**Severity:** Critical (broke gamification dashboard, achievements, leaderboard, and Friday chat streaming for every student)
**Status:** Resolved

## Summary
Immediately after promoting commit `2b545f7` to production (retag-and-reuse
of already-staging-tested images; `harness` deliberately excluded from the
restart set since it had zero code changes in the promoted commit range),
students hit consistent `401 Unauthorized — "Invalid or expired token"` on
every `/harness-stream/api/v1/...` route: the gamification dashboard,
achievements, leaderboard, and Friday's chat stream. `student-backend`
itself (freshly restarted as part of the promotion) authenticated fine;
only requests proxied through to the harness (port 8080, via nginx's
`/harness-stream` prefix) failed. Root cause: `hbec-harness` was verifying
tokens against a JWT public key that no longer matched the key
`student-backend` was actually signing with — not because any key file was
rotated during this promotion, but because `harness` was one of the
services correctly left untouched (per the "build once, deploy everywhere,
only restart what changed" promotion process), while `student-backend` and
several other services *were* restarted and picked up the current
`/opt/hbec/docker/keys/jwt_public.pem` content. The two processes ended up
holding different keys in memory simultaneously — a mismatch that was
latent (both sides were consistent with each other before the promotion)
and only became visible once one side of the pair restarted and the other
didn't.

## Symptoms
- Browser console: repeated `401` on
  `GET /harness-stream/api/v1/analytics/gamification/dashboard`,
  `/achievements`, `/leaderboard?...`, and
  `POST /harness-stream/api/v1/friday/chat/stream`, each with response body
  `{"detail":"Invalid or expired token"}`.
- Every other part of the student app (login, curriculum, exam practice,
  notifications) worked normally — only harness-routed calls failed, since
  those are the only ones verified by `hbec-harness` rather than
  `student-backend` itself.
- Reported by the user directly off a live browser session immediately
  after the promotion, with a full console stack trace.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec` (production)
- **Services Affected:** `hbec-harness` (verifier); all student-facing
  features that route through it (gamification, Friday/AI companion chat)
- **Related Components:** `docker-compose.production.yml` (`JWT_PUBLIC_KEY_FILE`
  bind mounts, lines ~305-320 for student-backend, ~511/550 for harness),
  `/opt/hbec/docker/keys/jwt_public.pem`, `/opt/hbec/docker/keys/jwt_private.pem`
- **Time First Observed:** 2026-09-15, within minutes of the production
  promotion completing

## Investigation Steps

### 1. Initial Diagnosis
The 401s were scoped entirely to `/harness-stream/*` — every other route
worked, including ones also gated by JWT auth on `student-backend` itself.
That narrowed it immediately to something specific to how `hbec-harness`
verifies tokens, per `HBEC/CLAUDE.md`'s documented split: "Student Backend
signs, Harness verifies with public key only."

### 2. Root Cause Analysis
Compared the JWT public key fingerprint as seen by each process:
```bash
docker exec hbec-student-backend sh -c 'openssl rsa -pubin -in /run/secrets/jwt_public.pem -outform DER | sha256sum'
docker exec hbec-student-backend sh -c 'openssl rsa -in /run/secrets/jwt_private.pem -pubout -outform DER | sha256sum'  # derived from the actual signing key
docker exec hbec-harness sh -c 'openssl rsa -pubin -in /run/secrets/jwt_public.pem -outform DER | sha256sum'
sha256sum /opt/hbec/docker/keys/jwt_public.pem  # the host file both containers bind-mount
```
Result: `student-backend`'s loaded key, its private-key-derived public key,
and the current host file all matched (`...50dc0`). `hbec-harness`'s loaded
key was a completely different fingerprint (`...67f09`), even though its
compose entry bind-mounts the exact same host path
(`./docker/keys/jwt_public.pem:/run/secrets/jwt_public.pem:ro`) — confirmed
via `docker inspect --format '{{range .Mounts}}...'`, ruling out a
misconfigured or divergent mount source.

### 3. Key Findings
- The bind mount source path was correct and identical across services —
  this was not a compose misconfiguration.
- `harness` had been running since before this promotion (`StartedAt`
  2026-09-14T09:43), `student-backend` was freshly started by the promotion
  (`StartedAt` 2026-09-15). Everything the promotion *did* restart came up
  holding the current host key content; `harness`, correctly left alone
  because its own code was unchanged, kept whatever key its auth layer
  loaded at its own last startup.
- This means the two keys were **already** out of sync with each other
  before today — `harness`'s in-memory key predates whatever the current
  host file holds — but that pre-existing drift was invisible as long as
  every JWT-signing/verifying service that mattered had been restarted (or
  not) in the same batch, keeping them mutually consistent. A promotion
  that intentionally restarts only a subset of services is exactly the
  condition that surfaces a drift like this: it doesn't create the
  mismatch, it exposes one that already existed between two services that
  hadn't been restarted together in a while.
- Every other verify-only consumer of the same key
  (`notifications-backend/worker/beat`) was checked and found already
  consistent with the current host file — they happened to have been
  restarted recently enough (or were part of this same promotion) not to
  be affected. `harness` was the only casualty this time, but the
  underlying risk applies to any service in `docker-compose.production.yml`
  that mounts `jwt_public.pem` and is excluded from a given promotion's
  restart set.

## Root Cause
`hbec-harness` loads its JWT public key once at process startup and never
re-reads it; the promotion correctly restarted only the services whose
code actually changed, which meant `harness` kept an in-memory key that
had already drifted from what `student-backend` (and the current host key
file) actually use, and that drift only became visible once
`student-backend` was restarted on top of it.

## Prevention / Rule
**Guardrail:** Add a fingerprint check to the promotion process itself —
before finishing any promotion, compare the JWT public key fingerprint
loaded by every running JWT-signing or JWT-verifying service (not just the
ones being restarted) against the current `/opt/hbec/docker/keys/
jwt_public.pem` on disk. Any service holding a stale fingerprint gets a
plain `docker compose restart <service>` (no image change needed) before
the promotion is considered complete — restarting to pick up a config/
secret file is a much lower-risk operation than a code deploy and belongs
in the same checklist as the `docker compose config --quiet` dry-run this
same promotion already runs.

This closes the gap because the actual failure mode was never a bad key or
a bad mount — it was staleness in a service nobody thought to restart
alongside a partial promotion, and a fingerprint comparison is the direct,
mechanical way to catch "this process's in-memory key no longer matches
the file it's bind-mounted to" before it reaches a live user.

## Solution

### Immediate Fix
```bash
docker compose -f docker-compose.production.yml restart harness
```
A pure process restart — no image change, no code touched — so it re-reads
the current, correct host key file. Verified via fingerprint match
post-restart and a live smoke test against the real domain with a freshly
signed token:
```bash
curl -s -o /dev/null -w 'HTTP %{http_code}\n' \
  -H 'Authorization: Bearer <token>' \
  https://student.hbca.tech/harness-stream/api/v1/analytics/gamification/dashboard
# HTTP 200
```
Also checked every other service mounting `jwt_public.pem`
(`harness-embeddings`, `notifications-backend/worker/beat`) — all already
consistent with the current host key, no further restarts needed.

### Long-term Fix
Add the fingerprint-comparison step described in Prevention/Rule above to
the documented promotion runbook (`docs/DEPLOYMENT.md`), as a companion
check alongside the existing `docker compose config --quiet` dry-run.

## Prevention
- [ ] Configuration changes needed — n/a, no config was wrong
- [ ] Monitoring/alerts to add — worth considering a lightweight periodic
      check that all JWT-key-consuming services agree on a key fingerprint
- [x] Documentation to update — add the fingerprint-check step to
      `docs/DEPLOYMENT.md`'s promotion runbook
- [ ] Code changes required — n/a; this is a process gap, not a code bug

## Related Issues
- Same promotion session also caught a missing `MODEL_SETTINGS_ENCRYPTION_KEY`
  in `/opt/hbec/.env` via the pre-flight `config --quiet` dry-run — see
  `HBEC-2026-09-15-production-env-missing-model-settings-encryption-key.md`.
  Both are promotion-process gaps found the same day; this one required a
  live symptom to surface because a stale in-memory key isn't visible to a
  static config check.

## References
- `docker-compose.production.yml` — `harness` and `student-backend` service
  blocks, `JWT_PUBLIC_KEY_FILE`/`JWT_PRIVATE_KEY_FILE` env and bind mounts
- `HBEC/CLAUDE.md` — "JWT: RS256 asymmetric — Student Backend signs,
  Harness verifies with public key only"

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Diagnosed and fixed within ~15 minutes of the user
reporting the live browser errors

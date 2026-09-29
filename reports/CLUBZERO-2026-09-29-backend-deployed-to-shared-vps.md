# Club Zero backend deployed to a shared VPS (`smepulse-vm`)

**Date:** 2026-09-29
**Project:** Club Zero
**Type:** Deployment
**Status:** Completed — backend live, all 36 backend tests pass against the deployed instance, full register/login smoke test verified end-to-end. Not yet reachable from the public internet — that depends on a separate cPanel-side reverse proxy the user is setting up (see Follow-ups).

## Summary
Until this session, Club Zero's entire backend only ever existed as a
Docker Compose stack on the local development machine, reachable only over
LAN (`192.168.60.227:8001`) — meaning nobody outside that WiFi network
could ever use the app, regardless of how it was distributed. The user
provided SSH access to an existing VPS (`10.50.101.11`) and asked for the
backend to be deployed there, running "beside" several other unrelated
live projects already on the box. The backend is now running there,
verified working, on port `8001`.

## Context / Trigger
Direct user request, prompted by a "let's talk deploying so people can
download it" conversation about distribution (Amazon Appstore vs. Google
Play). Before addressing app-store choice, it was flagged that backend
hosting was the more fundamental blocker — the app could be listed
anywhere and still be useless without a publicly reachable backend. The
user then provided VPS credentials directly and asked for auto-SSH setup,
a `smepulse-vm` alias, and the backend deployed there.

## Scope
**Included:** SSH key-based access setup, fixing a pre-existing disk
issue on the VPS that was blocking any deployment (see the separate
bug-log entry), copying the backend codebase and secrets to the VPS,
writing a hardened production `docker-compose.yml`, building and
launching the stack, and verifying it end-to-end.

**Explicitly excluded** (deferred, not forgotten):
- The public-facing domain/reverse-proxy side — the user has a separate
  cPanel setup that will route a public domain to this VM; that
  configuration is being done outside this session, on infrastructure
  this session doesn't have access to.
- Updating the mobile app's hardcoded backend URLs (`192.168.60.227:8001`
  in three files) — blocked on knowing the final public domain, which
  doesn't exist yet.
- App store distribution (Google Play, Amazon Appstore) — separately
  blocked on the user not yet having a Google account for Play Console;
  not pursued further this session.
- TLS/HTTPS termination — assumed to be handled by the cPanel gateway
  fronting this VM, not configured on the VM itself.

## Method
Investigated the VPS's actual state before touching anything, rather than
assuming a clean box: an initial `ssh-copy-id` failed with a read-only
filesystem error, which turned into a full investigation (see the
DevOps_and_Infrastructure bug-log entry) before any deployment work could
proceed — the VM turned out to be shared with three other live projects,
one of them already showing symptoms (`unhealthy` Postgres containers)
from the same underlying issue. Confirmed every existing container used
`restart: unless-stopped` before rebooting the VM to fix that issue, so
the fix wouldn't strand unrelated services. Once the filesystem was
healthy, deployment followed the same DB-migration and verification
patterns already established for this project this session: manual schema
setup where needed, `pytest` run inside the actual deployed container
(not just locally) as the correctness check, and live `curl` smoke tests
of the real auth flow rather than trusting a clean `docker compose up`
alone.

## Decisions & Findings

**Hardened the production `docker-compose.yml` rather than copying the
dev one verbatim.** Differences from the local dev version:
- `SECRET_KEY` is now an explicit random 64-hex-char value passed via
  `.env` (`chmod 600`, never committed anywhere) — the app's own code
  (`app/security.py`) silently falls back to a hardcoded dev key
  (`"supersecret-dev-key"`) if this isn't set, which would have been a
  real vulnerability on a publicly-reachable instance signing real JWTs.
- Postgres credentials changed from the default `postgres`/`postgres` to
  a dedicated `clubzero` user with a random generated password, also via
  `.env`.
- Postgres's host port mapping (`5433:5432` in the dev compose file) was
  removed entirely — there's no reason for the database to be reachable
  from outside the Docker network at all in production, only the `api`
  service needs a host-published port.
- Added `restart: unless-stopped` to all three services, matching the
  convention already used by every other project on this shared VM (this
  is also what let the VM's later reboot self-heal cleanly).

**Port 8001, chosen to avoid the other projects' ports and match local
dev convention.** The VM already had 3000, 3001, 3002, and 8000 in use by
`labflow-ai-main` and `topshelf-bot`. 8001 was free and is the same port
Club Zero's backend already uses locally, so there's no port-mapping
confusion between the two environments.

**UFW rule added explicitly for 8001**, even though Docker's own iptables
rules can sometimes bypass UFW's filtering for published container ports
— added for consistency with how the other services' ports (8000, 3001,
3002) were each given their own explicit UFW allow rule, and because
relying on an undocumented bypass behavior isn't something to build on
deliberately.

**Test data cleaned up after the smoke test.** The `deploytest@x.com`
account created to verify the live register/login flow was deleted from
the production database afterward (`DELETE FROM users WHERE email=...`)
— this is now the real production DB, not a scratch/dev one, so it
doesn't carry throwaway verification data forward.

## Changes Made
- `~/.ssh/config` (local dev machine): added `Host smepulse-vm` alias
  (`10.50.101.11`, user `user`), key-based auth installed via
  `ssh-copy-id`.
- VPS (`smepulse-vm`, `~/club-zero-backend/`): full backend codebase
  synced (excluding `venv/`, `__pycache__/`, `.pytest_cache/`), a new
  production `docker-compose.yml` (see Decisions above), a new `.env`
  with generated `SECRET_KEY`/`POSTGRES_PASSWORD` (mode 600, not
  committed anywhere), `firebase-service-account.json` copied over
  directly via `scp` (mode 600) rather than through git.
- VPS firewall: `ufw allow 8001/tcp`.
- VPS filesystem: fixed as a prerequisite (see the separate
  `DevOps_and_Infrastructure` bug-log entry) — not a Club Zero-specific
  change, but required before any of the above could happen.

## Verification
- `docker compose ps` on the VPS: all three containers (`api`, `db`,
  `redis`) `Up`, `api` published on `0.0.0.0:8001->8000/tcp`.
- `curl http://localhost:8001/` → `200`, `{"message":"Welcome to the Club
  Zero API"}`; `/docs` → `200`.
- Full `pytest` suite run *inside the deployed container*
  (`docker compose exec -T api python -m pytest -q`): 36 passed — same
  count as local, confirming the deployed environment (fresh Postgres,
  generated secrets, copied code) behaves identically to dev.
- Live smoke test of the real HTTP flow: `POST /auth/register` → `201`,
  `POST /auth/login` → `200` with a valid token pair, against the actual
  running deployed instance (not a test fixture) — then the test account
  was deleted (see Decisions above).
- An initial `api` container restart loop (`ConnectionRefusedError`
  connecting to Postgres) was observed and diagnosed as an expected
  `depends_on` race — Compose's `depends_on` only waits for the DB
  *container* to start, not for Postgres to finish initializing on a
  brand-new data volume. Resolved itself once Postgres finished starting
  (Docker's `restart: unless-stopped` retried automatically); confirmed
  via `docker compose logs db` showing "database system is ready to
  accept connections" shortly before `api` came up clean.

## Follow-ups / Deferred
- **Public reachability is not yet verified.** The backend is confirmed
  working *on the VPS itself* (`localhost:8001`) and the necessary UFW
  rule is in place, but nothing has confirmed the cPanel-side gateway
  actually routes a public domain to this VM's port 8001 yet — that setup
  is on the user's side, outside this session's access. Once a domain is
  live, re-verify `GET https://<domain>/` returns the same welcome
  message from outside the local network.
- **Mobile app still points at the old LAN IP.** `lib/services/auth_service.dart`,
  `lib/services/club_service.dart`, and `lib/providers/dashboard_provider.dart`
  all hardcode `192.168.60.227:8001` (`http://`/`ws://`). Once the public
  domain is confirmed working, these need to change to the real domain
  (and almost certainly `https://`/`wss://`, assuming the cPanel gateway
  terminates TLS), followed by a fresh release APK build.
- **App store distribution is still blocked** — the user doesn't yet have
  a Google account for Play Console registration. Direct APK distribution
  (a downloadable link) was proposed as an interim path while that gets
  sorted, but hasn't been built yet.
- **No monitoring/alerting exists for the VPS's disk health** — flagged
  in the companion bug-log entry as worth adding given the underlying
  storage already threw I/O errors once.
- **`FIREBASE_CREDENTIALS_PATH` and the Google Sign-In Android OAuth
  client are tied to the app's *debug* signing certificate** (see the
  2026-09-29 Google Sign-In bug-log entry) — if/when a real release
  signing key is created for Play Store distribution, that new
  certificate's SHA-1 will need registering in Firebase the same way
  before Google Sign-In works on Play-Store-signed builds.

## References
- `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/CLUBZERO-2026-09-29-smepulse-vm-disk-io-errors-read-only-root.md`
  — the VPS filesystem issue that had to be fixed before this deployment
  could start.
- `SOFTWARE-ENGINEER/Integrations_and_Auth/CLUBZERO-2026-09-29-google-sign-in-missing-android-oauth-client.md`
  — referenced above re: signing-certificate/Firebase coupling.
- `/home/shadowe/Projects/SharedHQ/DEVLOG.md` — living project status doc;
  not yet updated to reference this deployment as of this report (next
  step).

---

**Completed By:** Claude (Sonnet 5), for tinotendamupezeni@thuthuka.tech.
**Duration:** Single continuous session, 2026-09-29.

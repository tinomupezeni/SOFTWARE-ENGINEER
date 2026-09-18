# FIELD_ENCRYPTION_KEY Fail-Fast Check Broke the Backend Docker Build (Runtime .env Isn't Available During `docker build`)

**Date:** 2026-09-18
**Project:** chemglee-concept-site
**Environment:** Production (caught during a deploy, before any container was touched)
**Severity:** Medium (would have blocked every deploy until fixed; caught immediately, zero customer impact)
**Status:** Resolved

## Summary
Deploying today's Paynow/notification-encryption work failed at
`docker compose up -d --build`: the `backend` image build errored during
`RUN python manage.py collectstatic` with
`ImproperlyConfigured: FIELD_ENCRYPTION_KEY environment variable is required`.
`config/settings/production.py` fails fast if `FIELD_ENCRYPTION_KEY` is
unset — correct at container *runtime*, but `collectstatic` runs as a
`RUN` step *during the image build*, which has no access to
`docker-compose.yml`'s `env_file: ./backend/.env` (that only applies once a
container starts). `backend/Dockerfile` already had exactly this problem
solved for `DJANGO_SECRET_KEY`/`ALLOWED_HOSTS` — both get a
build-time-only dummy `ENV` value with a comment explaining why — but the
equivalent line for `FIELD_ENCRYPTION_KEY` was never added when that check
was introduced earlier this session.

## Symptoms
- `docker compose up -d --build` failed with exit code 1 during the
  `backend` build stage; `frontend`/`admin` built fine.
- Currently-running containers were untouched — Compose builds images
  before recreating anything, so this failed before touching production.

## Root Cause
A new fail-fast settings check (`FIELD_ENCRYPTION_KEY` required in
`production.py`) was added without noticing the codebase already had an
established pattern for exactly this class of problem — a build-time-only
dummy value for any setting `production.py` requires but that
`collectstatic` doesn't actually need a *real* value for.

## Solution
`backend/Dockerfile`:
```dockerfile
ENV DJANGO_SECRET_KEY=build-time-dummy-not-used-at-runtime
ENV ALLOWED_HOSTS=localhost
ENV FIELD_ENCRYPTION_KEY=build-time-dummy-not-used-at-runtime
```
Safe because `collectstatic` never touches the database or any
`EncryptedCharField` value — the dummy only needs to be non-empty to
satisfy the `if not FIELD_ENCRYPTION_KEY: raise` check; it doesn't need to
be a real Fernet key.

## Prevention / Rule
**Guardrail:** Any new "required in production" settings check added to
`production.py` needs a corresponding look at `Dockerfile` for whether
`collectstatic` (or anything else in a `RUN` step) will hit it — this
codebase already has the pattern (search `Dockerfile` for
"build-time-only"); a new check should extend that list, not reinvent
whether it's needed.

## Prevention
- [x] Code changes required — done
- [ ] Consider a CI step that builds the backend image (not just runs the
      test suite) so this class of failure is caught on a PR rather than
      on an actual deploy — this would have been caught before merge, not
      after

## References
- `backend/Dockerfile`
- `backend/config/settings/production.py` (`FIELD_ENCRYPTION_KEY` check)
- Related: `chemglee-concept-site-2026-09-17-paynow-sandbox-live-admin-config.md`
  (`DevOps_and_Infrastructure/`) — introduced the check this build-time gap
  was missing for.

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Caught and fixed within minutes of the failed
deploy, same session

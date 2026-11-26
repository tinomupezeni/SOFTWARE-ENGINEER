# SWAP-O-SELL — API Integration Notes

**Last updated:** 2026-11-26

## `VITE_API_URL` is a Vite build-time value, and the build-arg wiring broke silently for a long time
**sqlite-dev-postgres-driver** is unrelated to this — see that section
below. For the API URL: `VITE_API_URL` must be passed as a Docker
`--build-arg` *and* actually consumed by the Vite build (via `define` /
`import.meta.env`) for it to end up in the static bundle — setting it as a
runtime container env var does nothing for a pre-built static Nginx image.
This was broken for essentially every production build until
2026-11-04 (bundle always contained the literal `http://127.0.0.1:8000/api/`
regardless of what was supplied). Full root-cause writeup:
`Frontend_and_UI/SWAP-O-SELL-2026-11-04-vite-api-url-silently-ignored-in-production-builds.md`.
When touching the Dockerfiles/build pipeline for either frontend, verify
the build arg is actually wired through `ARG`/`ENV`/Vite `define`, not just
declared.

## Messaging requires UUID-consistent identity across creation and matching
Conversation creation and conversation lookup/matching must resolve
product/user references to the same `public_id` UUID on both sides, or the
frontend will either 400 on `POST /api/messaging/conversations/` or create
duplicate conversations. See `decisions/api-design.md` "Messaging/product
identity" and `Integrations_and_Auth/SWAPOSELL-2026-10-15-messaging-conversation-retry-loop.md`.
Also watch the React effect dependency list in
`components/messaging/MessageModal.tsx` — including the conversation-list
string in its dependencies previously caused repeated conversation-creation
requests on every list update.

## `django.contrib.postgres` sqlite-dev pitfall
Even with `DATABASE_URL` unset (SQLite selected), `django.contrib.postgres`
being unconditionally in `INSTALLED_APPS` forces a `psycopg2` import at
`django.setup()` time, before any DB connection is attempted — so a fresh
non-Docker local checkout fails to boot at all without `psycopg2`
installed, even though it will never touch Postgres. `TrigramSimilarity`
usage in `modules/listings/views.py` is already guarded by
`connection.vendor == 'postgresql'`, but the app-level import isn't.
Workaround applied, not fixed at the `INSTALLED_APPS` level — see
`Database_and_State/SWAP-O-SELL-2026-11-04-sqlite-dev-requires-postgres-driver.md`.

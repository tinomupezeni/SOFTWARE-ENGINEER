# SWAP-O-SELL — Authentication Decisions

**Last updated:** 2026-11-26

## JWT + Google sign-in, no session-based auth — (ongoing)
**Chose:** `djangorestframework-simplejwt` for primary API auth, with
Google OAuth sign-in added to the storefront (`google-auth` backend
dependency; `VITE_GOOGLE_CLIENT_ID` wired through as a frontend build arg
alongside `VITE_API_URL`, commits `64302bd`/`aeb51ad`).
**Alternatives considered:** Not deeply documented in the dev-log history
reviewed; no evidence of session-based auth ever being used.
**Why:** Stateless API auth suits the decoupled storefront/admin/backend
split where each frontend is a separately deployed static bundle talking
to one shared API origin.
**Still valid?** Yes as of 2026-11-26. Google sign-in is newly added
(not yet reflected in any report in `reports/` — only visible via commit
history); verify its full flow (token exchange, account linking) against
code before relying on this description, since no dedicated decision/bug
report exists yet for it.

## Admin/client separation uses `is_staff`, not a role field
See `decisions/api-design.md` — "Admin-vs-client user separation". Kept
here as a cross-reference since it is also an authorization decision.

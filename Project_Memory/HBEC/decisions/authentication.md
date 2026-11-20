# HBEC — Authentication Decisions

**Last updated:** 2026-11-20

Why auth is built the way it is — not how it works mechanically (that's
`implementation/` or the code itself). One entry per decision:

## Platform admin vs school admin use different credential systems — 2026-11-20
**Chose:** Platform staff authenticate to the admin backend as a custom
`AdminUser` (`USERNAME_FIELD = "email"`) with short-lived JWTs
(simplejwt, refresh blacklist on); school staff authenticate to the
*schools* backend as stock `django.contrib.auth` users with an opaque,
persistent `SchoolToken` per user (one row, `get_or_create`, no expiry).
**Alternatives considered:** unifying on JWT for both; unifying on tokens
for both.
**Why:** the two services own their own tables and were built as separate
deploys — the schools service deliberately has no `AUTH_USER_MODEL` and no
REST framework, so a hand-rolled `Token` header keeps it dependency-light.
Cost of that split: "logging out a school admin" and "disabling an
account" are different mechanisms in each service, and cross-service calls
are authenticated by the copied HMAC `ServiceSignature` v2 module instead
of by either user system.
**Still valid?** Yes as of 2026-11-20 (code-verified for the schools side
this session; the admin side's JWT config was read but not exercised).

## School-admin credentials are minted server-side and delivered only by email — 2026-11-20
**Chose:** When a platform admin adds a school (or a school admin), the
backend generates `secrets.token_urlsafe(12)`, hashes it into the user,
and sends it in a welcome email; the school-creation response does *not*
return it (the "add a school admin" response does, for the panel to show
once). There is no password-change or password-reset endpoint anywhere in
the schools service or dashboard.
**Alternatives considered:** showing the generated password in the panel
after creation (the dashboard's own form text promises "the system will
automatically generate a secure password", implying the operator sees it
somewhere); a reset-by-email flow.
**Why:** delivery was assumed to be email; nobody chose the "no reset
flow" explicitly — it was never built.
**Still valid?** **No — known gap.** Production has no `EMAIL_*`
configuration for the schools backend, so the mail goes to the console
backend and the only copy of the credential lands in container stdout;
`fail_silently=True` hides even that from any alert. Being decided 2026-
11-20; see
`DevOps_and_Infrastructure/HBEC-2026-11-20-school-admin-password-never-delivered.md`.

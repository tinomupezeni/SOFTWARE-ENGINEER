# ZIM DASH JWT Auth for Anonymous and Named Accounts (ZD-M1-03)

**Date:** 2026-10-27
**Project:** ZIM DASH
**Type:** Feature (auth)
**Status:** Completed

## Summary
Implemented ZD-M1-03: `/auth/anonymous`, `/auth/register`, `/auth/login`,
and `/auth/me` (the first route behind the new JWT dependency), plus
Redis-backed rate limiting on `/auth/anonymous` — closing an open finding
in the repo's own threat model, not just the bare task checklist.

## Context / Trigger
Direct follow-on to ZD-M1-01 (same session), which created `iam.users`.
Before writing any endpoint, read `database_design.md` Section 2.1 (exact
upgrade-in-place semantics), ADR-003 (anonymous-first, no-login-required
identity model), and `docs/security/threat_model.md` — the last of which
turned out to contain a requirement not visible in `tasks.md` at all.

## Scope
In scope: the four endpoints tasks.md lists, plus whatever threat_model.md
assigns to this task number specifically (rate limiting on
`/auth/anonymous`). Out of scope: Epic 4 Task 4.3 ("migrate order history
from anonymous device identity to named account") — this doesn't need a
separate migration step at all, because `/auth/register` already updates
the same row rather than creating a new one; `orders.customer_id` simply
never changes across the upgrade. Also out of scope: refresh-token
rotation, phone-number OTP verification, and reverse-proxy-level rate
limiting for public reads (a separate, still-open threat-model item not
assigned to this task).

## Method
Cross-referenced three documents before implementing, since `tasks.md`'s
four-line "In Scope" list alone would have missed a real requirement:
- `database_design.md` Section 2.1 for the exact row-upgrade mechanics.
- ADR-003 for why anonymous issuance has to be low-friction (no device
  pre-registration step, no OTP).
- `docs/security/threat_model.md`, which explicitly flags unlimited
  `/auth/anonymous` calls as an open Denial-of-Service/fraud vector and
  tags the mitigation **"Open — not yet implemented, ZD-M1-03"** — i.e.
  the threat model itself assigns a requirement to this task number that
  `tasks.md`'s own scope bullet list never mentions.

## Decisions & Findings
- **`/auth/anonymous` must upsert on `device_id`, not always insert.**
  Neither doc states this in so many words, but it's the only reading
  consistent with "device-scoped identity" (ADR-003) and the unique
  partial index on `device_id` (database_design.md Section 2.1): the same
  device calling `/auth/anonymous` again after its token expires has to
  get the same `iam.users` row back, or "device-scoped" is meaningless and
  order history would scatter across throwaway rows every time a token
  expires.
- **A device that has since registered still gets its current (NAMED)
  identity back from `/auth/anonymous`**, never a forced downgrade — the
  row is the single source of truth for "what this device currently is,"
  and `/auth/anonymous` only needs to re-issue a token for whatever that
  is.
- **Password hashing: `bcrypt` directly, not `passlib[bcrypt]`.** passlib's
  bcrypt backend has had repeated compatibility breaks against
  bcrypt>=4.1, and the library is effectively unmaintained; calling
  `bcrypt.hashpw`/`checkpw` directly removes an unnecessary layer.
- **Rate limiter is deliberately generic**, not an auth-specific helper —
  `threat_model.md`'s same Denial-of-Service row flags order creation and
  promo redemption for identical treatment once those endpoints exist
  (Epic 1/ZD-M1-05), so `app/core/rate_limit.rate_limit` takes a
  `key_prefix`/`limit`/`window_seconds` rather than being
  `/auth/anonymous`-shaped.
- **JWT lifetime: 30 days, no refresh-token mechanism yet.** A real
  tradeoff, made explicit rather than picked silently — ADR-003's
  low-friction goal argues against frequent re-auth, and the threat model
  already prices a stolen token's blast radius as "theft only exposes one
  user's session," but it does not yet weigh that specifically against a
  30-day window. Flagged as a follow-up, not treated as settled.

## Changes Made
- `app/core/security.py` — password hashing (bcrypt), JWT
  issuance/decoding (PyJWT).
- `app/core/rate_limit.py` — Redis-backed fixed-window limiter (reusable).
- `app/core/redis.py`, `app/db/session.py` — shared async Redis client and
  SQLAlchemy async session factory (new runtime infra; ZD-M1-01/02 only
  had Alembic's own sync connection).
- `app/schemas/auth.py` — request/response Pydantic models.
- `app/api/deps.py` — `get_current_user`, the JWT middleware tasks.md
  asks for, meant to be reused by every future authenticated route.
- `app/api/auth.py` — the four endpoints; wired into `app/main.py`.
- `app/core/config.py` — JWT secret/algorithm/expiry and rate-limit
  settings (dev-only secret default, flagged as such).
- `pyproject.toml` — added `pyjwt`, `bcrypt`; `B008` added to the Ruff
  ignore list (FastAPI's `Depends(...)`-as-default pattern, not the
  mutable-default-argument bug the rule targets); pytest-asyncio
  configured to a session-scoped event loop.
- `tests/conftest.py` (new, shared fixtures), `tests/test_auth.py` (new,
  12 tests).
- Commit `cf31f57`, pushed to `origin/main`.

## Verification
- `ruff check .`, `black --check .` — clean.
- `pytest` (default, no DB) — 1/1 passing, unaffected.
- `pytest -m db` — 15/15 passing (12 new auth tests + the 3 existing
  migration tests, confirmed to still coexist correctly after the
  event-loop fix below): anonymous issuance and its device-id idempotency
  (same device → same user, verified by a direct row count), rate limiting
  (6 rapid calls → 5×200 then 429), register's same-row upgrade (asserts
  the returned `user_id` is identical before/after), register's conflict
  handling (already-named account, phone number already in use by another
  account), login success/wrong-password/unknown-number, and `/auth/me`'s
  three paths (valid token, missing token, garbage token).
- Hit a real event-loop bug during this verification, not just a passing
  first run: the module-level DB engine and Redis client (one connection
  pool for the app's lifetime) broke against pytest-asyncio's default
  per-test event loop ("Future attached to a different loop" / "Event loop
  is closed"). Fixed by pinning
  `asyncio_default_fixture_loop_scope`/`asyncio_default_test_loop_scope` to
  `"session"` — and in fixing it, found and fixed a second latent
  ordering hazard: `tests/test_migrations.py`'s own fixture independently
  upgrades/downgrades the same database per test, which would have
  silently broken a naively session-scoped "upgrade once" schema fixture
  the first time pytest's file collection order interleaved the two test
  files. Resolved by making the shared `db_schema` fixture idempotent
  (upgrade-if-needed, every test, no single shared teardown) rather than
  "run once per session."
- Attempted to also verify via the full Docker Compose stack (`docker
  compose up -d --build api`); the container built successfully but
  couldn't bind host port 8000 (claimed by an unrelated process in this
  sandbox — the same pre-existing conflict noted in the ZD-M1-02 report).
  Not pursued further: the native `pytest -m db` suite already exercises
  the complete FastAPI app against real Postgres and Redis end-to-end via
  ASGI transport, which is a more thorough check than a bare `curl
  /health` would have been anyway.

## Follow-ups / Deferred
- ZD-M1-04 (Paynow webhook) can start independently of this task.
- ZD-M1-05 (order state machine + SSE) is now unblocked — needs
  `iam.users` and `catalog.restaurants`, both of which exist.
- Refresh-token rotation, phone-number OTP verification at registration,
  and rate limiting on order creation/promo redemption are explicitly not
  built yet — tracked as open items, not silently skipped.
- Whether the 30-day JWT lifetime is actually acceptable, versus adding a
  refresh-token flow sooner, is a product/security tradeoff worth a
  deliberate decision rather than inheriting this task's default.

## References
- `docs/security/threat_model.md` Section 3/4 (the rate-limiting
  requirement this task closes).
- `docs/architecture/database_design.md` Section 2.1, ADR-003.
- Prior reports: `ZIM_DASH-2026-10-27-fastapi-boilerplate-init.md`
  (ZD-M1-02), `ZIM_DASH-2026-10-27-db-schema-init.md` (ZD-M1-01).

---

**Completed By:** Tinotenda Mupezeni (with Claude Code)
**Duration:** ~2 hours

# ZIM DASH Paynow Webhook Verification Endpoint (ZD-M1-04)

**Date:** 2026-10-27
**Project:** ZIM DASH
**Type:** Feature (payments)
**Status:** Completed

## Summary
Implemented ZD-M1-04: a verified Paynow status-update webhook that writes
`orders.orders.payment_status`. Hash verification was checked byte-for-byte
against Paynow's own published worked example before being trusted, and the
handler follows Paynow's own recommendation to poll the transaction back
for confirmation before acting on a payment-moved status, not just the
pushed message.

## Context / Trigger
Independent, non-blocking task per `tasks.md`'s dependency notes (only
ZD-M1-14, ledger posting, depends on this one). Before implementing,
cross-checked the task against the Risk Register and found a real tension
worth surfacing rather than silently resolving either way.

## Scope
In scope: hash verification, poll-back confirmation, and writing
`payment_status` on a matched order. Out of scope, by the task's own
boundary and `tasks.md`'s sequencing: the order-lifecycle state machine
(`orders.status`, ZD-M1-05) and ledger posting (ZD-M1-14, which explicitly
depends on this task plus ZD-M1-13's ledger schema) — this endpoint never
touches either.

## Decisions & Findings
- **Risk Register R-1 vs. the task's own naming.** R-1 ("No EcoCash
  aggregator (e.g. Paynow) integration chosen... Resolve aggregator choice
  and settlement terms before committing to a Phase 1 launch date") is
  scored High/Critical and explicitly unresolved; `project_plan.md`'s Task
  1.1 ("Select EcoCash aggregator") is separately listed as "blocked on
  Risk R-1." Yet `tasks.md`'s ZD-M1-04 title, `project_plan.md`'s Task 1.2,
  `system_design.md`, and `threat_model.md` all name Paynow specifically,
  never "an aggregator." Raised this directly rather than picking a side
  silently; confirmed building the real Paynow integration, since it's
  consistently the working assumption everywhere and has a genuinely
  public, well-documented API — R-1's blocker reads as a commercial/
  contract matter (settlement terms, who signs), not a reason the
  engineering itself should stall. Flagging here in case R-1 resolves to a
  different aggregator later: this task's *shape* (webhook, hash-verify,
  poll-confirm, write one column) transfers; the hash algorithm and field
  names are Paynow-specific and would need redoing.
- **Verified the hash algorithm against the vendor's own test vector, not
  a description of it.** Fetched Paynow's "Validating a hash on an inbound
  message" page, extracted its sample message/integration key/expected
  hash in several pieces (a single fetch couldn't quote the full 128-char
  hash or message due to a source-quoting limit), reassembled them, and
  computed the hash independently with a throwaway script *before* writing
  the real implementation — confirmed an exact match. This is the
  difference between "I read how the algorithm works" and "I checked my
  code produces the vendor's own published answer."
- **Two Paynow integration styles exist and disagree on hashing.** An
  older "Custom Button Template" product (capitalized field names like
  `Paynow_Reference`, `Customer_Name`; key+value hashing) is a different
  integration path from the REST "Initiate Transaction" API (lowercase
  `reference`/`paynowreference`/`status`/`pollurl`/`hash`; values-only
  hashing) this schema and the rest of the docs clearly assume. Confirmed
  the field list against the dedicated `status_update.html` page rather
  than assuming from the hash-algorithm sample alone (which also carried a
  `browserurl` field not part of the actual webhook payload).
- **Poll-back before trusting a payment-moved status is Paynow's own
  stated recommendation**, not an invented hardening step — their
  `status_update.html` page advises confirming via `pollurl` for updates
  that matter, specifically naming a payment having been made as the
  example. Implemented this for Paid/Awaiting Delivery/Delivered/
  Cancelled/Refunded; the polled result, not the pushed one, is what gets
  written.
- **A payment-status value with no DB-level CHECK constraint.** ZD-M1-01
  left `payment_status` as a bare `VARCHAR(16)` with no `CHECK`, unlike
  `currency`/`payment_method` on the same table. Followed that existing
  design rather than unilaterally adding a constraint in an unrelated
  task — the allowed values (`PENDING`/`PAID`/`CANCELLED`/`REFUNDED`) are
  enforced only in `app/core/paynow.py`'s status-mapping sets for now.

## Changes Made
- `app/core/paynow.py` — `_parse_raw`/`verify_and_parse` (hash check +
  field extraction, split so the vendor's hash-only sample can be tested
  against the real algorithm without also needing a `reference`/`amount`
  it doesn't carry), `confirm_via_poll`.
- `app/api/payments.py` — `POST /payments/paynow/webhook`.
- `app/core/config.py` — `paynow_integration_id`/`paynow_integration_key`
  (dev placeholder; the key defaults to Paynow's own published *public*
  test-vector key, not a real secret).
- `app/db/session.py` — `connect_args={"statement_cache_size": 0}` (see
  Verification below for why).
- `tests/test_paynow.py` (5 unit tests, no DB needed — includes the
  vendor's own worked example as a literal test vector) and
  `tests/test_payments.py` (4 DB-integration tests).
- `pyproject.toml` — `httpx` moved from dev-only to a runtime dependency
  (now used for the poll-back, not just tests).
- Commit `0339902`, pushed to `origin/main`.

## Verification
- `ruff check .`, `black --check .` — clean.
- `pytest` (default, no DB) — 6/6 passing, including the vendor-sample
  hash-verification test.
- `pytest -m db` — 19/19 passing (12 auth + 3 migrations + 4 new payment
  tests): a correctly-hashed Paid update (with a mocked poll-back) marks
  the matched order `PAID`; a tampered/invalid hash is rejected with the
  order left untouched; a poll-back that disagrees with the pushed status
  (mocked to return Cancelled against a pushed Paid) results in the
  *polled* status being written, proving the poll-confirmation step is
  load-bearing and not just logged; an unknown `reference` is acknowledged
  (200) without erroring.
- **Found and fixed a real bug, not just a test-environment quirk**, while
  running the full integration suite together: `sqlalchemy.exc.
  InternalError: cache lookup failed for type 19747` on the very first
  insert touching `iam.identity_type` in a new test file. Root cause:
  asyncpg caches a prepared statement's column/enum type OIDs per
  connection; `tests/test_migrations.py`'s own tests independently
  downgrade/upgrade the schema (dropping and recreating the ENUM types
  with new OIDs each time), and the async engine's long-lived connection
  pool — a module-level singleton, same one the live app uses — had cached
  the *old* OID before that happened. This is not test-only: the identical
  failure mode would hit a real, running API process during a rolling
  deploy that includes a migration touching an ENUM type, until that
  process's connections happened to cycle. Fixed by disabling asyncpg's
  statement cache on the shared engine.

## Follow-ups / Deferred
- ZD-M1-05 (order state machine + SSE) is now unblocked — needs
  `iam.users`, `catalog.restaurants`, and this task's `payment_status`
  column, all of which exist.
- ZD-M1-14 (ledger posting on payment completion/refund) depends on this
  task plus ZD-M1-13 (ledger schema, not yet built).
- Whether Paynow is the final aggregator (Risk R-1) is unresolved and
  outside engineering's control; flagged in both the commit and here so a
  later reader isn't surprised the "real" integration might still need
  replacing.
- No `CHECK` constraint on `payment_status`'s allowed values at the DB
  layer — consistent with ZD-M1-01's existing design, not a gap introduced
  here, but worth a look if a future migration touches that column anyway.

## References
- `docs/planning/risk_register.md` R-1 (the aggregator-choice tension).
- `docs/security/threat_model.md` (payment verification happens
  server-side, per ADR-005).
- `developers.paynow.co.zw/docs/validating_hash.html` (hash algorithm +
  worked example), `.../docs/status_update.html` (field list, status
  values, poll-back recommendation).
- Prior reports: ZD-M1-01 (db-schema-init), ZD-M1-02
  (fastapi-boilerplate-init), ZD-M1-03 (jwt-auth) — same session.

---

**Completed By:** Tinotenda Mupezeni (with Claude Code)
**Duration:** ~2 hours

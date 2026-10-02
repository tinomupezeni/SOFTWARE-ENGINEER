# Payment routes had no transaction commit - writes never actually persisted

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
`POST /api/payments/initialize` and `POST /api/payments/webhook/zb` had no
`@transactional()` decorator, and `PaymentService` only ever calls
`self.db.flush()`, never `.commit()`. Since `get_db()`'s session is
`autocommit=False` and its `finally: db.close()` rolls back anything not
explicitly committed, a successful payment initialization would flush
the new `Payment` row within the request's transaction (visible to
later queries in the same request) but silently discard it the moment
the request finished and the session closed. Confirmed this had never
actually worked by checking the `payments` table in production: 0 rows,
despite the code being written with clear intent to persist one per
initialization.

## Symptoms
- Not reported by a user - found during a backend audit specifically
  flagged in an earlier session as the single highest-risk item (real
  money, zero atomicity guarantee), then investigated properly this
  session.
- `SELECT count(*) FROM payments` / `SELECT count(*) FROM orders` both
  returned 0 before this fix, consistent with (though not solely proof
  of) the bug - this is a pre-launch app with testers only, so an
  unexercised payment flow was also plausible on its own.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-store-api`
  container, `tese_store` database)
- **Services Affected:** Payment initialization and the ZB webhook
  callback - any real checkout attempt
- **Related Components:**
  `apps/store-api/app/modules/orders/routes/payment.py`,
  `apps/store-api/app/modules/orders/services/payment_service.py`
- **Time First Observed:** 2026-10-02

## Investigation Steps

### 1. Initial Diagnosis
Read `payment.py`'s two routes directly - neither had `@transactional()`,
unlike every route in `order.py` (which uses it on every write).

### 2. Root Cause Analysis
Read `PaymentService.initialize_order_payment`/`verify_transaction` and
found only `self.db.flush()` calls, no `self.db.commit()` anywhere in the
call chain. Checked `get_db()` in `app/database.py`: a plain
`StoreSessionLocal()` with `try: yield db; finally: db.close()` - no
commit, no autocommit mode. Confirmed this means an uncommitted
transaction's writes are rolled back when the session closes, by
checking `payments`/`orders` row counts in production (both 0).

### 3. Key Findings
- `catalog.py`, `auth.py`, and `order.py` all follow a consistent
  pattern: service layer `flush()`es, route-level `@transactional()`
  commits. `payment.py` was the one place this pattern was skipped
  entirely.
- The payment gateway itself (`ZBGateway` in `payment_gateway.py`) is
  currently a stub/mock (always returns `success: True`, never makes a
  real HTTP call to ZB) - a separate, pre-existing fact, not something
  this fix addresses or needed to address; the DB-persistence bug exists
  independently of whether the gateway integration is real.

## Root Cause
The two payment routes were written without the `@transactional()`
decorator that every other write-path route in this app uses, and the
service layer's `flush()`-only pattern depends entirely on that
decorator (or an equivalent) to ever actually commit.

## Prevention / Rule
**Guardrail:** Any route that creates/mutates a model via a service
calling `db.flush()` must have `@transactional()` (or an equivalent
explicit commit) - there is no other commit path in this codebase. A
grep for `db.flush()` with no `@transactional()` anywhere in the same
route module is a direct signal of this exact bug.

## Solution

### Immediate Fix
`apps/store-api/app/modules/orders/routes/payment.py`:
```python
from tese_common.database.transactions import transactional
...
@router.post("/initialize", response_model=PaymentResponse)
@transactional()
async def initialize_payment(...): ...

@router.post("/webhook/zb")
@transactional()
async def zb_webhook(...): ...
```

```bash
python3 -m py_compile app/modules/orders/routes/payment.py   # clean
```
Verified end-to-end in production with a real test account: registered,
logged in, added an item to cart, created an address, created an order,
called `/api/payments/initialize` - confirmed via direct DB query that
the `Payment` row persisted (`status: PENDING`). Then called
`/api/payments/webhook/zb` with that payment's reference - confirmed
both the `Payment` row updated to `COMPLETED` and the linked `Order`
updated to `status: PAID` / `payment_status: COMPLETED`, both persisted.
First time this entire flow has worked end-to-end.

### Long-term Fix
None needed beyond the fix itself - this was a straightforward missing-
decorator bug, now consistent with every other write route in the app.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `reports/tese-marketplace-2026-10-02-database-hardening-transactions-engines-fks.md`
  (the initiative this was fixed under)
- `Backend_and_API/tese-marketplace-2026-10-02-dual-session-consistency-gap.md`
  (a related transactional-consistency gap found in the same pass)

## References
- `apps/store-api/app/modules/orders/routes/payment.py`
- `apps/store-api/app/modules/orders/services/payment_service.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~20 minutes from investigation to verified fix in production

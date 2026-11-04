# Pre-existing test failures: trust-hardening tests never updated after public_id migration

**Date:** 2026-11-04
**Project:** SWAP-O-SELL
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
While verifying a change to `modules/listings/views.py` and `serializers.py`
(adding `distance_km`), ran the full `modules.listings` test suite as a
sanity check and found 4 pre-existing failures on `main` (confirmed via
`git stash`, unrelated to this session's change). Not fixed — flagging for
the owning team since the fix touches test fixtures across several test
cases, out of scope for the change this session made.

## Symptoms
- `test_fee_tiers_snapshot_on_create`, `test_full_order_lifecycle_with_otp`,
  `test_stock_confirm_seller_only` (all in `modules/listings/tests.py`,
  `TrustHardeningTests`) fail with `404 Product not found` instead of their
  expected `201`/`403`.
- `test_home_sections_validate_partial_location`
  (`modules/listings/test_search.py`) fails with `200 != 400`.

## Environment Details
- **Server/Host:** local dev (sqlite, Python 3.14, fresh venv)
- **Services Affected:** `backend` test suite (`modules.listings`)
- **Related Components:** `modules/listings/tests.py`,
  `modules/listings/test_search.py`, `modules/listings/views.py`
  (`orders`, `home_sections`)
- **Time First Observed:** 2026-11-04, running `python manage.py test
  modules.listings` for the first time locally

## Investigation Steps

### 1. Initial Diagnosis
```bash
python manage.py test modules.listings
```
4 failures out of 23 tests. Confirmed pre-existing (not caused by this
session's edits) by stashing the session's diff and re-running the same 4
tests against clean `main` — same 4 failures, same assertions.

### 2. Root Cause Analysis
For the three `TrustHardeningTests` failures:
```bash
grep -n "def orders" -A 40 modules/listings/views.py | grep -n "Product.objects.get"
# -> Product = Product.objects.get(public_id=request.data.get('product_id'))
```
`make_product()` in `tests.py` and the test bodies pass `p.id` (the
internal integer PK) as `product_id` in the request payload, but the
`orders` view looks products up by `public_id` (a UUID, added in migration
`swapapp.0005_public_uuid_ids`). The lookup never matches `p.id`, so every
request 404s before reaching the assertion under test.

For `test_home_sections_validate_partial_location`: the test sends only
`lat` with no `lng` and expects `400`, but `home_sections()` only validates
when *both* `lat` and `lng` are present (`if raw_lat is not None and
raw_lng is not None:`) — a single param is silently treated as "no
location" and returns `200`. The test's expectation doesn't match the
view's actual (and, arguably, reasonable) contract.

### 3. Key Findings
- The three `TrustHardeningTests` failures are test-fixture drift: the
  `public_id` migration changed the API's product-lookup key but the test
  fixtures were never updated to match, so they've likely been broken since
  that migration landed.
- The `test_home_sections_validate_partial_location` failure is a
  test/behavior mismatch, not obviously a bug in the view — worth a product
  call on whether partial lat/lng should 400 or silently ignore.

## Root Cause
Test fixtures and assertions were not updated when `swapapp.0005_public_uuid_ids`
changed the public product identifier used by request payloads, and a
second test encodes a stricter validation contract than the view actually
implements.

## Prevention / Rule
**Guardrail:** Add this suite to CI (if not already wired) so public-facing
contract changes like a PK-to-UUID migration fail the build immediately via
the test fixtures that exercise the changed endpoint, instead of surfacing
only when someone happens to run the suite locally months later.

Running the existing test suite in CI on every PR would have caught this
the same day the `public_id` migration merged, instead of it sitting
broken and undetected.

## Solution

### Immediate Fix
None applied — left as-is, out of scope for the `distance_km` change this
session made. Noted here so it isn't lost.

### Long-term Fix
- Update `make_product()`/test bodies in `modules/listings/tests.py` to
  send `str(p.public_id)` instead of `p.id` as `product_id` in request
  payloads.
- Decide and align `home_sections()` and its test: either make partial
  lat/lng a 400 (match `listings()`'s `or`-based check) or update the test
  to accept the silent-ignore behavior.

## Prevention
- [ ] Configuration changes needed — add/verify CI runs `manage.py test`
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [ ] Code changes required — `modules/listings/tests.py`,
      `modules/listings/test_search.py` (or `views.py` for the validation
      mismatch)

## Related Issues
- None filed yet.

## References
- `backend/swapapp/migrations/0005_public_uuid_ids.py`
- `backend/modules/listings/tests.py`
- `backend/modules/listings/test_search.py`
- `backend/modules/listings/views.py` (`orders`, `home_sections`)

---

**Resolved By:** Not resolved — logged by Claude (session with tinomupezeni) for follow-up
**Time to Resolution:** n/a (investigation only, ~15 minutes)

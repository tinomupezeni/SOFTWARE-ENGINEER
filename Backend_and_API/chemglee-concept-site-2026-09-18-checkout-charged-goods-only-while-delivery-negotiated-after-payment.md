# Checkout Charged for Goods Only While Calling It "Estimated Total," Then Negotiated Delivery After the Customer Had Already Paid

**Date:** 2026-09-18
**Project:** chemglee-concept-site
**Environment:** Production
**Severity:** Critical (real customers were charged an amount that was never the amount owed; no terms-of-service acceptance was ever captured on a card-payment flow)
**Status:** Resolved (merged to `main` via PR #4 and PR #5 — the same fix, committed independently on two branches; see the merge note below)

## Summary
The cart offered "Pay Now," sending the shopper to Paynow for `cartTotal` —
goods only — while the same panel read "Estimated Total" and "Delivery is
quoted separately." The amount actually charged was therefore never the
amount owed, and the delivery charge had to be argued about with the
customer *after* they'd already paid. There was nowhere to even record a
delivery charge: `Order.total` was purely the sum of line items, and
checkout collected a free-text "Delivery note" but no address. Separately,
from the same audit: the shop had never asked anyone to accept any terms
before taking a card payment, and auth/checkout forms used placeholders
instead of real `<label>` elements (a screen reader has nothing to announce
for a placeholder, and it disappears the moment someone types).

## Root Cause
`Order.total` was defined as "sum of line items" with no concept of
fulfilment method or a priced delivery leg, so the UI's only honest options
were to omit delivery from the charged total (what it did) or block online
payment entirely. Terms acceptance and real form labels were simply never
built as part of the original checkout/signup flow.

## Solution
An order now knows how it's being fulfilled (`fulfilment`: unspecified /
delivery / collection). Collection is priced exactly at checkout, so paying
online for a collection order is honest and "Pay Now" stays available.
Delivery cannot be priced at checkout (it depends on address and volume), so
that path submits an order request instead; staff set `delivery_fee` and
tick "Delivery charge confirmed" in the admin, and only then can the
customer pay — for a total that now includes delivery.
`payments.start_payment()` refuses to start a payment for any order that
still `needs_delivery_quote`, raising a specific `DeliveryNotQuoted` (409),
so this holds even for a request that skips the cart UI entirely. The
WhatsApp hand-off path sends no fulfilment at all and lands as "not yet
agreed," which is equally unpayable. Quote requests are exempt (a quote was
never a bill). Existing orders default to "not yet agreed," so a pre-existing
order can't be paid online until someone explicitly confirms its delivery
cost. Terms acceptance is now required at sign-up and checkout, recorded
with a timestamp against the account; marketing consent is a separate,
default-off checkbox. Placeholder-only fields became real `<label>`s.

## Merge Note
This fix landed as one commit, authored once but present with an identical
content hash (`git patch-id`) on two separately-opened branches/PRs
(`feat/admin-ux-postgres`, PR #4, and `feat/delivery-quote-gate`, PR #5).
Both were merged to `main` in this session; the second merge was a verified
no-op (see this repo's own commit `439298e` on `chemglee-concept-site` for
the reasoning) — recorded here once rather than as two entries.

## Prevention
- [ ] Consider a regression test that asserts `Payment.amount` (or the
      amount actually sent to Paynow) always equals `Order.total` including
      `delivery_fee` for every payable order — the exact invariant this bug
      violated.

## References
- Commits `2f5d2ce`/`b47f995` ("Never charge for an order whose delivery we
  haven't priced yet"), merged to `main` via commits `8bcc3dd` and
  `439298e` in this session.
- `backend/apps/orders/models.py` (`Order.fulfilment`, `.delivery_fee`,
  `.delivery_quoted`, `.needs_delivery_quote`), `payments.py`
  (`DeliveryNotQuoted`), `backend/apps/accounts/models.py`
  (`accepted_terms_at`, `marketing_opt_in`), `frontend/src/routes/cart.tsx`,
  `register.tsx`

---

**Resolved By:** winstonjthinker + Claude Opus 5 (1M context), PR #4 / PR #5
**Time to Resolution:** N/A (site audit)

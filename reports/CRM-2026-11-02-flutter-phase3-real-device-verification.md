# Flutter Mobile Rebuild — Phase 3 Real-Device Verification

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** Verification / Closes a Follow-up from a Prior Report
**Status:** Completed

## Summary
Ran the Phase 3 (POS/Checkout) flow end-to-end on a real Android device
(wirelessly paired, per
`DevOps_and_Infrastructure/DevEnv-2026-11-02-adb-wireless-pairing-port-confusion.md`)
against a live Django backend on the LAN, closing the "not yet done — the
actual pilot-critical gate" item from
`CRM-2026-11-02-flutter-mobile-rebuild-phase3-pos-checkout.md`. Login,
product browsing, cart, customer search, checkout, and sale completion all
worked correctly, verified not just visually but against the backend's own
database (sale record + stock-movement ledger).

## Context / Trigger
Direct continuation of the prior session: the user asked to wirelessly
pair their phone, then asked to actually run the app on it and test POS
end-to-end, since that device test was explicitly the one thing Phase 3's
report said was still missing.

## Scope
Included: standing up the Django backend + Postgres via Docker on the LAN
(`docker compose up db backend`, mapped to host port 8020), migrating +
seeding demo data, building and installing a debug APK on the physical
device with `--dart-define=API_BASE_URL` pointed at the host machine's LAN
IP, and manually driving the full checkout flow via `adb shell input` +
screenshots, then verifying the result via direct API calls against the
backend.

Excluded: barcode scanning, Bluetooth printer support (same reasoning as
the original Phase 3 report — still deferred, unrelated to this
verification pass).

## Method
Backend: `docker compose up -d db backend` → `migrate` → `seed_data`
(creates `demo`/`demo1234` and seeded contacts/products/sales) →
confirmed `/health/` reachable from both `localhost:8020` and the host's
LAN IP (`192.168.60.242:8020`), since the phone needs the LAN address, not
`10.0.2.2` (emulator-only) or `localhost`.

Mobile: `flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.60.242:8020`,
installed via `adb install -r`, launched via `adb shell am start`. Drove
the UI via `adb shell input tap`/`text` plus `adb exec-out screencap`,
reading back each screenshot to decide the next action — a fully real,
non-synthetic interaction path (distinct from the widget tests, which
dispatch gestures directly through the widget tree and can't by
themselves prove real touch/network/device behavior).

## Decisions & Findings
- **The one real snag was mine, not the app's**: partway through, taps on
  the bottom navigation bar appeared to do nothing. Investigation (ADB's
  `pointer_location` overlay, then pixel-level analysis of screenshots
  with PIL) showed the taps were landing nowhere near the nav bar — I had
  been consistently misjudging where UI elements sat in the screenshot's
  displayed (resized) coordinate space when converting by hand to real
  device pixels. Once addressed by measuring exact pixel bands
  programmatically rather than eyeballing the rendered preview, every tap
  landed correctly and the app behaved exactly as built. No code change
  was needed — this is a testing-methodology note, not a bug in the CRM
  or SOFTWARE-ENGINEER codebases, so it isn't filed as a bug-log entry.
- **Verified server-side, not just visually**: after completing the sale
  in the app, queried the backend directly (`GET /api/v1/sales/?search=...`,
  `GET /api/v1/products/{id}/stock_history/`) to confirm the sale record
  and the exact matching stock-movement ledger entry — the kind of check
  a screenshot alone can't provide.

## Changes Made
No application code changes. Backend bring-up (Docker containers,
migrations, seed data) was operational, not a code change.

## Verification
- Login (JWT) against the real backend: pass.
- Stock tab (Product list, search, low-stock filter): renders real seeded
  product data correctly.
- Sales tab (POS): product list → add-to-cart sheet → cart summary bar
  with running total: all correct.
- Checkout: customer search (found a real seeded contact, "Tatenda
  Moyo"), currency selector (USD), payment status (Paid): correct.
- Sale completion: `POST /api/v1/sales/` succeeded, receipt screen showed
  sale number `S-000006`, correct totals.
- **Backend-side confirmation**: `GET /api/v1/sales/?search=S-000006`
  returns the sale with `contact_name: "Tatenda Moyo"`, `total_amount:
  "7.00"`, `payment_status: "paid"`, `balance_due: "0.00"`. `GET
  /api/v1/products/{id}/stock_history/` shows the matching movement
  (`movement_type: "out"`, `quantity: 1`, `reference: "Sale #S-000006"`),
  and the product's `quantity_in_stock` dropped from 46 to 45 — the
  decrement matches the sale exactly.

## Follow-ups / Deferred
- Barcode scanning and Bluetooth printer support remain deferred (need
  the actual physical test POS machine/hardware, not just any Android
  phone).
- This was one manual pass by one operator, not a structured usability
  session with the actual intended cashier/user — still worth a real
  pilot walkthrough with the boss's staff before calling Phase 3 fully
  signed off for the pilot.

## References
- `CRM-2026-11-02-flutter-mobile-rebuild-phase3-pos-checkout.md` (the
  report this closes a follow-up from)
- `DevOps_and_Infrastructure/DevEnv-2026-11-02-adb-wireless-pairing-port-confusion.md`
- `backend/apps/accounts/management/commands/seed_data.py`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session

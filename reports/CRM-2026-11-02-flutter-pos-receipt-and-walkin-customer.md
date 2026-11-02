# Flutter Mobile — Shareable Receipt and Walk-in Customer Entry

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed, verified on real device

## Summary
Added a real, visual till-receipt to the POS checkout flow (styled to match
a reference "cash receipt" image the user provided: organization header,
address/phone, dashed dividers, line items, totals, "THANK YOU", and a
scannable barcode of the sale number), shareable as an actual image through
the OS share sheet (WhatsApp included) rather than the previous text-only
`wa.me` link. Also replaced the walk-in-customer quick-add's single
"phone-as-name" hack with a real Name + Phone form.

## Context / Trigger
User request, with a reference image of the desired receipt layout: "lets
actually have an actual receipt generated that can be shared to whatsapp
with the client and for each sale they can enter the client name and phone
number, with the organisation name."

## Scope
Included: `Organization.address`/`.phone` backend fields (+ migration +
serializer), a proper walk-in-customer form (Name + Phone, replacing the
old single-field hack), the `ReceiptCard` widget and image-capture/share
flow, `createdAt` added to `SaleEntity`/`SaleModel` for the receipt's
date/time.

Excluded: WhatsApp Business API integration (sending directly to a
specific number with no user interaction) — not possible from a client
app without that API; the OS share sheet (user picks WhatsApp, then picks
the chat) is the correct and only available mechanism here. The previous
`wa.me`-link text-share code path in `SaleRepository`/backend
`share_whatsapp` action was left in place (tested, unused by this new UI)
rather than removed, since it's a reasonable fallback for a future
text-only share action.

## Method
Read the `Organization` and `Sale`/`SaleItem` Django models directly before
adding fields, to confirm there was no tax/VAT concept in the data model
(CLAUDE.md and prior research already mark ZIMRA/payment-compliance as
out-of-scope) — the receipt template was adapted to show Total/Paid/
Balance rather than a fabricated "Sales Tax" line the backend has no data
for.

Built the receipt as a native Flutter widget (not a server-rendered PDF —
the existing `backend/.../invoice_pdf.html` template is a different,
formal-invoice layout) wrapped in a `RepaintBoundary`, captured to PNG via
`toImage()`, written to a temp file, and handed to `share_plus`'s
`Share.shareXFiles`. Verified the whole pipeline on the real paired
Android device, not just via widget tests, including confirming the
native share sheet actually received the image (not just that no
exception was thrown).

## Decisions & Findings
- **Receipt breakdown uses Total/Paid/Balance, not Sub-total/Tax/Balance**
  as in the reference image, because the backend genuinely has no tax
  field — showing a fake `0.00` tax line would misrepresent real data.
- **Barcode encodes the sale number** (`Barcode.code128()` via
  `barcode_widget`), giving the receipt a real scannable code, not a
  decorative stripe pattern.
- **Found and fixed a real Flutter focus bug** while building the new
  walk-in-customer form: the first `TextField` in the form never opened
  the keyboard on tap (only the second one did), reproducibly, across
  multiple fresh app installs. Root-caused to Flutter silently granting a
  freshly-built subtree's first focusable node framework-level focus
  without an actual platform IME connection, so the user's first tap was
  a no-op focus-wise. Full write-up and guardrail in the dedicated bug-log
  entry (see References). This is a reusable lesson for any future screen
  that swaps content inside an already-focused modal route.
- **Extended `ContactRepository.quickCreate`** to accept `lastName` (the
  backend `ContactSerializer` already supported it; only the mobile client
  wasn't using it) rather than inventing a new endpoint.
- **Session testing hit two unrelated automation gotchas** (documented so
  they don't eat time again): (1) a long real-device session with heavy
  `adb shell input` traffic can leave a `flutter run`-attached session in
  a state where *programmatic* autofocus still works but manual tap-to-
  focus silently fails everywhere — a full `am force-stop` + relaunch
  clears it; this is a test-harness quirk, confirmed unrelated to the real
  bug above since the real bug reproduced identically on fresh installs.
  (2) Screenshot-to-tap coordinate conversion needs the stated display
  scale factor applied consistently — eyeballing a resized preview image
  and skipping the multiply is an easy, repeated mistake; measuring pixel
  bands with PIL directly on the raw (un-resized) screenshot file is the
  reliable method.

## Changes Made
- `backend/apps/accounts/models.py` — `Organization.address`, `.phone`.
- `backend/apps/accounts/migrations/0004_organization_address_organization_phone.py`.
- `backend/apps/accounts/serializers.py` — exposed the new fields.
- `backend/apps/accounts/management/commands/seed_data.py` — seeds a
  realistic demo address/phone.
- `mobile_flutter/lib/features/auth/{domain,data}/.../organization_{entity,model}.dart`
  — `address`/`phone`.
- `mobile_flutter/lib/features/sales/domain/entities/sale_entity.dart` +
  `.../data/models/sale_model.dart` — added `createdAt`.
- `mobile_flutter/lib/features/contacts/{domain,data}/...` — `quickCreate`
  now accepts `lastName`.
- `mobile_flutter/lib/features/pos/presentation/widgets/contact_picker_sheet.dart`
  — rewritten with a real "New customer" Name+Phone form (plus the focus
  fix above).
- `mobile_flutter/lib/features/pos/presentation/widgets/receipt_card.dart`,
  `dashed_divider.dart` — the receipt UI.
- `mobile_flutter/lib/core/utils/share_image.dart` — `RepaintBoundary` →
  PNG → OS share sheet helper.
- `mobile_flutter/lib/features/pos/presentation/screens/sale_receipt_screen.dart`
  — now renders `ReceiptCard` and shares it as an image instead of the old
  text-only `wa.me` link button.
- `pubspec.yaml` — added `barcode_widget`, `share_plus`, `path_provider`.
- New/updated tests: `test/features/pos/receipt_card_test.dart`,
  `test/features/pos/contact_picker_sheet_test.dart`.

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — 72/72 passing.
- **Real-device verification** (not just widget tests): logged in, added a
  product to cart, opened checkout, used the new Name+Phone walk-in form
  (both fields focus and accept input correctly — including the keyboard
  bug found and fixed above), completed a real sale against the live
  backend, confirmed the rendered receipt matched the reference image
  (organization name/address/phone, items, total, barcode showing the real
  sale number), tapped "Share receipt via WhatsApp," and confirmed via
  `adb logcat` + screenshot that Android's native share sheet opened with
  the actual receipt image attached and WhatsApp listed as a direct share
  target.

## Follow-ups / Deferred
- Consider exposing `Organization.address`/`.phone` as editable fields in
  a future "organization settings" screen (currently only settable via the
  seed command or a direct `PATCH /api/v1/accounts/organization/` call).
- The old `wa.me`-link share path (`SaleRepository.getWhatsappReceiptLink`)
  is now unused by any UI — revisit whether to keep it as a text-only
  fallback or remove it once there's a concrete second use case.

## References
- `CRM-2026-11-02-flutter-phase3-real-device-verification.md`
- `Frontend_and_UI/CRM-2026-11-02-flutter-first-field-silent-focus-no-keyboard.md`
- `backend/apps/accounts/models.py`, `backend/apps/sales/models.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/pos/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session

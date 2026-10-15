# Swap-O-Sell Upload Product HCI Refactor

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** HCI Audit / UX Refactor
**Status:** Completed

## Summary
Reworked the add-product flow to reduce clutter and make the primary seller
task easier to complete. Required listing information is now grouped into a
short publish path, while payments, fulfilment, stock confirmation, warranty,
and tags are available through progressive disclosure as optional details.

## Context / Trigger
The user reported that the add-product page was too cluttered. The previous
form displayed images, product information, commerce requirements, fulfilment
operations, trust controls, and search metadata as one uninterrupted sequence.

## Scope
Included the upload/edit form information architecture, field labels,
responsive layout, image controls, optional-details disclosure, and submit
behavior. Preserved the existing backend payload and all trust-related fields.
Excluded backend schema changes, payment policy changes, image-processing
changes, and browser usability testing with external users.

## Method

1. Read the HCI guide sections on working-memory limits, chunking,
   progressive disclosure, visibility, error prevention, feedback, and
   accessibility.
2. Traced the existing upload form fields and backend payload contract.
3. Grouped fields by the seller's task sequence:
   photos, item description, price/category, condition/location, then
   optional operational details.
4. Reduced competing labels and rewrote prompts around buyer intent.
5. Added clearer image status, cover-image indication, semantic labels,
   larger remove controls, and responsive spacing.
6. Removed duplicate publish-event wiring, built the frontend, and verified
   the Docker-served application and API health endpoint.

## Decisions & Findings

- The required path is now visible without forcing sellers to process every
  marketplace policy field at once.
- “What are you selling?” and “Where can buyers find it?” are more task
  oriented than implementation-oriented labels.
- Photos show a `0/5` status and identify the first image as the cover.
- Description guidance explains what buyers need to know without requiring a
  separate help document.
- Optional details remain discoverable and editable; they were not removed
  from the workflow or payload.
- The publish action is now a single form submit path, preventing duplicate
  listing mutations.

## Changes Made

- `swappify-social-hub/src/pages/UploadProduct.tsx`
  - Reorganized the form into required and optional sections.
  - Added progressive disclosure for operational details.
  - Improved image previews, cover labeling, removal affordances, and count.
  - Added semantic input labels and responsive commerce styling.
  - Renamed the primary action to `Publish listing` for creation and
    `Save changes` for editing.
  - Removed duplicate submit click handling.
- `Frontend_and_UI/SWAP-O-SELL-2026-10-15-upload-product-double-submit-handler.md`
  - Logged the resolved duplicate-submit defect.

## Verification

- `npm run build` passed.
- `git diff --check` passed for `UploadProduct.tsx`.
- Docker frontend image rebuilt successfully.
- `http://localhost:8080/` returned HTTP 200.
- `http://localhost:8080/api/health/` returned
  `{"ok": true, "service": "swap-o-sell"}`.
- Existing backend payload field names were preserved.

## Follow-ups / Deferred

- Run browser-based task testing at mobile and desktop widths.
- Add a visible progress/error summary for failed image uploads.
- Consider making the optional-details section open automatically when an
  existing listing contains saved operational values.
- Add browser tests for image limits, edit mode, optional fields, and
  duplicate-submit prevention.

## References

- `Principal_Engineer/engineering-guides/12. HCI.md`
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/pages/UploadProduct.tsx`
- `/home/shadowe/Projects/swap-o-sell/backend/modules/listings/serializers.py`
- `Frontend_and_UI/SWAP-O-SELL-2026-10-15-upload-product-double-submit-handler.md`

---

**Completed By:** Copilot
**Duration:** One implementation session

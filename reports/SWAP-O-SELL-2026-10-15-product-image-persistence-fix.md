# Swap-O-Sell Product Image Persistence Fix

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Bug Fix / Integration Hardening
**Status:** Completed

## Summary
Fixed product image persistence so new listings upload actual image files
instead of storing browser-only preview URLs. Product cards now display a
single active image with thumbnail navigation and safely ignore invalid
browser-scoped URLs.

## Context / Trigger
The user reported that product images were not appearing and that cards
showed broken thumbnail labels for a listing. Investigation found `blob:`
URLs persisted in the database.

## Scope
Included the upload page, multipart API client, backend listing serializer,
and product-card image rendering. Removed only the unrecoverable invalid
image rows from the local development database. No production data or
unrelated listing fields were changed.

## Method

1. Traced the image lifecycle from file input to preview URL, multipart
   request, database record, API response, and card rendering.
2. Queried the local database to confirm the persisted values.
3. Corrected the transport boundary to send `File` objects.
4. Added server-side validation for browser-only URLs.
5. Corrected card rendering to select the active image rather than stacking
   all images.
6. Rebuilt the frontend/backend containers and verified the listing API and
   health endpoints.

## Decisions & Findings

- `URL.createObjectURL` remains appropriate for local previews but must never
  be sent as a persisted image URL.
- Multipart arrays are appended item-by-item so the backend receives the
  intended list rather than a stringified array.
- Product cards now use `currentImageIndex` for the main image, making the
  navigation controls functional.
- The previously affected listing has no recoverable image files; its images
  need to be re-uploaded by the seller.

## Changes Made

- `swappify-social-hub/src/pages/UploadProduct.tsx`
  - Sends `imageFiles` for new listing creation.
  - Excludes blob preview URLs from persisted URL payloads.
- `swappify-social-hub/src/server/Server.tsx`
  - Appends array form values individually and skips null values.
- `swappify-social-hub/src/components/ProductCard.tsx`
  - Filters browser-only URLs.
  - Displays the selected image and keeps thumbnails for navigation.
  - Shows a clear empty-photo state.
- `backend/modules/listings/serializers.py`
  - Rejects empty and `blob:` image URLs.
- Local database
  - Removed three unrecoverable browser-preview image rows.

## Verification

- `npm run build` passed.
- Backend Python compilation passed with `python3 -m compileall`.
- `docker compose exec -T backend python manage.py check` passed.
- `docker compose up --build -d frontend backend` passed.
- `http://localhost:8080/` returned HTTP 200.
- `http://localhost:8080/api/health/` returned
  `{"ok": true, "service": "swap-o-sell"}`.
- Listing API now returns no browser-scoped image URLs.

## Follow-ups / Deferred

- Re-upload the affected listing's original photos.
- Add an authenticated browser test for multi-image creation and reload.
- Add explicit upload failure feedback when the remote image provider rejects
  a file.
- Consider a durable local-media fallback if the external image provider is
  unavailable.

## References

- `Integrations_and_Auth/SWAP-O-SELL-2026-10-15-product-image-blob-url-persistence.md`
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/pages/UploadProduct.tsx`
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/components/ProductCard.tsx`
- `/home/shadowe/Projects/swap-o-sell/backend/modules/listings/serializers.py`

---

**Completed By:** Copilot
**Duration:** One implementation session

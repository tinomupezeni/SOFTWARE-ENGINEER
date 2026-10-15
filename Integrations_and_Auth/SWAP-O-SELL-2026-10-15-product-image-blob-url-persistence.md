# Product Images Persisted as Browser Blob URLs

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The product upload flow sent temporary browser preview URLs to the API as
listing image URLs. These `blob:` URLs are scoped to the browser session and
cannot be loaded by other pages, users, or later sessions, so uploaded
products displayed broken images and thumbnail labels without usable photos.

## Symptoms
- Product cards displayed broken image areas and thumbnail labels such as
  `Thumbnail 1`, `Thumbnail 2`, and `Thumbnail 3`.
- The affected product's stored `image_url` values began with
  `blob:http://localhost:8080/`.
- One multipart field also serialized multiple preview URLs into a single
  comma-separated string.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Frontend product upload and product listing display
- **Related Components:** `UploadProduct.tsx`, `Server.tsx`, `ProductCard.tsx`,
  `ProductCreateSerializer`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the listing API response, upload payload construction, and product
card image rendering.

### 2. Root Cause Analysis
Queried the local database for stored image URLs:

```bash
docker compose exec -T backend python manage.py shell -c \
  "from swapapp.models import Product; print([(p.id, list(p.product_images.values_list('image_url', flat=True))) for p in Product.objects.all()])"
```

The affected record contained browser-scoped `blob:` URLs. The upload page
created those URLs with `URL.createObjectURL(file)`, then passed the preview
URL array to `Server.addProduct` instead of passing `imageFiles`.

### 3. Key Findings
- Preview URLs were used as persistence data.
- The API client stringified arrays when appending multipart fields.
- Product cards rendered every image stacked at once and did not filter
  invalid browser-only URLs.
- The original browser blob URLs could not be recovered after the session.

## Root Cause
The frontend conflated display previews with durable upload data. It persisted
object URLs generated for local rendering instead of uploading the selected
`File` objects to the backend image storage integration.

## Prevention / Rule
**Guardrail:** Product creation must send image files through the multipart
`images` field; `images_urls` may contain only durable HTTP(S) URLs, and the
backend serializer must reject `blob:` URLs.

This prevents browser-local preview state from crossing the API boundary and
ensures persisted image records can be loaded by any client.

## Solution

### Immediate Fix
- Passed `imageFiles` to `Server.addProduct`.
- Removed browser preview URLs from new-product `images_urls` payloads.
- Updated multipart array handling to append array members individually.
- Added backend validation rejecting empty and `blob:` image URLs.
- Updated product cards to use one active image, filter invalid URLs, and show
  a deliberate empty-photo state.
- Removed three unrecoverable `blob:` image rows from the local database.

### Long-term Fix
Add browser-level upload tests that create a listing with multiple files,
reload the feed, and assert that each returned image URL is durable and
renderable.

## Prevention
- [ ] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `swappify-social-hub/src/pages/UploadProduct.tsx`
- `swappify-social-hub/src/server/Server.tsx`
- `swappify-social-hub/src/components/ProductCard.tsx`
- `backend/modules/listings/serializers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same implementation session

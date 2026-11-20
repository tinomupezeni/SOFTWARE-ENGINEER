# Catalogue Import 400 Bad Request Field Errors Hidden

**Date:** 2026-11-20
**Project:** LEC (lec-biotech-ascend)
**Area:** Frontend_and_UI / Backend_and_API
**Task ID:** `941aebf4-f84c-4b46-81a1-54f345f30167`

## Summary
When importing a CSV file into the catalogue via `/api/v1/admin/catalogue/import`, 400 Bad Request responses (such as empty file uploads or validation failures) caused the UI to show only generic `(error as Error).message` ("Some fields need attention.") rather than displaying specific field validation errors.

## Root Cause
DRF serializes field-level validation errors into the `fields` mapping in the error envelope:
```json
{
  "error": "Bad Request",
  "code": "VALIDATION_FAILED",
  "message": "Some fields need attention.",
  "fields": {
    "file": ["The submitted file is empty."]
  }
}
```
In `ImportScreen.tsx`, `error` was typed as generic `Error` and rendered via `(error as Error).message`. The specific field validation messages inside `ApiError.fields` were omitted, giving users no indication why their file was rejected.

## Resolution
1. Updated `ImportScreen.tsx` with a `formatError()` helper that checks `if (error instanceof ApiError && error.fields)`.
2. Formatted field errors into readable summaries (e.g., `Some fields need attention. (file: The submitted file is empty.)`).
3. Added test case in `apps/admin/src/features/catalogue/CatalogueStructure.test.tsx` ensuring structured field details are rendered when a 400 validation error occurs.
4. Verified with `npm run verify` (100% pass across lint, types, tests, build, scan, content gates).

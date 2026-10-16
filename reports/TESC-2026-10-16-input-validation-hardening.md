# TESC input validation hardening

**Date:** 2026-10-16
**Project:** TESC
**Type:** Audit / Bug Fix / Testing
**Status:** Completed

## Summary
Audited the highest-risk backend write paths for dates, national IDs, email
addresses, phone numbers, and bulk-upload values. Added shared validators,
serializer enforcement, commit-time revalidation, and focused regression tests.

## Context / Trigger
The request was to check data validation across TESC input tags, including
date, national ID, email, and phone inputs. Encrypted student fields and bulk
ingestion were identified as paths where normal Django model validation did not
apply.

## Scope
Included student and staff write serializers, institution bulk-upload preview
and commit paths, numeric amount handling, and focused backend tests. A full
frontend UX validation pass and staging bulk-upload execution for every module
remain follow-ups because this checkpoint focused on server-side integrity.

## Method
Reviewed model field definitions, serializers, service-layer normalization,
bulk preview conversion, and commit behavior. Implemented shared validators
independent of encrypted storage, then tested valid, malformed, and future
values.

## Decisions & Findings
- Encrypted PII must use explicit validators because model field types cannot
  enforce normal email/date semantics.
- Preview validation is not a trust boundary; commit must revalidate data.
- Dates are accepted only as `YYYY-MM-DD` and future dates are rejected.
- Phone numbers accept local/international formatted numbers while rejecting
  arbitrary text.
- Deprecated fields in `StudentWriteSerializer` were removed after the audit
  exposed an `ImproperlyConfigured` serializer construction failure.

## Changes Made
- Added `backend/core/input_validation.py`.
- Applied validators to student and staff serializers.
- Hardened bulk ingestion date, PII, amount, and commit validation.
- Converted client-data validation failures to HTTP 400 responses.
- Added `backend/tests/test_input_validation.py`.
- TESC commit: `f044e4b`.
- Related issue log: `TESC-2026-10-16-input-validation-gaps.md`.

## Verification
- Backend changed files compile using an isolated bytecode cache.
- Focused validation suite passed: 5 tests.
- Django system checks passed for the focused test run.
- Broader DB-backed academic tests were blocked because local PostgreSQL was
  not running on `localhost:5432`; no staging claim was made.

## Follow-ups / Deferred
- Run all bulk-upload module tests against staging.
- Complete frontend validation UX alignment after backend rules are confirmed.
- Add module-specific numeric bounds and cross-field date ordering where each
  domain requires them.
- Deploy `f044e4b` to staging and rerun endpoint/bulk-upload verification.

## References
- `backend/core/input_validation.py`
- `backend/academic/services/ingestion_service.py`
- `backend/tests/test_input_validation.py`
- `Backend_and_API/TESC-2026-10-16-input-validation-gaps.md`

---

**Completed By:** Copilot
**Duration:** Same session

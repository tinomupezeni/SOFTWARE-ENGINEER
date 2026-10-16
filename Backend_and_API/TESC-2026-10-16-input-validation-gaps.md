# Student and bulk-input validation gaps

**Date:** 2026-10-16
**Project:** TESC
**Environment:** Development/Staging
**Severity:** High
**Status:** Resolved

## Summary
Encrypted student identity fields and bulk-upload data bypassed the normal
Django field validators. Invalid national IDs, dates, email addresses, and
phone numbers could therefore reach service and persistence code.

## Symptoms
- Encrypted PII fields were exposed as unrestricted serializer `CharField`s.
- Bulk upload dates were parsed permissively and bulk commit trusted preview
  data without repeating validation.
- `StudentWriteSerializer` also referenced deprecated model fields and failed
  during serializer field construction.

## Environment Details
- **Server/Host:** TESC backend
- **Services Affected:** Academic and staff APIs; institution bulk ingestion
- **Related Components:** DRF serializers, ingestion service, encrypted fields
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Audited serializers, encrypted model fields, and the bulk ingestion preview
and commit paths.

### 2. Root Cause Analysis
The encrypted field implementation prevents Django's model field validators
from providing normal format checks. The ingestion path additionally used
permissive pandas date parsing and treated client preview data as trusted.

### 3. Key Findings
- Student national ID, date of birth, email, and phone fields lacked explicit
  serializer validators.
- Staff phone and join-date inputs lacked equivalent checks.
- Bulk validation did not cover student PII consistently.
- Commit-time validation was absent.
- The write serializer listed removed fields (`is_work_for_fees`,
  `work_area`, `hours_pledged`, and `inclusivity_category`).

## Root Cause
Validation rules were distributed implicitly across model fields even though
the encrypted fields are stored as text and bypass those model-level type
validators. Bulk ingestion also had no shared validation boundary.

## Prevention / Rule
**Guardrail:** Every encrypted or bulk-imported input must pass an explicit
shared validator at both serializer/write and commit boundaries.

The shared validators and focused regression tests now make format validation
independent of encrypted storage and prevent preview-only validation from being
used as a persistence control.

## Solution

### Immediate Fix
- Added shared strict ISO-date, national-ID, email, and phone validators.
- Applied them to student and staff write serializers.
- Added bulk preview and commit-time validation.
- Removed deprecated fields from `StudentWriteSerializer`.

### Long-term Fix
Keep the shared validator module as the single format-validation boundary and
extend it when additional bulk modules are audited.

## Prevention
- [x] Code-level shared validators
- [x] Serializer regression tests
- [x] Commit-time bulk validation
- [ ] Full staging bulk-upload regression run for every module

## References
- `backend/core/input_validation.py`
- `backend/academic/services/ingestion_service.py`
- `backend/tests/test_input_validation.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session

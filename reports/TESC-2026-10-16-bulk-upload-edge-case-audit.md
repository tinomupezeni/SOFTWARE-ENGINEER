# TESC bulk-upload edge-case audit

**Date:** 2026-10-16
**Project:** TESC
**Type:** Testing / Bug Fix / Release Readiness
**Status:** In Progress

## Summary
Ran institution bulk-upload edge cases against the requested staging hosts
before user training. Preview validation handled the tested malformed files and
row values, but direct commit testing exposed two defects in the deployed
runtime. The code fixes are committed locally and on the staging branch, while
remote VM deployment remains pending.

## Context / Trigger
Real institution users are about to upload production-like spreadsheets.
Training readiness requires testing malformed dates, national IDs, numeric
values, missing columns, malformed files, and attempts to bypass preview
validation.

## Scope
Covered all 11 ingestion module template endpoints, malformed date and PII
rows, negative/non-finite scholarship amounts, date ordering, missing columns,
malformed spreadsheet bytes, and direct commit payloads. The remote staging
VM deployment was not completed because non-interactive SSH access was denied.

## Method
Created a temporary institution through the staging API, authenticated through
the institution login path, downloaded each template, submitted malformed test
files, sent direct commit payloads, and cleaned up the temporary institution.
The same suite was rerun after the code fix was committed, but the remote
hostname continued returning the old behavior, demonstrating that the remote
runtime had not been updated.

## Decisions & Findings
- Template endpoints for all 11 ingestion modules passed.
- Malformed preview rows returned row-level validation errors rather than
  crashing.
- Direct commit payloads remain a critical release blocker on the remote
  staging VM:
  - Negative amount returned HTTP 200 with zero imports.
  - Missing student fields returned HTTP 500 with `KeyError`.
- The root cause is incomplete commit-time validation and silent skipping of
  unknown student references.
- Fix committed as TESC `eea3d7e`.

## Changes Made
- Added per-module required-field checks at commit time.
- Added commit-time numeric, date, PII, and date-order validation.
- Changed missing student references into HTTP 400 input errors.
- Rejected rows already marked invalid instead of returning success with zero
  imports.
- Added explicit handling for client input `KeyError`, `TypeError`, and
  `ValueError`.

## Verification
- - Remote backend hostname edge suite: **23/25 passed; 2 failed** because the
  remote runtime still serves the pre-fix code.
- Institution frontend hostname edge suite: **23/25 passed; 2 failed** with
  the same two commit-path defects, confirming the frontend proxy reaches the
  same stale backend runtime.
- Existing positive smoke suite remains 14/14 passed before this edge audit.
- Local compilation and focused backend tests passed.
- Remote staging IP is `102.217.49.126`; SSH deployment attempt was denied.
- Both `tesc-staging.zchpc.ac.zw` and `tesc-inst-staging.zchpc.ac.zw` resolve
  to the same staging VM and reproduce the same results.

## Follow-ups / Deferred
- Deploy TESC `eea3d7e` to the remote staging VM.
- Rerun the two failing direct-commit cases and require HTTP 400.
- Do not begin unrestricted user training uploads until the remote rerun is
  green.
- Add persistent automated negative-upload checks to the staging release gate.

## References
- TESC commit `eea3d7e`
- `backend/academic/services/ingestion_service.py`
- `backend/academic/app_views/ingestion_views.py`
- `SOFTWARE-ENGINEER/Backend_and_API/TESC-2026-10-16-bulk-commit-validation-bypass.md`

---

**Completed By:** Copilot
**Duration:** Same session; deployment follow-up pending

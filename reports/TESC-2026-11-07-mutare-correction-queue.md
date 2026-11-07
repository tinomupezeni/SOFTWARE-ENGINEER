# Mutare student correction queue

**Date:** 2026-11-07
**Project:** TESC
**Type:** Data Cleanup / Operational Handoff
**Status:** Completed

## Summary
Generated a correction workbook for Mutare Teachers College records attached to the two duration-code placeholder programs created by the historical upload issue, and emailed it to the main system administrator for source-spreadsheet reconciliation.

## Context / Trigger
The Mutare upload treated `2YEAR` and `3YEAR` as program codes, creating placeholder programs named `CHISHONA` and `MATHEMATICS` and routing unrelated students beneath them. The underlying subject mappings cannot be safely inferred from current database fields alone.

## Scope
Included institution `82` only and all students attached to programs `3088` (`CHISHONA`, code `2YEAR`) and `3089` (`MATHEMATICS`, code `3YEAR`).

The workbook does not modify or delete records. It excludes other institutions and does not attempt to infer corrected program or learning-area values.

## Method
Queried production through the healthy green backend container, selected the affected records with stable record and student identifiers, preserved current program/learning-area/category values, and added blank proposed-correction fields for completion from the original Mutare spreadsheet.

## Decisions & Findings
- Correction queue size: **5,054 records**.
- Placeholder programs: `CHISHONA (2YEAR)` and `MATHEMATICS (3YEAR)`.
- Current database values were preserved in the workbook.
- Proposed program, code, learning-area, category, and admin-notes columns are available for controlled reconciliation.
- No production rows were changed during workbook generation or delivery.

## Changes Made
- Generated a temporary Excel workbook with `Correction Queue` and `Summary` sheets.
- Emailed it to `admin@scalareye.com`.
- The temporary server-side file was removed after successful email attachment.

## Verification
- Excel generation completed using `openpyxl`.
- Email backend was configured for SMTP.
- `EmailMessage.send()` returned `1`.
- The generated workbook contained 5,054 records and the expected two placeholder programs.

## Follow-ups / Deferred
- Await the completed workbook from Mutare/main administration.
- Validate proposed mappings in dry-run mode.
- Produce an affected-row delta and obtain confirmation before applying any field corrections.
- Recompute STEM classifications only after corrected subject/program mappings are approved.

## References
- Issue: `SOFTWARE-ENGINEER/Backend_and_API/TESC-2026-11-07-mutare-chishona-stem-classification.md`
- TESC source: `backend/academic/services/student_services.py`

---

**Completed By:** Copilot
**Duration:** Same investigation session

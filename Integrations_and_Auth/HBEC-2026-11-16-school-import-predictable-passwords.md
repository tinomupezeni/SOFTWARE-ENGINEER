# School-imported student accounts got predictable default passwords

**Date:** 2026-11-16
**Project:** HBEC
**Environment:** Development source review
**Severity:** High
**Status:** Resolved

## Summary
Every student account created by the school dashboard's bulk Excel import
(`SCHOOLS/schools_backend/institutions/views.py`,
`import_students_excel`) was given a default password of the student's
uppercased surname, or the hardcoded literal `"HBEC2026"` when no surname
was supplied. Both are guessable from information printed in the same
roster file the school just uploaded (or from the constant itself), for
every student account created this way platform-wide.

## Symptoms
- No symptom reported by a user — found during an audit of the import flow
  ahead of adding an admin-operated equivalent, specifically because a
  second surface was about to start minting accounts the same way.

## Environment Details
- **Server/Host:** Local checkout.
- **Services Affected:** Integrations and Auth (account provisioning).
- **Related Components:**
  `SCHOOLS/schools_backend/institutions/views.py` (former inline import
  logic), now `SCHOOLS/schools_backend/institutions/services/
  import_service.py`.
- **Time First Observed:** 2026-11-16.

## Investigation Steps

### 1. Initial Diagnosis
Read the student-creation code path inside the bulk import view.

### 2. Root Cause Analysis
`default_password = lname.upper() if lname else "HBEC2026"` — a value
derived from data already visible in the uploaded sheet (or a fixed
literal), set directly as the account's live password with no forced
change on first login enforced anywhere in the flow.

### 3. Key Findings
- The fallback constant `"HBEC2026"` is identical for every student at
  every school that uploads a roster row with no last name.
- A surname-derived password is guessable by anyone who can read the
  roster (teachers, other admin staff, or anyone who intercepts the file)
  without needing the generated credential at all.

## Root Cause
The import path never generated a random credential; it derived one from
data already present in the row being processed.

## Prevention / Rule
**Guardrail:** `RunImportTests.test_generated_passwords_are_random_not_
predictable` (`institutions/tests.py`) asserts generated passwords are
unique per student and asserts neither the surname-derived nor the old
hardcoded value appears — a regression back to a derived or constant
password fails CI.

This directly tests the property that was missing: that the password isn't
reconstructable from data already available to whoever holds the roster.

## Solution

### Immediate Fix
`run_import()` now generates `secrets.token_urlsafe(10)` per student —
matching the random-password pattern `create_institution` already used for
newly provisioned school admins — and returns it in the per-row result so
the operator (school admin or, for the new admin-side import, HBEC staff)
can relay it through a channel of their choosing. The response explicitly
flags that credentials are shown once and must be distributed securely.

### Long-term Fix
Consider forcing a password change on first student login; not implemented
here (out of scope — no such enforcement mechanism currently exists
anywhere in the student auth flow to extend).

## Prevention
- [x] Guardrail test added.
- [ ] Evaluate forced password rotation on first login for bulk-imported
      accounts.

## Related Issues
- `HBEC-2026-11-16-school-import-job-state-machine-dead.md`
- `HBEC-2026-11-16-school-sync-missing-requests-dependency.md`

## References
- `SCHOOLS/schools_backend/institutions/services/import_service.py`
- `SCHOOLS/schools_backend/institutions/tests.py`

---

**Resolved By:** Local code fix, 2026-11-16
**Time to Resolution:** Same session as discovery

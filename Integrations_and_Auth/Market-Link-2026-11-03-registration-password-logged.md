# Registration Logged Plaintext Passwords

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Development code review (deployment state not verified)
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
The registration controller logged the complete request body, including the supplied plaintext password. The log was visible when running the buyer registration regression test.

## Symptoms
- Test output contained a `Registration attempt` object with `password: 'StrongPass123'`.
- Production log exposure was not inspected.

## Environment Details
- **Server/Host:** Repository checkout; production not inspected
- **Services Affected:** Express registration API and its log destination
- **Related Components:** `backend/controllers/authController.js`, `backend/tests/auth-regressions.test.js`
- **Time First Observed:** 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
Ran the new buyer registration regression test against the pre-fix controller.

### 2. Root Cause Analysis
The registration handler called `console.log("Registration attempt:", req.body)` before destructuring the payload. The request body contains the password.

```bash
node tests/auth-regressions.test.js
```

### 3. Key Findings
- The plaintext password appeared in local test output.
- The handler did not need the full body for its registration logic.
- A regression assertion now checks that registration logs do not contain the submitted password.

## Root Cause
Unredacted request payload logging at the authentication boundary.

## Prevention / Rule
**Guardrail:** Authentication route tests must assert that a submitted password is absent from application log output.

This catches accidental full-body logging in future registration changes.

## Solution

### Immediate Fix
Removed the full request-body log from `authController.register` in the local checkout.

### Long-term Fix
Keep the focused auth regression test as a required backend check. Review production logs for previously recorded passwords and apply the relevant log retention process.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `Backend_and_API/Market-Link-2026-11-03-buyer-registration-fields-dropped.md`

## References
- `backend/controllers/authController.js`
- `backend/tests/auth-regressions.test.js`

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session

## Verification

- `npm run test:auth` passed with an assertion that the submitted password never appears in captured registration logs.
- Production deployment and log review remain pending.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.

# My Files shows an empty library when the list request fails

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development source review; staging and production not exercised
**Severity:** Medium
**Status:** Investigating

## Summary
PR #118 makes listLearnerFiles return an empty array for every network, authentication, or server error. MyFilesPage treats that array as a successful empty response and tells the learner nothing is saved, even when the files are still in PostgreSQL.

## Symptoms
- A failed GET /api/v1/learner-files displays "Nothing saved yet."
- The user has no retry or visible error state on this path.

## Environment Details
- **Server/Host:** Local checkout and fetched PR #118 head.
- **Services Affected:** Student web My Files page.
- **Related Components:** learner-files/api.ts and MyFilesPage.tsx.
- **Time First Observed:** 2026-11-08 PR review.

## Investigation Steps

### 1. Initial Diagnosis
Read the new file-list API helper and the page's loading and empty states.

### 2. Root Cause Analysis
The helper catches all request errors and returns the same value as a valid empty response.

### 3. Key Findings
- The page cannot distinguish unavailable data from a genuinely empty library.
- The frontend test covers a valid empty response but not a failed request.

## Root Cause
An error was converted into a success-shaped empty array at the API boundary.

## Prevention / Rule
**Guardrail:** Make the list API return an explicit success/error result and add a UI test for a failed GET that requires an error and retry action.

This prevents an outage or expired session from being presented as absent learner data.

## Solution

### Immediate Fix
No fix made in this review. Preserve the request failure and render a retryable error state.

### Long-term Fix
Keep the failure-path test in CI and verify the signed-in browser journey on staging.

## Prevention
- [ ] Add explicit list error state.
- [ ] Add failure-path UI test.
- [ ] Verify the target user journey.

## Related Issues
- PR #118.

## References
- STUDENT/Frontend/src/shared/learner-files/api.ts:109-116
- STUDENT/Frontend/src/shared/learner-files/MyFilesPage.tsx:30-37,76-84

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing

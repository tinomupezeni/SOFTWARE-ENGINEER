# Two unreconciled hand-rolled "today" helpers disagree across the Africa/Harare midnight window

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Environment:** Development (caught during PR review, PR #3, before merge)
**Severity:** Medium
**Status:** Investigating

## Summary
PR #3's `RecordPayment.tsx` and `SettingsPage.tsx` each define their own `today()` helper for defaulting a date field — one computes the local-time calendar date, the other computes the UTC calendar date. Neither uses the codebase's own established Africa/Harare timezone constant already present in `utils/format.ts`. For Africa/Harare (UTC+2), any action taken between 00:00 and 02:00 local time gets a different default "today" depending on which page's convention is used.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review. A payment recorded or a setting changed just after local midnight would default to a date that disagrees with another screen's convention for the same instant.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `frontend` (desk app).
- **Related Components:** `frontend/src/pages/desk/RecordPayment.tsx:16`, `frontend/src/pages/desk/SettingsPage.tsx` (equivalent helper), `frontend/src/utils/format.ts` (existing Africa/Harare constant, not reused by either).
- **Time First Observed:** 2026-11-24, during review of PR #3.

## Investigation Steps

### 1. Initial Diagnosis
Compared every "default to today" date helper added across the PR's desk-app pages, rather than reviewing each page in isolation, to check they agree on what "today" means.

### 2. Root Cause Analysis
Two independent authors/commits each hand-rolled a date-default helper rather than reusing a shared, timezone-aware utility already present in the codebase (`utils/format.ts`'s Africa/Harare handling), so the two helpers drifted to different (and both defensible in isolation) interpretations of "today."

### 3. Key Findings
- No test exercises either helper near the UTC/Africa-Harare midnight boundary, so the drift wasn't caught by existing coverage.

## Root Cause
Duplicated, independently-written date-default logic instead of a single shared timezone-aware helper.

## Prevention / Rule
**Guardrail:** a single shared `today()` utility, built on the existing Africa/Harare constant in `utils/format.ts`, should be the only source of "default to today" logic across the frontend; a lint rule or code-review checklist item flagging a new local `Date` construction for calendar-date defaults (instead of importing the shared helper) would prevent this class of drift from recurring.

## Solution

### Immediate Fix
_Pending — to be fixed in this session._

### Long-term Fix
Replace both hand-rolled helpers with a single shared `today()` utility based on the existing Africa/Harare constant, and add a test asserting both call sites agree during the 00:00–02:00 local-time window.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Add a shared `today()` utility and a boundary-window test.
- [ ] Documentation to update: none required beyond this log entry.
- [ ] Code changes required — in progress.

## Related Issues
- Found alongside other PR #3 findings; see sibling entries in this directory dated 2026-11-24.

## References
- PR: https://github.com/winstonjthinker/Zimphos/pull/3

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session) — fix pending
**Time to Resolution:** Caught before merge; fix in progress

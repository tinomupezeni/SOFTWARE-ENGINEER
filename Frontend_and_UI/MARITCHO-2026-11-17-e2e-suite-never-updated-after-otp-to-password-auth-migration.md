# E2E suite never updated after OTP-to-password auth migration

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** CI (GitHub Actions, Frontend E2E workflow)
**Severity:** Medium
**Status:** Resolved

## Summary
`main`'s Frontend E2E workflow had 6 failing tests, pre-dating PR #12,
caused by the e2e suite still simulating the old phone+6-digit-OTP-code
sign-in flow. An earlier migration (`d3f6a1b8c9e2`, "Add password_hash
to persons, drop otp_requests — phone+password auth replaces OTP")
replaced that flow with a single-step phone+password sign-up, but the
e2e specs and helpers were never updated to match, so they'd been
silently red on `main` for some time.

## Symptoms
- `Visual regression (14 screens) + stubbed flows` and `Job lifecycle
  against docker-compose backend` both failing on `main`, with:
  - `getByRole('heading', { name: 'Enter your code' })` — element not found
    (that screen no longer exists)
  - `getByText('+263 77 412 3089')` — element not found (a label shown
    only during the old code-entry step)
- Discovered while diagnosing PR #12's CI failures — these 6 were
  already failing on `main` before that PR existed, confirmed by
  comparing `gh run list --branch main --workflow "Frontend E2E"`.

## Environment Details
- **Server/Host:** GitHub Actions
- **Services Affected:** `frontend/e2e/support/people.ts`,
  `frontend/e2e/visual/screens.spec.ts`,
  `frontend/e2e/visual/fixtures.ts`,
  `frontend/e2e/flows/media-and-code.spec.ts`,
  `frontend/e2e/lifecycle/job-lifecycle.spec.ts`
- **Time First Observed:** pre-existing; noticed 2026-11-17 while
  reviewing PR #12's CI failures.

## Investigation Steps

### 1. Initial Diagnosis
`gh pr checks 12` showed two failing E2E jobs. Downloaded job logs via
`gh api repos/Rest-creator/MARITCHO/actions/jobs/<id>/logs` and found
assertions against a "6-digit code"/"Enter your code" screen.

### 2. Root Cause Analysis
```bash
gh run list --branch main --workflow "Frontend E2E" --limit 3 --json databaseId,conclusion,headSha
gh run view 43937050988   # main's own latest E2E run — also failing, 6/20 tests
```
Confirmed these exact failures already existed on `main` at the commit
PR #12 branched from. Checked `SignUpScreen.tsx` (current source): it
only ever renders a single phone+password+name form — no OTP step
exists anywhere in the component tree.

### 3. Key Findings
- `people.ts`'s `signUp()` helper filled a "6-digit code" field that no
  longer exists in the UI.
- `fixtures.ts` stubbed a `POST session/code` endpoint the frontend no
  longer calls.
- `screens.spec.ts` had a dedicated `02b-sign-in-code` screenshot test
  for a screen that was deleted from the app.
- A second, unrelated staleness bug surfaced once the OTP fix let the
  lifecycle test actually run: `job-lifecycle.spec.ts` asserted
  `"Confirmed through Maricho"` (old brand name) against the current UI's
  `"Confirmed through Maritcho"` — a leftover from the Maritcho rebrand
  (PR #12) that only the test string missed.

## Root Cause
Two unrelated but same-shaped gaps: application code was migrated (OTP
auth removed; brand renamed) without a corresponding update to the e2e
suite that exercises those exact screens/strings, and CI's failure was
apparently not acted on for long enough that it stopped being noticed
as new/actionable.

## Prevention / Rule
**Guardrail:** Treat a red required CI check on `main` as blocking for
new feature PRs the same way a merge conflict is — i.e., add a CI
branch-protection rule requiring `main`'s own last Frontend E2E run to
be green before any PR's E2E job result is treated as informative.
Practically: when an auth flow or brand/copy string changes, grep the
`e2e/` directory for the old flow's distinctive strings (e.g. `"6-digit
code"`, the old brand name) as part of that same PR, instead of relying
on a human to notice CI drift later.

This closes the gap because the failure mode here was specifically
"nobody connected the dots that this screen/string doesn't exist
anymore" — a targeted grep at the time of the UI change would have
caught both staleness bugs immediately, before they could linger
unnoticed on `main`.

## Solution

### Immediate Fix
- `people.ts`: `signUp()` now fills name/phone/password in one step,
  matching the real form.
- `fixtures.ts`: removed the dead `POST session/code` stub.
- `screens.spec.ts`: removed the `02b-sign-in-code` screen test and its
  baseline PNG (dead screen); updated `02c-role-notice` to the
  single-step flow.
- `media-and-code.spec.ts`: replaced the two OTP-branch tests with one
  accurate password sign-up test asserting the real `POST /api/session`
  payload shape (`{mode, phone, password, name, role}`).
- `job-lifecycle.spec.ts`: fixed the stale `"Maricho"` → `"Maritcho"`
  assertion.
- Regenerated all 14 visual-regression screenshot baselines inside the
  exact pinned Playwright container CI uses
  (`mcr.microsoft.com/playwright:v1.63.0-noble`), since the rebrand's
  new color palette never had baselines regenerated either.

### Long-term Fix
Add the CI guardrail described above (gate new E2E failures against
`main`'s own current pass/fail state, not just the PR's own result) so
staleness like this surfaces as soon as it's introduced rather than
sitting unnoticed on `main`.

## Prevention
- [x] Configuration changes needed (e2e specs updated to match current UI)
- [ ] Monitoring/alerts to add (branch-protection rule comparing against main's own E2E state)
- [ ] Documentation to update (note the OTP→password migration in the e2e README, if one exists)
- [x] Code changes required

## Related Issues
- Found and fixed as part of reviewing MARITCHO PR #12 (`Rest-creator/MARITCHO#12`).

## References
- Migration `d3f6a1b8c9e2` ("Add password_hash to persons, drop otp_requests")
- `frontend/src/features/accounts/SignUpScreen.tsx`
- `frontend/e2e/support/people.ts`

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** ~1 hour, including diagnosing a false-alarm Next.js build-nudge blocker encountered while verifying the fix

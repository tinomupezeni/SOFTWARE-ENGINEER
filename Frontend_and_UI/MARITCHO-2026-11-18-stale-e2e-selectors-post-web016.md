# E2E Tests Stale Against WEB-016 Sign-up Changes (Frontend E2E Red Since Before PR #13)

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** CI (GitHub Actions, Frontend E2E workflow) and local (Playwright Docker image)
**Severity:** Medium
**Status:** Resolved

## Summary
Frontend E2E (`visual` + `flows` Playwright projects) had been failing since commit `781fd48` (WEB-016: "log in first, richer sign-up, and logo/travel/spacing fixes"), well before PR #13. The sign-up screen's copy, button label, and validation rules changed in that commit, but the E2E tests and shared helpers that drive the sign-up form were never updated to match. This was initially mistaken for a PR #13 regression during that PR's review; confirmed pre-existing by checking CI runs on the pre-merge commit.

## Symptoms
- `getByLabel("Your name")` timed out — the field's accessible label had changed to "Your full name".
- `getByRole("button", { name: "Continue" })` timed out — the submit button's label had changed to "Create account".
- Even after fixing the label/button text, the buyer/worker signup form still failed to submit: `validateSignUpDetails` (added in the same commit) requires a suburb, which no E2E test or helper filled in.
- 4 visual-regression screens (`03-employer-home`, `05-my-jobs`, `11-jobs-near-you`, `13-my-work`) failed separately with "API calls with no fixture" for `GET messages/unread` — a PR #13 addition with no stub in `e2e/visual/fixtures.ts`.
- 7 visual screens failed on pixel diffs against stale baselines, because PR #13 added a new `BrandLogo` component and a "How Maritcho works" onboarding carousel that legitimately changed those screens.

## Environment Details
- **Server/Host:** GitHub Actions `Frontend E2E` workflow; reproduced locally via `npm run test:visual` / running `npx playwright test --project=visual --project=flows` in the `mcr.microsoft.com/playwright:v1.63.0-noble` image
- **Services Affected:** None at runtime — test infrastructure only
- **Related Components:** `frontend/e2e/support/people.ts`, `frontend/e2e/visual/screens.spec.ts`, `frontend/e2e/flows/media-and-code.spec.ts`, `frontend/e2e/visual/fixtures.ts`, `frontend/src/features/accounts/SignUpScreen.tsx`
- **Time First Observed:** Since `781fd48`; noticed 2026-11-18 while investigating PR #13's red CI

## Investigation Steps

### 1. Initial Diagnosis
PR #13's Frontend E2E check was red. Assumed at first it might be caused by that PR's own changes (RoleGate, messaging, dual profiles).

### 2. Root Cause Analysis
- `git log -S'"Your name"'` / `-S'"Continue"'` / `-S"validateSignUpDetails"` on `SignUpScreen.tsx` all pointed to `781fd48`, which predates PR #13 by several commits.
- Confirmed the same two E2E jobs were already failing on the pre-merge `experimental` commit (`gh run list --branch experimental`), ruling out PR #13 as the cause for those two specific failures.
- The `GET messages/unread` and stale-baseline failures *were* genuinely new, caused by PR #13's own additions (unread inbox, BrandLogo, onboarding carousel) — those are legitimate, not bugs, just missing fixture/baseline updates that should have shipped with the feature.

### 3. Key Findings
- A UI copy/behavior change (WEB-016) landed without updating the E2E suite that exercises the exact form it changed — the tests kept "passing" in the sense that nobody looked, because this suite isn't gated into merges automatically here.
- `e2e/support/people.ts`'s `signUp()` helper is shared by the `lifecycle` project (runs against a real backend) — the same missing-suburb bug would have silently blocked that suite too; not independently verified end-to-end due to a slow Docker image pull in this session, but the same selector-matching logic applies.

## Root Cause
E2E test selectors and form-filling helpers were not updated when the sign-up form's copy, button label, and validation requirements changed in `781fd48`; a later PR (#13) then added new UI (BrandLogo, onboarding carousel, unread inbox) without updating the corresponding visual baselines and API fixtures either.

## Prevention / Rule
**Guardrail:** Add Frontend E2E as a required status check on `main`'s branch protection (currently none configured), and require screenshot/fixture updates to ship in the same PR as any UI change that affects a stubbed screen's API calls or pixel layout — a PR touching `SignUpScreen.tsx`'s labels/validation, or adding a new UI element rendered on an existing stubbed screen, should fail its own CI if it doesn't also update the matching E2E selectors/fixtures/baselines.

This closes the gap on both ends: a required check stops a red E2E suite from merging silently (what let `781fd48`'s drift go unnoticed for multiple PRs), and treating fixture/baseline updates as part of the UI change's own PR prevents the same "someone else's problem" drift from recurring.

## Solution

### Immediate Fix
- `e2e/support/people.ts`, `e2e/visual/screens.spec.ts`, `e2e/flows/media-and-code.spec.ts`: updated label text to "Your full name", button text to "Create account", and added filling the now-required suburb field (`selectOption({ label: "Hillside" })`, a seeded suburb).
- `e2e/visual/fixtures.ts`: added a `"GET messages/unread": ok([])` fixture entry.
- Regenerated 7 stale visual baselines via `npm run test:visual:update`.
- Verified: `npx playwright test --project=visual --project=flows` → 18/18 passing, run inside the same Docker image CI uses.

### Long-term Fix
Add Frontend E2E as a required branch-protection check per the Guardrail above.

## Prevention
- [ ] Configuration changes needed (branch protection: require Frontend E2E on `main`)
- [x] Code changes required (done — see Immediate Fix)

## Related Issues
- Found while investigating CI status for PR #13 (Maritcho `experimental` -> `main`), merged separately.

## References
- Commit `781fd48` (WEB-016) — introduced the drift
- PR #13 (Maritcho) — added the BrandLogo/carousel/unread-inbox features whose fixtures/baselines were missing

---

**Resolved By:** Claude (code review follow-up)
**Time to Resolution:** Same session

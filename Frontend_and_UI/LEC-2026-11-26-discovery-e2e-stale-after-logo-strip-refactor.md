# CI red on main for 3 pushes: e2e spec never updated after logo-strip control removal

**Date:** 2026-11-26
**Project:** LEC Biotec (lec-biotech-ascend)
**Environment:** CI (GitHub Actions), discovered while merging two unrelated PRs
**Severity:** High (blocked every CI run on `main` and any PR rebased onto it)
**Status:** Resolved

## Summary
`main`'s CI (`npm run test:e2e`) had been failing since commit `c33b46b`
("fix(logo-strip): resolve vertical cut-off and remove manual controls in
favor of hover-to-pause"), three pushes in a row, because
`apps/storefront/e2e/discovery.spec.ts` still asserted against a "Pause
movement" button and a "Scroll partners right" button that commit removed
from the component. Nobody noticed because `npm run verify` (the local
gate) does not run `test:e2e` — only CI does.

## Symptoms
- `gh run list --branch main` showed `failure` on the three most recent
  pushes to `main` (`8118268`, `305347e`, `62502c8`), all green on
  `Verify`/`API` but red on `E2E (storefront + admin)`.
- Two separate PRs being reviewed/merged in this session (#67, #68) both
  inherited this failure after merging `main` into their branches, making
  it look like a problem with those PRs when it was actually pre-existing
  on `main`.
- Playwright error: `locator.click: Test timeout of 30000ms exceeded` —
  `waiting for getByRole('button', { name: 'Pause movement' })` /
  `'Scroll partners right'`.

## Environment Details
- **Related Components:** `apps/storefront/e2e/discovery.spec.ts`,
  `apps/storefront/src/features/content/sections/LogoStripSection.tsx`
- **Time First Observed:** 2026-11-26, while checking CI status before
  merging PRs #67/#68.

## Investigation Steps

### 1. Initial Diagnosis
`gh pr checks` on both PRs showed an `E2E` failure unrelated to either
PR's own diff. `gh run list --branch main` confirmed the same failure
already existed on `main` itself, ruling out either PR as the cause.

### 2. Root Cause Analysis
`git log --oneline -- apps/storefront/e2e/discovery.spec.ts` showed the
spec was last touched in a much older commit, while
`git show c33b46b --stat` showed that commit updated
`logo-strip.test.tsx` (the unit test) but not `discovery.spec.ts` (the
e2e test) — the component's manual pause/scroll buttons were deleted
entirely in favor of `onPointerEnter`/`onPointerLeave` hover-to-pause
(`LogoStripSection.tsx:78-83`), but the e2e spec was never told.

### 3. Key Findings
- `npm run verify` does not include `test:e2e`, so this regression was
  invisible to the standard local gate and only surfaced in CI.
- The unit test suite (`logo-strip.test.tsx`) was correctly updated in
  the same commit that changed the component — only the e2e suite was
  missed, suggesting the author ran unit tests but not `npm run test:e2e`
  before committing.

## Root Cause
`c33b46b` changed `LogoStripSection.tsx`'s interaction model (removed
manual pause/scroll buttons for hover-to-pause) and updated its unit test
but not its e2e coverage, which still drove the removed buttons directly.

## Prevention / Rule
**Guardrail:** None added this session — `npm run verify` deliberately
excludes `test:e2e` (per `CLAUDE.md`, e2e runs on its own dev server on
`:8140`), so there's no cheap automated gate that would have caught this
locally before push. The practical guardrail is procedural: when a commit
changes a component's accessible-role surface (removes/renames a button,
changes ARIA roles), grep `e2e/*.spec.ts` for the old role name before
committing, the same way the unit test was checked.

This closes the gap by naming the actual manual step that was skipped
(checking e2e for role-surface changes) rather than asking for "more
testing" in the abstract.

## Solution

### Immediate Fix
Rewrote both tests in `discovery.spec.ts` to assert the actual
hover-to-pause behavior (move mouse over the strip's bounding box to
pause, move away to resume) instead of clicking buttons that no longer
exist. Verified locally with `npx playwright test discovery.spec.ts`
(chromium + mobile, 4/4 passed).

### Long-term Fix
None required; this was a one-off oversight, not a systemic issue beyond
the procedural note above.

## Prevention
- [x] Code changes required (done)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
Discovered while reviewing and merging PRs #67 (LEC-093) and #68
(LEC-097) in the same session — see
`reports/LEC-2026-11-26-pr-67-68-review-and-merge.md` if one is filed for
that initiative.

## References
- `apps/storefront/e2e/discovery.spec.ts`
- `apps/storefront/src/features/content/sections/LogoStripSection.tsx`
- Commit `c33b46b`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** < 30 minutes

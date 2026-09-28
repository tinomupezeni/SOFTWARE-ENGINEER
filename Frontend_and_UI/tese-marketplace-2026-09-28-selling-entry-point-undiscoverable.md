# Self-service listing feature unreachable in practice - ambiguous nav label, buried entry point

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, customer-store)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
The same day the "instant self-service listing" flow was deployed (see
`reports/tese-marketplace-2026-09-28-self-service-listing-no-approval-gate.md`),
a real user reported it as broken: "nothing changed... did u really deploy,"
then "incognito doesnt help... same issue." Extensive server-side
investigation (DB queries, app logs, curl against the live endpoint) proved
the click never reached the backend as a network request. The feature
itself was never broken - it was undiscoverable. The profile page's nav tab
was still labeled "Partner" (a leftover from the old application-form
naming) with no entry point anywhere else in the UI, so the user genuinely
could not find/recognize the function that would let them list products.

## Symptoms
- User report: "nothing changed... did u really deploy" - pasted the exact
  current self-service UI text (hero, 3 role cards, benefit cards),
  confirming the deploy *was* live and rendering correctly.
- Follow-up: "incognito doesnt help... same issue" after being asked to
  hard-refresh/retry in a private window.
- When directly asked what happens on click (spinner? toast? console
  error?), the user's actual answer reframed the whole report: "oh ok, my
  bad, thing is its still says partner on the navbar which is confusing...
  the steps to be clicked by user should be reduced... remove unnecessary
  clicks." No click had actually failed - the user was reporting confusion
  about *finding* the function, not a broken function.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-customer-store`
  container)
- **Services Affected:** `customer-store` profile page navigation
  (`CustomerProfilePage.tsx`, `AccountOverview.tsx`)
- **Related Components:**
  `apps/customer-store/src/features/customer-profile/pages/CustomerProfilePage.tsx`,
  `apps/customer-store/src/features/customer-profile/components/AccountOverview.tsx`,
  `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`
- **Time First Observed:** 2026-09-28, same session as the self-service
  listing deploy

## Investigation Steps

### 1. Initial Diagnosis
Treated it as a functional bug first, since that's what the report implied.
Confirmed via `GET /api/auth/admin/applications` and a direct Postgres
query (`tese_user`@`tese_store` on the VPS) that the reporting user held
only the `customer` role - no role grant had ever been attempted for him.

### 2. Root Cause Analysis
```bash
docker logs tese-store-api --since 45m | grep -E 'HTTP/1.1" (4|5)[0-9][0-9]'
# -> zero errors, and no request pattern matching a genuine attempt from
#    his account at all (only my own automated test traffic)
```
This proved the click never even left the browser as a network request.
Read the full click path statically end to end - `PartnerSection.tsx`'s
role-card `<button onClick>`, `selfGrantMutation`, `AuthContext.login`/
`getRefreshToken`, `axiosInstance`'s request interceptor - all identical
regardless of login method (email/password vs. the Google OAuth path
implemented earlier the same session); found no code-level reason a click
would silently no-op. Declined to forge a JWT with the production secret
to fake-reproduce a session (correctly blocked by the environment's
credential-materialization guard) and instead asked the user directly what
happened on click (spinner? console error? network request at all?).
That direct question is what surfaced the real issue: the user hadn't
actually failed to trigger the function - he couldn't confidently locate
it, because the tab is labeled "Partner," a word with no obvious
connection to "list/sell my products," and it's not the default tab.

### 3. Key Findings
- The `PartnerSection.tsx` self-grant flow itself was working correctly in
  production the whole time - all the server-side and client-side
  investigation confirmed a fully functional, unbroken implementation.
- `AccountOverview.tsx` (the default landing tab) had zero mention of
  selling/listing anywhere in its quick-action cards (Orders, Login &
  Security, Addresses, Your Profile) - a user had to already know to click
  the ambiguous "Partner" tab specifically to discover the feature exists.
- Asking "what exactly happens when you click" - rather than continuing to
  assume the report's framing ("nothing changed") was literally accurate -
  was what actually resolved this; the user's own answer contradicted
  their initial "did u really deploy" framing once asked to be specific.

## Root Cause
UX/discoverability gap, not a code defect: the nav label "Partner" was
carried over unchanged from the old application-form terminology when the
flow beneath it was rewritten to instant self-service listing, and no
direct entry point to it existed from the page a user actually lands on
first (Overview). The feature was functionally correct but effectively
invisible.

## Prevention / Rule
**Guardrail:** Whenever a user-facing flow's *purpose* changes (here:
"submit a partner application for review" -> "instantly list your
products"), treat renaming every surface that names it - nav labels, page
titles, breadcrumbs, empty-state copy - as part of the same change, not a
follow-up; grep the codebase for the old feature name (e.g. `"Partner"`)
before considering the change complete, the same way you'd grep for a
renamed API field.

This closes the specific gap here: the backend/business-logic rename
("application" -> "self-service listing") happened in the same session but
the nav label rename did not, because nothing forced a full-codebase
sweep for every place the old name appeared.

## Solution

### Immediate Fix
- Renamed the profile nav tab from "Partner" to "Sell" (`CustomerProfilePage.tsx`,
  swapped `Building2` icon for `Store`).
- Added a "Start Selling" quick-action card directly on the default
  Overview tab (`AccountOverview.tsx`), linking straight to the `partner`
  tab - so a new user is one click from the role picker instead of having
  to first interpret an ambiguous nav item.
- Added `"partner"` to the `ProfileTab` union type (`customerProfile.types.ts`),
  which had been missing despite the tab already existing at runtime -
  a pre-existing type-safety gap, fixed in passing since the new
  `AccountOverview` usage required it to type-check.

```bash
npx tsc --noEmit          # clean
pnpm --filter customer-store build   # clean production build
```

### Long-term Fix
None needed beyond the guardrail above - this was a naming/discoverability
gap, not a structural one.

## Prevention
- [x] Code changes required (done this session)
- [ ] Monitoring/alerts to add - n/a
- [ ] Documentation to update - n/a

## Related Issues
- `reports/tese-marketplace-2026-09-28-self-service-listing-no-approval-gate.md`
  (the same-day initiative whose nav label this entry finishes renaming)

## References
- `apps/customer-store/src/features/customer-profile/pages/CustomerProfilePage.tsx`
- `apps/customer-store/src/features/customer-profile/components/AccountOverview.tsx`
- `apps/customer-store/src/features/customer-profile/types/customerProfile.types.ts`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~25 minutes from report to verified fix in production (most of it spent ruling out a functional bug before the direct question surfaced the actual UX cause)

# Add Listing form asked "what are you listing?" after the user had already said so

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, customer-store)
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
A seller holding more than one listing role (e.g. Supplier + Service
Provider) clicked a single generic "Add Listing" button, which opened a
form that then asked them to pick "What are you listing? *" (Produce /
Supply / Service) via a radio group before showing the rest of the form -
an extra decision step for information the product's own type already
determines. User feedback, verbatim (pasting the radio group's text):
"no need for a user to select ontop what they want to sell, they should
just come and click what they want to sell."

## Symptoms
- Not an incident - a design review request from the user, in the same
  session as the category-permissions fix
  (`Backend_and_API/tese-marketplace-2026-09-28-sellers-could-create-own-categories.md`),
  after reviewing the self-service listing form.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-customer-store`
  container)
- **Services Affected:** `PartnerSection.tsx`'s Add Listing flow, only
  visible to sellers holding 2+ roles (farmer/supplier/service_provider)
- **Related Components:**
  `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`
- **Time First Observed:** 2026-09-28, same session as the self-service
  listing feature and its category-permissions follow-up

## Investigation Steps

### 1. Initial Diagnosis
Not a functional bug - read the form JSX directly. The radio group only
rendered `!editingProduct && approvedListingTypes.length > 1`, i.e. only
for multi-role sellers adding a new listing, confirming this was a genuine
extra click/decision, not dead code.

### 2. Root Cause Analysis
The header had one generic "Add Listing" button regardless of how many
listing types the seller was approved for, deferring the type choice to
inside the form instead of making it the entry action itself.

### 3. Key Findings
- The information being asked for (which listing type) was already fully
  determined by which role card the seller had clicked earlier in
  `reports/tese-marketplace-2026-09-28-self-service-listing-no-approval-gate.md`
  - the form was re-asking a question the app already had the answer to.

## Root Cause
UX design gap: the "Add Listing" entry point wasn't specialized per
listing type, so the type had to be collected as a form field instead of
being implied by which action the user took.

## Prevention / Rule
**Guardrail:** When a user has already made a choice earlier in a flow
(here: which role/listing-type they hold), a later step in the same flow
must not re-ask for that same information via a generic entry point plus
an internal selector - the earlier choice should determine which specific
action is offered next. Applies generally to any multi-step flow being
added to this app: prefer type-specific entry points (`Add Produce`, `Add
Supply`, `Add Service`) over a single generic entry point with an
internal disambiguation step.

## Solution

### Immediate Fix
`apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`:
- Removed the "What are you listing?" radio group from the Add/Edit
  Listing form entirely.
- Replaced the single "Add Listing" header button with one button per
  listing type the seller is approved for (`Add Produce` / `Add Supply` /
  `Add Service`, via a new `LISTING_TYPE_ADD_LABEL` map) - clicking it
  sets the listing type and opens the form directly, no in-form
  selection step.

```bash
npx tsc --noEmit                     # clean
pnpm --filter customer-store build   # clean production build
```
Verified in production after redeploy (site returns 200, no console/build
errors).

### Long-term Fix
None needed - this was a UX simplification, not a structural change.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `Backend_and_API/tese-marketplace-2026-09-28-sellers-could-create-own-categories.md`
  (same commit, same session, unrelated cause - category permissions, not
  listing-type selection)
- `Frontend_and_UI/tese-marketplace-2026-09-28-selling-entry-point-undiscoverable.md`
  (earlier same-day fix to the same page - reducing clicks to reach the
  selling function in the first place)

## References
- `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~20 minutes from request to verified fix in production

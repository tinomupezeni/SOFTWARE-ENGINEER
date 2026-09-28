# Remove partner application/approval gate - instant self-service listing

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, store-api / customer-store)
**Type:** Scope Decision
**Status:** Completed

## Summary
Replaced the multi-field "Partner Application" form (business name,
description, KYC documents) plus a manual admin-review wait with instant
self-service: a user picks Farmer/Supplier/Service Provider and is taken
straight to their product management page, no waiting. This reverses part
of an earlier architecture decision in this same session (and the
project's original "centralized, admin-only listing" direction from
`DECISIONS_LOG.md`) in favor of lower-friction self-listing, per explicit
user direction.

## Context / Trigger
User feedback, verbatim: "the submit application, its supposed to be
simply say add/list your products an users product management page" -
after seeing the application form (screenshot showed the Farmer/Supplier/
Service Provider cards plus Business Name/About/KYC fields and a "Submit
Application" button) and reporting "there doesn't seem to be any update"
after submitting.

## Scope
**Included:**
- Backend: `POST /auth/applications` now auto-approves and grants the
  role(s) immediately instead of requiring `PATCH
  /auth/admin/applications/{id}/status` from an admin first.
- Frontend: `PartnerSection.tsx` - removed the application form UI (name/
  description/KYC fields, "Submit Application" step) entirely. Picking a
  role is now a single click that grants it and shows the product
  management portal.
- Handling the JWT-staleness consequence of instant role granting (the
  user's current access token doesn't carry a role granted mid-session).

**Explicitly excluded:**
- The `ProviderApplication` admin-review UI in admin-dashboard
  (`Verifications.tsx`) was left as-is - still functional for whatever
  admin-side visibility or manual role management is wanted later, just
  no longer load-bearing for normal self-listing.
- No database migration: `business_name` stayed a NOT NULL column;
  handled by defaulting it server-side to the user's name rather than
  making it nullable, avoiding any schema change.

## Method
1. Confirmed the exact intended flow with the user before touching
   authorization logic (options: keep vs. drop the farmer/supplier/
   service type selection) - it's a role-authorization change, not
   just a UI simplification, so guessing wrong would mean redoing both
   the frontend and the backend role-granting logic.
2. Reasoned through the JWT consequence up front: `require_partner_or_admin`
   checks roles embedded in the JWT at login time, not the DB directly.
   Granting a `UserRole` row mid-session does nothing until the user's
   token is refreshed. Confirmed `POST /auth/refresh` already re-reads
   `user.roles` fresh from the DB, so the fix is to call it immediately
   after granting, before the caller tries to use the new role.
3. Verified the whole thing against production with a real headless
   browser (Playwright via system Chrome, `channel: 'chrome'`, since the
   sandboxed environment's OS isn't in Playwright's supported list) doing
   the actual UI flow: register -> login -> Partner tab -> click a role ->
   confirm the portal appears and "Add Listing" opens without error ->
   reload the page -> re-navigate to the Partner tab -> confirm the
   portal still shows (this last step initially looked broken in testing,
   traced to the test script itself not re-clicking the tab after a fresh
   page load resets to the default "Overview" tab - not a real bug).

## Decisions & Findings
- **JWT staleness after mid-session role grants** is the one real technical
  wrinkle in "instant" self-service: a naive implementation would grant
  the DB role but leave the user unable to actually use it until their
  next full login. Solved by calling the existing refresh-token endpoint
  right after granting and updating the client's stored token before
  invalidating the `my-applications` query, so the UI's very next request
  (fetching products/categories) is already authorized.
- **`business_name` NOT NULL avoided a migration** by defaulting to
  `user.name` server-side when the field is omitted, rather than altering
  the column or adding a migration this session didn't need.
- **Multiple roles remain supported**: a user already in the portal for
  one role sees a small inline prompt for any role they haven't yet
  granted themselves ("Also want to sell: Supplier · Service Provider"),
  reusing the same instant-grant mutation, so there's no need to leave
  the product management page to add a second selling category later.
- **`update_application_status` (admin manual approve/reject) was kept**,
  refactored to share a `_grant_roles()` helper with the new self-service
  path rather than removed, since it's still a reasonable lever for an
  admin to have even though it's no longer in the normal path.

## Changes Made
Backend (`apps/store-api`):
- `app/modules/auth/schemas/auth.py` - `ProviderApplicationCreate.business_name`
  made optional.
- `app/modules/auth/services/auth_service.py` - `create_provider_application`
  now sets `status="approved"` and calls the new shared `_grant_roles()`
  helper immediately, instead of leaving `status="pending"` for an admin.
  Defaults `business_name` to the user's name when omitted.

Frontend (`apps/customer-store`):
- `features/customer-profile/components/PartnerSection.tsx` - rewritten:
  removed `isApplying`/`formData` (business name/description/KYC) state
  and the application-form JSX entirely; added `selfGrantMutation` (POST
  the role, then refresh the JWT via `authService.refreshToken()` and
  `useAuth().setTokens()`); the "not selling yet" view is now 3 direct
  role-selection cards instead of a promo banner + form; the portal view
  gained an inline "Also want to sell: ..." prompt for ungranted roles.

## Verification
- `npx tsc --noEmit` - no new errors from the rewritten file.
- `pnpm --filter customer-store build` - clean production build.
- Live end-to-end Playwright run against production (see Method) covering
  registration, login, role grant, portal display, listing-form open, and
  reload persistence.

## Follow-ups / Deferred
- `admin-dashboard`'s `Verifications.tsx` page still lists
  `ProviderApplication` rows (now always `status="approved"` /
  `admin_notes="Auto-approved (self-service listing)"`) - worth revisiting
  whether that page should be relabeled or repurposed now that there's
  nothing left to actually review, or removed if it's confirmed unused.
- No abuse/spam guardrail was added on top of instant role granting
  (e.g., rate-limiting how many roles/listings a brand-new account can
  create) - acceptable for now per the "supermarket" trust model in
  `DECISIONS_LOG.md`, but worth a follow-up if listing spam becomes a
  problem.

## References
- `reports/tese-marketplace-2026-09-28-farmer-self-listing.md` (the prior
  session that built the application/approval flow this report removes
  the gate from)
- `Frontend_and_UI/tese-marketplace-2026-09-28-session-lost-on-page-reload.md`
  (separate, unrelated bug found and fixed earlier the same day, also on
  this profile page)
- Key files: `apps/store-api/app/modules/auth/services/auth_service.py`,
  `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~40 minutes from user report to verified fix in production

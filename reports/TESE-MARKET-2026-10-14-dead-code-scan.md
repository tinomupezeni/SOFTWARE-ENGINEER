# Dead-code scan and cleanup candidates

**Date:** 2026-10-14
**Project:** TESE-MARKET (BFF)
**Type:** Audit / Cleanup
**Status:** Completed

## Summary
A static source-graph audit identified tracked modules with no static importer and compared them with frontend route tables, barrel exports, cleanup scripts, and production builds. The verified customer-store legacy modules were removed; unrouted admin feature pages were deliberately left in place because their product status is still ambiguous.

## Context / Trigger
The user requested a codebase scan for dead code that could be deleted.

## Scope
Included the two Vite frontend applications, shared TypeScript packages, workspace manifests, route entry points, source imports, cleanup scripts, and build/type-check commands. Excluded Python service internals, generated `dist/` output, dependencies, and runtime-only backend references because this pass focused on frontend source reachability.

## Method
1. Read workspace manifests and TypeScript/Vite boundaries.
2. Built a static graph from `main.tsx` entry points, relative imports, `@/` aliases, workspace package aliases, and index files.
3. Cross-checked candidates with route declarations, barrel exports, repository-wide filename references, and Git tracking state.
4. Ran frontend TypeScript checks and production builds.
5. Removed only the customer-store modules with no static importer or code reference; left ambiguous admin pages for follow-up.

## Decisions & Findings

### High-confidence cleanup candidates

These tracked customer-store files have no static importer and no repository source reference beyond documentation or the scan output:

- `apps/customer-store/src/core/api/socketClient.js`
- `apps/customer-store/src/hooks/useAnalytics.ts`
- `apps/customer-store/src/hooks/useCatalog.ts`
- `apps/customer-store/src/hooks/useChatWebSocket.ts`
- `apps/customer-store/src/hooks/useFavorites.ts`
- `apps/customer-store/src/hooks/useIntelligence.ts`
- `apps/customer-store/src/hooks/useOrders.ts`
- `apps/customer-store/src/lib/socketClient.ts`
- `apps/customer-store/src/services/addressService.tsx`
- `apps/customer-store/src/services/deliveryService.tsx`
- `apps/customer-store/src/services/paymentService.tsx`
- `apps/customer-store/src/shared/navigation/HeaderLocationBanner.tsx`
- `apps/customer-store/src/types/home.ts`
- `apps/customer-store/src/types/listings.ts`
- `apps/customer-store/src/types/message.ts`
- `apps/customer-store/src/types/products.ts`
- `apps/customer-store/src/types/services.ts`
- `apps/customer-store/src/types/supplier.ts`

These modules had no static importer or repository code reference and were removed after the customer production build passed.

### Admin-dashboard unreachable surfaces

The following tracked admin pages are not imported or routed by `apps/admin-dashboard/src/App.tsx:4-47`:

- `EventMonitor.tsx`
- `Governance.tsx`
- `KnowledgeGraph.tsx`
- `Projections.tsx`
- `SourcingManagement.tsx`
- `SystemLogs.tsx`

Related unreferenced data/hooks include `hooks/useProductAdmin.ts`, `hooks/useSourcing.ts`, and `data/support/ticket-query.ts`. These remain for review as feature slices before deletion because some are coupled to product/reporting surfaces and their intended status is ambiguous.

### Tooling and quality-gate findings

- `apps/customer-store/find-unused-files.js:37-55, 87-148` produces broad false positives for active alias/barrel imports.
- `apps/customer-store/production-cleanup.js:11-45` contains a stale list of paths that no longer exist in the current source tree.
- Customer-store type-checking fails with numerous existing contract/import errors.
- Admin-dashboard type-checking fails at `apps/admin-dashboard/src/lib/types/projections.ts:7` due to invalid syntax (`any{}`).
- Both Vite production builds complete, so build success alone is not evidence that cleanup is safe.

## Changes Made
The 18 confirmed customer-store legacy modules listed above were deleted. The temporary root-level `unused-files.json` produced by the repository script was removed after analysis. Two issue logs were created for the scanner false positives and the failing type-check baseline.

## Verification
- Static dependency graph traced both frontend entry points and workspace aliases.
- Route and barrel references were checked manually.
- Customer-store Vite production build passed.
- Admin-dashboard Vite production build passed.
- Customer-store TypeScript check still failed with the pre-existing baseline errors documented in the issue log.
- Admin-dashboard TypeScript check failed as documented.
- No remaining code references to the deleted customer modules were found.

## Follow-ups / Deferred
- Decide whether the six unrouted admin pages are retired features or pending routes; delete complete feature slices only after that decision.
- Repair the TypeScript baseline and add type-check gates before a second cleanup pass.
- Replace or rewrite the custom unused-file scanner.

## References
- `apps/customer-store/find-unused-files.js`
- `apps/customer-store/production-cleanup.js`
- `apps/customer-store/src/App.tsx`
- `apps/admin-dashboard/src/App.tsx`
- `TESE-MARKET-2026-10-14-dead-code-scan-tooling-false-positives.md`
- `TESE-MARKET-2026-10-14-typecheck-baseline-failing.md`

---

**Completed By:** Copilot
**Duration:** One audit session

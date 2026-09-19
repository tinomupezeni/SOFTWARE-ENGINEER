# `system_design.md` Described WhatsApp/PWA/Mobile Client Tier as Implemented — None of It Exists

**Date:** 2026-09-18
**Project:** MARITCHO
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
`docs/architecture/system_design.md` §1 listed "React Native (Expo) mobile clients," "Next.js PWA for web access," and "WhatsApp Business API for SMS/Voice-note fallback" under the Client Tier with no qualifier, and its §2 component diagram drew solid (implemented-looking) edges from a `Client` node and a `WA` (WhatsApp) node into the FastAPI backend. None of these three clients exist: there is no PWA, no Expo/React Native app (Sprint 3, `APP-00x`, is still `TODO` in `docs/backlog.md`), and no WhatsApp integration code anywhere in `app/`. A reader of the architecture doc alone would reasonably believe all three were live.

## Symptoms
- `grep -rn "whatsapp\|WhatsApp" backend/app/ --include="*.py"` returns nothing.
- No `frontend/`, `pwa/`, or `mobile/` directory exists anywhere in the repo — the backend is the entire implemented surface today.
- `docs/backlog.md`'s Sprint 3 (`APP-001`–`APP-003`, the Expo/offline-first client) is entirely `TODO`, confirming the mobile client was never built, contradicting the SDD's unqualified listing.
- The component diagram's `Client -->|HTTPS/REST| API` and `WA -->|Webhooks| API` edges were drawn as solid lines, the same visual weight as the genuinely-implemented `API -->|Async PgSQL| DB` edge — no visual distinction between what's real and what's aspirational.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO`
- **Services Affected:** `docs/architecture/system_design.md` (documentation only — no runtime component affected)
- **Related Components:** `docs/discovery/business_case.md` (the actual source of the WhatsApp requirement, correctly scoped there as Stage One), `docs/backlog.md` Sprint 3
- **Time First Observed:** 2026-09-18, while reconciling a comparative service-marketplace case-study review into Maricho's documentation and noticing the SDD already claimed the WhatsApp channel existed

## Investigation Steps

### 1. Initial Diagnosis
While writing ADR-006 (WhatsApp Business API intake, prompted by the case-study review's Kandua/"Ask Jess" pattern), checked whether WhatsApp intake was in fact already built, since the SDD implied it was.

### 2. Root Cause Analysis
```bash
grep -rn "whatsapp\|WhatsApp" backend/app/ --include="*.py"   # empty
find . -maxdepth 2 -iname "*pwa*" -o -iname "*mobile*" -o -iname "*frontend*"   # empty
```
Cross-checked against `docs/backlog.md`: Sprint 3 (the Expo mobile client) is fully `TODO`, and no backlog item for a PWA or WhatsApp integration existed at all before this session — the SDD's Client Tier bullet was written aspirationally when the document was first drafted (Phase 1 SDLC work, commit `67c9d6e`) and never revisited once the project's actual build order (backend-first) diverged from it.

### 3. Key Findings
- This is the same root-cause shape as the earlier-logged Redis/Message-Broker finding from this project (`MARITCHO-2026-09-11-redis-and-background-jobs-never-built-despite-system-design.md`) — an architecture doc describing target-state components as if they were already part of the running system, with nothing distinguishing "built" from "planned."
- Unlike the Redis case, this one was caught proactively (while writing new ADRs) rather than during a dedicated architecture review — a good sign that the "planned vs. built" labeling convention introduced for the Redis fix is generalizing as a habit, but the underlying SDD still needed the same treatment applied to a second, unrelated section.

## Root Cause
`system_design.md` was drafted early (Phase 1) describing the intended full-stack topology, and was never updated to distinguish "what we've committed to building" from "what actually exists right now" as the project's real build order (backend-first, client tiers deferred) diverged from the document's original framing — the same gap already fixed once for Redis, recurring in the client-tier section because the fix wasn't generalized into a standing convention at the time.

## Prevention / Rule
**Guardrail:** Any architecture-document component/edge describing a client, integration, or service that is not yet built must be explicitly labeled `(planned, not yet built)` in prose and drawn as a dashed edge in any accompanying diagram — never left unqualified. This is now the second time this exact pattern has been fixed in this document (Redis in the earlier finding, WhatsApp/PWA/mobile here); a future SDD edit that adds a new component should apply this labeling by default rather than by review catching it a third time.

This closes the gap because it makes "not yet built" visually and textually indistinguishable from "built" impossible by convention, rather than relying on a reader (or reviewer) to separately know the project's real backlog state.

## Solution

### Immediate Fix
- `docs/architecture/system_design.md` §1: the Client Tier bullet now explicitly marks the PWA and Expo mobile app as "not yet started," and the WhatsApp line as "planned, not yet built," pointing to the new ADR-006.
- §2's component diagram: the `Client` and `WA` nodes and their edges into `API` are now dashed and labeled "not yet built" / "planned," matching the existing treatment already given to the Redis/Worker edges. The diagram's caption was rewritten to state plainly that only the FastAPI backend and its PostgreSQL connection are real and tested today.
- Added a new §6, "Explicitly Rejected Patterns," and reconciled the case-study review into four new ADRs (002–005) plus this WhatsApp-specific one (006), so the SDD now carries both what's planned and why, rather than an unqualified list.

### Long-term Fix
None needed beyond the guardrail above — this is a documentation-only fix with no code or schema impact.

## Prevention
- [x] Corrected `system_design.md` §1 and §2 to mark all not-yet-built client-tier components explicitly
- [x] Added ADR-006 recording the WhatsApp decision and its current (not-started) status
- [ ] Sweep the rest of the architecture docs (`database_schema_design.md`, `openapi.yaml`, `schema.sql`) for any other unqualified "as if built" claims the next time a substantial doc-reconciliation pass happens — not done exhaustively this session, since this fix was scoped to the section touched while writing the new ADRs

## Related Issues
- Same root-cause shape as `MARITCHO-2026-09-11-redis-and-background-jobs-never-built-despite-system-design.md` (this project's first instance of this pattern)

## References
- `docs/discovery/business_case.md` — the actual, correctly-scoped source of the WhatsApp requirement ("Scope: Web app and WhatsApp channel" — Stage One)
- `docs/backlog.md` — Sprint 3 (`APP-001`–`APP-003`), confirming the mobile client was never built
- `docs/architecture/adr/006-whatsapp-business-api-intake.md`

---

**Resolved By:** Claude Code (Zimbabwe-adjusted case-study reconciliation session)
**Time to Resolution:** Same day, caught while drafting unrelated new ADRs

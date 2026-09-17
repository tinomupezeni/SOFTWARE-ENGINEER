# ADR-005's WebSocket Choice for Order Tracking Was a Poor Fit for Zimbabwe's Mobile Network Conditions

**Date:** 2026-09-16
**Project:** ZimDash
**Environment:** Development (documentation/architecture decision, not yet implemented)
**Severity:** Low
**Status:** Resolved

## Summary
ADR-005 (2026-09-04, FastAPI backend pivot) specified FastAPI WebSockets to replace Supabase
Realtime for order-state and live-tracking updates, without considering the specific network
conditions the client actually runs under. External research on comparable on-demand delivery
platforms operating in variable/expensive-mobile-data environments identifies WebSockets as a
recurring poor fit for exactly this case: they need custom heartbeat maintenance, recover slowly
from frequent cellular drops, and add stateful proxy complexity — all avoidable given that the
traffic in question (order status, courier location) is purely server→client. No ZimDash document
had evaluated this tradeoff before ADR-005 was written; the WebSocket choice was made by default
(likely because "FastAPI + WebSockets" is a common pairing in tutorials) rather than by evaluating
it against the constrained/expensive mobile data explicitly named as a non-functional requirement in
the SRS.

## Symptoms
- ADR-005 Decision: "FastAPI WebSockets will replace Supabase Realtime for order state and live
  tracking updates" — no alternative considered, no reference to the SRS's own "usable over
  constrained mobile data" non-functional requirement.
- `docs/planning/tasks.md` ZD-M1-05/ZD-M1-09 scoped WebSocket server/client work directly from
  ADR-005 with no discussion of reconnection behavior on cellular networks.
- No document mentioned Server-Sent Events (SSE) as an alternative, despite ZimDash's traffic shape
  (order tracking, dispatch state) being unidirectional server→client — exactly SSE's use case.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/ZIM_DASH`
- **Services Affected:** documentation/architecture only — no application code exists yet for either
  WebSockets or SSE
- **Related Components:** `docs/architecture/adr/ADR-005-fastapi-custom-backend.md`,
  `docs/planning/tasks.md` (ZD-M1-05, ZD-M1-09), `docs/requirements/srs.md` Section 1
- **Time First Observed:** 2026-09-16, while reviewing an external architecture research document
  the user shared covering delivery-platform patterns for the Zimbabwean market

## Investigation Steps

### 1. Initial Diagnosis
Compared ADR-005's real-time transport choice against the user-supplied research spec's own ADR-002
("Real-Time Communication Protocol for Order Tracking"), which explicitly weighs polling vs.
WebSockets vs. SSE for exactly this use case.

### 2. Root Cause Analysis
ADR-005 bundled the real-time transport decision in with several unrelated FastAPI-adoption
decisions (ORM choice, JWT auth, hosting) without a dedicated tradeoff analysis. The SRS's own
non-functional constraint ("usable over constrained mobile data") existed at the time ADR-005 was
written but wasn't cross-checked against the WebSocket choice.

### 3. Key Findings
- SSE gives automatic reconnection over plain HTTP/2 with lower overhead — a better match for
  ZimDash's actual traffic (unidirectional, tolerant of connect gaps) than WebSockets.
- The only real cost is that SSE can't carry client→server real-time messages — irrelevant here
  since ZimDash's client-to-server actions (cancel, accept) are already normal REST calls, not
  planned to run over the same channel.

## Root Cause
The real-time transport decision in ADR-005 was made without a dedicated tradeoff evaluation against
the project's own documented non-functional constraint (constrained mobile data), rather than an
incorrect implementation of a correct decision.

## Prevention / Rule
**Guardrail:** Any ADR touching a non-functional requirement already listed in the SRS (performance,
reliability, security, accessibility, localization/network conditions) must include a line
explicitly stating which SRS constraint it was checked against — a lightweight, greppable marker
(e.g. `**Checked against SRS:** <constraint>`) that a doc-review pass can verify is present before
the ADR is marked Accepted.

This closes the gap directly: ADR-005 would have been checked against "usable over constrained
mobile data" at write time instead of nine days later, if that line had been a required field.

## Solution

### Long-term Fix
Added [ADR-006](../../ZIM_DASH/docs/architecture/adr/ADR-006-sse-realtime-protocol.md), which
supersedes the real-time-transport portion of ADR-005 (all other ADR-005 decisions — FastAPI,
JWT auth, Alembic/Postgres — are unaffected and remain accepted) adopting SSE over HTTP/2. Updated
every downstream reference across `README.md`, `docs/requirements/srs.md`,
`docs/architecture/system_design.md` (component diagram + Section 5), `docs/security/threat_model.md`,
`docs/planning/risk_register.md`, `docs/planning/project_plan.md`, and `docs/planning/tasks.md`
(ZD-M1-05, ZD-M1-09) in the same session, so no document contradicts the new decision.

## Prevention
- [x] Add ADR-006 documenting the SSE decision and its rationale.
- [x] Update all downstream docs referencing the WebSocket approach.
- [ ] Adopt the "Checked against SRS" marker convention on future ADRs (see Guardrail above).

## Related Issues
- [[2026-09-16-adr005-fastapi-pivot-not-propagated-to-sdlc-docs]] — the broader doc-drift issue this
  was found while re-verifying.

## References
- `docs/architecture/adr/ADR-005-fastapi-custom-backend.md`
- `docs/architecture/adr/ADR-006-sse-realtime-protocol.md`
- User-supplied research: "Architecture and Engineering Reference Specification for an On-Demand
  Last-Mile Delivery Marketplace in Zimbabwe" (external document, 2026-09-16)

---

**Resolved By:** Claude Code (found while reviewing user-supplied architecture research; fixed same
session at user's request)
**Time to Resolution:** Same session

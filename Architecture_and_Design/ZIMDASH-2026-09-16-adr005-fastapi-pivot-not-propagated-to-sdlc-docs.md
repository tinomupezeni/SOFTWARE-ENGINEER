# ADR-005 (Supabase → Custom FastAPI Pivot) Never Propagated to Downstream SDLC Docs

**Date:** 2026-09-16
**Project:** ZimDash
**Environment:** Development (documentation only)
**Severity:** Medium
**Status:** Resolved

## Summary
On 2026-09-04, ADR-005 was accepted, reversing the project's backend
architecture from managed Supabase (Postgres + Auth + RLS, ADR-002) to a
self-hosted custom FastAPI service with Alembic-managed Postgres, custom JWT
auth, and WebSockets. ADR-002 was correctly marked `Deprecated (Superceded by
ADR-005)`, and `docs/planning/tasks.md` was added the same session describing
FastAPI-based engineering tasks. However, every other document in the SDLC
set — README, Vision Document, Business Case, PRD, SRS, System Design
Document, Risk Register, and Threat Model — still describes Supabase/
PostgREST/RLS as the current and only backend architecture, with no mention
of ADR-005, the FastAPI pivot, or `tasks.md`. A reader following the
document index from the README would build a mental model of the system that
contradicts the most recent accepted architectural decision.

## Symptoms
- `README.md` document index and "Current phase" section describe RLS as the
  authorization layer and list no FastAPI-related task file.
- `docs/requirements/srs.md` Section 1 states the backend transport is
  "Supabase client SDK ... not a custom OpenAPI-first backend" — the literal
  opposite of ADR-005's decision.
- `docs/architecture/system_design.md` Section 1's component diagram and
  Section 4 ("there is no application server ZimDash operates") both describe
  the pre-ADR-005 topology as current.
- `docs/discovery/business_case.md` costs a Supabase Pro tier and no
  self-hosted VPS/FastAPI hosting line item.
- `docs/planning/risk_register.md` R-6 and `docs/security/threat_model.md`
  Zone 3 both frame the FastAPI/payment server as a hypothetical "future"
  component not yet built, rather than a decided architecture with tasks
  already assigned in `tasks.md`.
- `docs/planning/project_plan.md` Epic 1/2 tasks still reference "requires a
  new server-side component per ADR-002's open consequence" instead of
  ADR-005's concrete FastAPI/Alembic/JWT/WebSocket plan.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/ZIM_DASH`
- **Services Affected:** documentation only — no application code exists yet
  for either architecture
- **Related Components:** `docs/architecture/adr/ADR-002-*.md` (correctly
  updated), `docs/architecture/adr/ADR-005-*.md` (source of truth),
  `docs/planning/tasks.md` (correctly reflects the pivot)
- **Time First Observed:** 2026-09-16, initial repo/documentation read-through

## Investigation Steps

### 1. Initial Diagnosis
Read the full SDLC document set per the README's document index, then
compared it against `git log` and file mtimes.

### 2. Root Cause Analysis
```bash
git log --oneline -10
find . -name "*.md" -newer docs/architecture/adr/ADR-002-supabase-managed-postgres-rls.md -not -path './.git/*'
```
Only `docs/planning/tasks.md` and `ADR-005-fastapi-custom-backend.md` were
touched in the 2026-09-04 ~21:46 session that introduced the pivot (per
`stat` mtimes); the other nine SDLC documents retain their original
2026-09-04 18:36 content from before the decision was made. The most recent
commit (`2ceaa28 docs: restructure M-1 for FastAPI pivot and add SDLC
tasks`) added `tasks.md` and ADR-005/ADR-002 edits but did not touch the
Vision Document, Business Case, PRD, SRS, System Design Document, Risk
Register, Threat Model, or README.

### 3. Key Findings
- ADR-005 is internally consistent and correctly marks ADR-002 as
  superseded — the decision record itself is fine.
- The drift is one-directional: downstream/dependent docs (SRS, SDD, PRD,
  Business Case, Risk Register, Threat Model, README) were never
  regenerated or hand-updated after the ADR that supersedes their
  architectural assumptions.
- This repo's own stated purpose (per README) is to be "the documentation
  layer for" the actual codebase — so an internally contradictory doc set is
  the primary defect surface here, not a side effect.

## Root Cause
No document in this repo declares a dependency on the ADRs it's derived
from beyond a one-line "traceability" footer, so nothing forced the eight
downstream documents to be revisited when ADR-005 superseded ADR-002 in the
same session `tasks.md` was added.

## Prevention / Rule
**Guardrail:** When an ADR's `Status` changes to `Superseded`/`Deprecated`,
require every document listed in `README.md`'s document index that cites the
old ADR (via its "Traceability" footer or inline reference) to be updated or
explicitly re-affirmed in the same commit — enforced by a simple CI/pre-commit
grep that fails if a commit touches an ADR's Status line without also
touching at least one file that references that ADR's ID.

This closes the gap directly: the drift here happened because ADR-002's
status flip and ADR-005's addition landed in a commit that never touched
SRS/SDD/PRD/Business Case/Risk Register/Threat Model/README, and nothing
flagged that omission.

## Solution

### Long-term Fix
Updated all nine affected documents to reflect ADR-005 as the current
architecture, while explicitly preserving Phase 0/Supabase content as
labeled historical context rather than deleting it:
- `README.md` — document index now lists ADR-005 and `tasks.md`; "Current
  phase" and "What's here" sections describe the FastAPI pivot.
- `docs/discovery/vision_document.md` — Section 4 (Technical goals) and
  Section 5 (Infrastructural & Operational Constraints) rewritten for
  self-hosted FastAPI/JWT.
- `docs/discovery/business_case.md` — cost table replaced Supabase line item
  with self-hosted VPS; risk matrix row replaced Supabase free-tier risk
  with self-hosted ops-overhead risk.
- `docs/requirements/prd.md` — "Row-level data isolation" BDD scenario now
  describes FastAPI JWT/ownership-check enforcement instead of Postgres RLS.
- `docs/requirements/srs.md` — Sections 1, 3, 4, 5 rewritten for FastAPI
  transport/JWT auth/ownership-scoped queries/`/health` endpoints.
- `docs/architecture/system_design.md` — Sections 1, 2, 3, 4, 5 rewritten:
  new component diagram, self-hosted VPS deployment topology, `users` table
  added, JWT-based network boundary, observability tied to the now-real
  backend.
- `docs/planning/risk_register.md` — R-6/R-7 reframed from "hypothetical
  future component"/Supabase free tier to the now-decided FastAPI service's
  real attack surface and self-hosted capacity risk; R-3 mitigation updated.
- `docs/security/threat_model.md` — trust boundaries, asset classifications,
  and the full STRIDE ledger updated for JWT auth/self-hosted Postgres/the
  FastAPI webhook and WebSocket surfaces (Zone 3 is no longer hypothetical).
- `docs/planning/project_plan.md` — Epic 1/2 tasks now point at ADR-005 and
  the corresponding `tasks.md` task IDs instead of "ADR-002's open
  consequence."
- Also added a one-line pivot note to ADR-003 and ADR-004, whose Decision
  text still named Supabase Auth specifically, clarifying the concept they
  record (anonymous identity; Provider + shared_preferences) still holds
  while the underlying mechanism/fallback target moved to the FastAPI
  service.

## Prevention
- [x] Update README document index / "Current phase" to reflect ADR-005.
- [x] Rewrite SRS Section 1 (Technical Interfaces) for FastAPI/JWT/WebSockets.
- [x] Rewrite System Design Document Sections 1, 2, 4, 5 for the
  self-hosted FastAPI + Alembic Postgres topology.
- [x] Update Business Case cost table for VPS hosting instead of Supabase
  Pro tier.
- [x] Update Risk Register R-6 and Threat Model Zone 3 from "hypothetical
  future component" to the now-decided FastAPI architecture, and re-run
  STRIDE analysis against it (new attack surface: self-hosted JWT auth,
  Alembic migrations, WebSocket endpoint).
- [x] Update Project Plan Epics 1/2 task descriptions to point at ADR-005
  instead of "ADR-002's open consequence."
- [ ] Adopt the CI/pre-commit guardrail proposed above so this class of
  drift is caught automatically on the next superseding ADR.

## Related Issues
- None yet filed for this project.

## References
- `docs/architecture/adr/ADR-002-supabase-managed-postgres-rls.md`
- `docs/architecture/adr/ADR-005-fastapi-custom-backend.md`
- `docs/planning/tasks.md`

---

**Resolved By:** Claude Code (found during initial codebase/documentation
read-through; fixed same session at user's request)
**Time to Resolution:** Same session

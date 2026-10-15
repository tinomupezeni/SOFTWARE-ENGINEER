# VerifiedHQ Zimbabwe Attendance Product Direction

**Date:** 2026-10-15
**Project:** VerifiedHQ
**Type:** Audit / Architecture Decision / Scope Decision
**Status:** Completed

## Summary
Reviewed the VerifiedHQ codebase, its research and gap documents, and public
GitHub projects implementing geofenced, offline, and HR attendance workflows.
The recommended Zimbabwe-market MVP is a trusted attendance evidence pipeline:
server-authoritative check-in/out, offline outbox replay with idempotency,
geofence-violation and missed-checkout approval queues, and payroll-ready export.
Biometrics, ambient BLE/Wi-Fi presence, and deep HRIS integrations should follow
after this vertical slice is reliable.

## Context / Trigger
The user requested a codebase review, comparison with similar public GitHub
projects, and a practical solution for Zimbabwean companies based on the
repository's research documents.

## Scope
Included:
- Current backend, mobile, admin, research, requirements, backlog, and gap
  analysis review.
- Public GitHub comparison for geofenced attendance, offline-first attendance,
  and open-source HR/payroll systems.
- Identification of the highest-value product slice for Zimbabwean employers.

Excluded:
- Implementing the selected product slice; the request did not specify which
  behavioral scope to approve, and several choices affect data protection and
  operational policy.
- Treating public repositories as production-ready security references.

## Method
Compared documented requirements with source code and recent repository history,
then reviewed public repositories and their implementation patterns:

- `Monzerdh/Geofence-Attendance-App`
- `MadhavPruthi/HR-Management-and-Geo-Attendance-System`
- `frappe/hrms`
- `horilla-opensource/horilla`

The review emphasized offline behavior, duplicate prevention, exception
handling, payroll interoperability, and evidence integrity.

## Decisions & Findings
1. **Primary customer problem:** a GPS punch alone does not prove continued
   presence. It also fails operationally when connectivity is intermittent or
   power/network availability is affected.
2. **Zimbabwe-specific product fit:** the system should tolerate low-cost
   Android devices and intermittent connectivity, support manager review rather
   than silently rejecting questionable punches, and export records in a format
   payroll teams can consume.
3. **Best reusable pattern:** `Monzerdh/Geofence-Attendance-App` uses a local
   outbox, client `local_id` plus a database uniqueness constraint for replay
   safety, explicit geofence violations, missed-checkout correction, and
   approval-driven creation of canonical attendance records.
4. **Mature HR capability:** `frappe/hrms` and Horilla provide broader shift,
   leave, attendance, and payroll workflows. VerifiedHQ should integrate with or
   export to such systems instead of recreating the complete HRMS domain first.
5. **Current implementation reality:** VerifiedHQ already has initial nonce,
   signature, event, sensor-fusion, anomaly, and multi-entity model code, but
   the gap analysis is stale and materially understates those implementations.
   Production-critical pieces remain incomplete, especially offline persistence
   and idempotency, device attestation, full exception workflow, migration
   verification, and payroll export.
6. **Recommended delivery order:** build one end-to-end trusted attendance slice
   before adding biometric/PAD or ambient-signal complexity:
   - canonical check-in/out event contract;
   - encrypted mobile outbox with local event ID;
   - idempotent server ingestion and replay handling;
   - geofence uncertainty/violation queue;
   - missed-checkout and attendance-correction workflow;
   - CSV/payroll export with an auditable status.

## Changes Made
- Added the related issue log:
  `Architecture_and_Design/VERIFIEDHQ-2026-10-15-stale-gap-analysis.md`.
- No VerifiedHQ source files were modified.

## Verification
- Read `Research.md`, `ARCHITECTURE.md`, `docs/GAPS_ANALYSIS.md`,
  `docs/backlog.md`, requirements, and relevant source files.
- Inspected current FastAPI check-in, sensor-fusion, SQLAlchemy model, and
  Flutter client implementations.
- Queried GitHub's public repository search API and reviewed comparable project
  documentation and source trees.
- Confirmed the documentation/source discrepancy with line-level evidence.

## Follow-ups / Deferred
- Choose whether the first implementation slice should target employee BYOD,
  shared kiosk, or both.
- Define the employer policy for uncertain/off-zone events and manager approval
  deadlines.
- Confirm the target payroll export format and whether Belina, PayDay, or
  another Zimbabwe payroll system is the first integration.
- Reconcile the stale gap analysis before using it as the delivery backlog.
- Add a threat model and focused regression tests before implementing new trust
  boundaries.

## References
- `Research.md`
- `docs/GAPS_ANALYSIS.md`
- `docs/backlog.md`
- `backend/app/routers/checkin.py`
- `backend/app/sensor_fusion.py`
- `mobile/lib/services/api_service.dart`
- `mobile/lib/services/crypto_service.dart`
- `Monzerdh/Geofence-Attendance-App`
- `frappe/hrms`
- `horilla-opensource/horilla`

---

**Completed By:** Copilot
**Duration:** One review session

# Remote-work signal (REMOTE event type, end to end)

**Date:** 2026-10-04
**Project:** Attendance
**Type:** Feature implementation (user-directed, post-Phase-3)
**Status:** Completed

## Summary
Off-premise employees get a WORK REMOTELY button sending a signed `REMOTE` event: backend skips polygon matching and scores device posture (0.75 → SUSPICIOUS review queue, rooted → hard reject), dashboard shows Remote badge + Remote-today KPI with one-click approve. Live-verified with real ECDSA-signed check-ins against throwaway PostGIS.

## Context / Trigger
User: remote staff need a one-button signal, as simple as possible.

## Scope
Included: `sensor_fusion` REMOTE branch, mobile button + flow, admin badge/override/KPI/evidence, 002 applied to the live dev volume.
Excluded: REMOTE-specific scoring tuning, WAN-IP signal (still uncaptured).

## Method
Backend branch → mobile caller → admin consumer. Behavioral script with generated P-256 keys exercised accept + rooted-reject + ledger persistence.

## Decisions & Findings
- REMOTE lands at 0.75/SUSPICIOUS by design: manager confirms in the existing queue rather than auto-trusting off-site claims.
- Live check caught a real `NameError` (`gps` out of scope in `_create_event`) — fixed to `request.telemetry.gps`; also corrected a wrong test assertion (rejected attempts persist as REJECTED events per PRD, which is correct behavior).
- `dart analyze`: zero errors/warnings (8 pre-existing infos).

## Changes Made
VerifiedHQ `db24de8` (5 files): `sensor_fusion.py`, `checkin_screen.dart`, ledger index/show, `DashboardController` + dashboard view.

## Verification
- `dart analyze` clean; `php artisan test` 3 passed; backend pytest 3 passed.
- `remote_check.py` vs throwaway PostGIS+Redis: SUSPICIOUS 0.75, rooted 403, gps+device persisted — passed.

## Follow-ups / Deferred
- WAN-IP capture for a remote-location corroborating signal.
- REMOTE in CSV export columns (already included via shared export).

## References
- Plan: `Attendance/docs/admin-dashboard-plan.md` (Phase 3 + this item).

---

**Completed By:** Remote-signal session
**Duration:** Same day

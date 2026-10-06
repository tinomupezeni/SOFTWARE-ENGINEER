# Stale Form-4 Combined Science subject (SCI_O) alongside live 4003

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`)
**Severity:** Medium
**Status:** Investigating (fix in progress)

## Summary
The student DB holds two Form-4 Combined Science subjects: live `4003` (21 topics, 28 published papers) and stale `SCI_O` (0 topics, 11 published papers, 0 attempts ever). `SCI_O` exists nowhere admin-side — a July-2 seed leftover whose upstream removal never propagated (same withdrawal-propagation gap class as the Sept-27 paper fix). 76 student profiles enroll via `SCI_O`, and AI-generated papers keep spawning under it (11 dupes and counting). The purpose-built cleanup tool (`merge_legacy_subjects`, pair `SCI_O→4003` already listed) dry-runs to zero on prod because it hardcodes board code `ZIM-HBCA` while prod reads `ZIMSEC-HBCA`.

## Symptoms
- Students see two identical "Combined Science" entries; one is content-empty.
- `merge_legacy_subjects` dry-run on prod: "Would merge: 0" despite 76 affected profiles.
- Same shape beside it: 67 profiles on `ENG_O`, 92 on `MATH_O` (pairs `ENG_O→4005`, `MATH_O→4004` already in the tool).

## Environment Details
- **Server/Host:** gpu-ndime, `hbec_student` DB
- **Services Affected:** student curriculum listings, onboarding picks, AI paper generation target
- **Related Components:** `curriculum_subject`, `practice_paper`, `accounts_studentprofile.subjects`, `merge_legacy_subjects`, `reconcile_stalled_subject_merges`
- **Time First Observed:** 2026-10-06 (row dates to 2026-07-02 seed)

## Investigation Steps

### 1. Initial Diagnosis
Ranked `curriculum_subject` content (topics/papers/attempts) for every Combined Science row; confirmed `SCI_O` has papers but no topics and no admin counterpart (`subjects` holds only `4003*`).

### 2. Root Cause Analysis
- `SCI_O` row created 2026-07-02 (seed era); papers kept syncing onto it as recently as 2026-10-03 — paper replication doesn't validate subject existence.
- All 11 papers are AI-generated (`session='AI'`), quality 0, duplicated titles, zero attempts: machine output, not admin content.
- Profiles store subject *codes* (`["SCI_O","ENG_O","MATH_O"]`), so enrollment follows the stale row.
- Ran the cleanup tool's dry-run on prod via the green backend: zero matches; traced to `_BOARD_CODE = "ZIM-HBCA"` vs prod `ZIMSEC-HBCA`. The sibling `reconcile_stalled_subject_merges` already documents this exact staging-vs-prod code variant and matches by shared board id instead.

### 3. Key Findings
- Do NOT "move papers to 4003 for admin verification": admin can never see student-side rows, and these are regenerable AI dupes — withdraw them instead.
- Do NOT rename the prod board code to satisfy the tool: admin + student agree on `ZIMSEC-HBCA`, and replication/API key on the code string. The tool must stop depending on the string (as its sibling already does).

## Root Cause
Stale seed-era subject row + no subject-delete propagation (TBD whether deletes propagate at all) + cleanup tooling pinned to another environment's board code.

## Prevention / Rule
**Guardrail:** no cleanup/matching command may filter on a hardcoded exam-board code string — resolve the board by id (same board, same grade), exactly as `reconcile_stalled_subject_merges` already does. Board codes are environment-variant data, not constants.

## Solution

### Immediate Fix
In progress: mirror the sibling's board resolution into `merge_legacy_subjects` (same-board-id + same-grade matching, drop `_BOARD_CODE`), with a test on a deliberately non-`ZIM-HBCA` board code; then dry-run → unpublish the 11 AI dupes → `--apply` → verify counts → inactivate `SCI_O`. (`is_active=False` is supported and honored by listings; no row deletes.)

### Long-term Fix
- Same treatment for `ENG_O`/`MATH_O` (pairs already listed; verify counts first).
- Propagate subject deletes/withdrawals downstream (verify whether anything does today).
- Stop AI paper generation from targeting inactive subjects (else the dupes regrow).

## Prevention
- [ ] Board-agnostic matching in both merge commands (+ regression tests)
- [ ] Onboarding/listing audit: inactive subjects must be unpickable AND ungeneratable
- [ ] Code changes required (the merge-tool fix; deploy to idle color, dry-run, apply)

## Related Issues
- `Database_and_State/HBEC-2026-10-06-bulk-sync-retry-and-dns-failures.md` (replication gaps, same pipeline family)

## References
- `STUDENT/hbec_backend/apps/curriculum/management/commands/merge_legacy_subjects.py` (`_MERGE_PAIRS`, `_BOARD_CODE`)
- `.../reconcile_stalled_subject_merges.py` (board-id resolution precedent + comments)
- Override persistence: `/opt/hbec/redis-failover-20261006.green-override.yml` (unrelated, same session)

---

**Resolved By:** TBD (fix in progress)
**Time to Resolution:** TBD

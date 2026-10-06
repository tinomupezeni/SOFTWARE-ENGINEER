# Stale Form-4 Combined Science subject (SCI_O) alongside live 4003

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`)
**Severity:** Medium
**Status:** Resolved

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
**Applied 2026-10-06.** Mirrored the sibling's board resolution into
`merge_legacy_subjects` (same-board-id + same-grade matching, dropped
`_BOARD_CODE`) — commit `23483bc1` — with a regression test on a
deliberately non-`ZIM-HBCA`/non-`ZIMSEC-HBCA` board code. That commit also
ported the sibling's per-topic savepoint safety (a blind bulk `Topic`
move can hit a real `(release, subject, code)` uniqueness collision and
abort the whole merge — already hit once on the sibling command).

Dry-run then surfaced the full scope — not just `SCI_O`: `ENG_O` (68
profiles, 0 papers), `MATH_O` (93 profiles, 6 papers), `SCI_O` (77 profiles,
11 papers). All 17 papers across `MATH_O`/`SCI_O` carried the identical
zero-quality, zero-attempt AI-dupe signature (`quality_score=0.0`,
`session` in `{AI, unknown}`) confirmed by direct inspection before
touching anything. A second fix (commit `b8c8ff33`) added an explicit
`exclude(status=ARCHIVED)` to the paper-move step, so archiving them first
(status flip only, same row, same subject FK) keeps them off the canonical
subject permanently rather than relying on status-filtering elsewhere to
hide them — matching the original intent ("withdraw, don't move to 4003")
precisely rather than indirectly.

Executed against production (green, `hbec-student-backend-green`, the
code copied in via `docker cp` for this one-off run rather than a full
image rebuild — student containers have no code volume mount):
1. Archived the 17 confirmed junk papers (`status=ARCHIVED`).
2. Re-ran dry-run: all 3 pairs now show 0 papers, confirming the exclusion
   worked.
3. `--apply`: 3 subjects merged, 238 student profiles remapped, 0 papers
   re-pointed (all correctly left behind, archived, on the now-inactive
   legacy subjects).
4. Verified: `SCI_O`/`MATH_O`/`ENG_O` all `is_active=False`; 0 archived
   papers attached to `4003`/`4004`/`4005`; 0 student profiles still
   reference any legacy code.

### Long-term Fix
- Propagate subject deletes/withdrawals downstream (verify whether
  anything does today) — still open, not addressed by this fix.
- Stop AI paper generation from targeting inactive subjects (else the
  dupes regrow) — still open.

## Prevention
- [x] Board-agnostic matching in both merge commands (+ regression tests)
- [x] Archived papers excluded from the canonical subject on merge (+ test)
- [ ] Onboarding/listing audit: inactive subjects must be unpickable AND
      ungeneratable (not verified this session)
- [ ] Stop AI paper generation from targeting inactive subjects

## Related Issues
- `Database_and_State/HBEC-2026-10-06-bulk-sync-retry-and-dns-failures.md` (replication gaps, same pipeline family)

## References
- `STUDENT/hbec_backend/apps/curriculum/management/commands/merge_legacy_subjects.py`
- `.../reconcile_stalled_subject_merges.py` (board-id resolution precedent + comments)
- Commits `23483bc1` (board-agnostic matching + topic-collision safety), `b8c8ff33` (archived-paper exclusion)

---

**Resolved By:** Tinotenda Mupezeni; original investigation and in-progress fix by Muse Spark (opencode)
**Time to Resolution:** Same day — fix completed and applied to production hours after discovery.

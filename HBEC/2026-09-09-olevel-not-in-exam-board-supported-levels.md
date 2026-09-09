# O-Level Silently Unselectable — Dropped From Every Exam Board's `supported_levels`

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Production (bug) / Staging (code fix deployed and verified 2026-09-09)
**Severity:** Critical
**Status:** Code Fix Deployed to Staging — Production Data Fix Still Pending

**Correction (same day):** this was originally attributed to a specific student report (`mutsa.mutepfa@students.uz.ac.zw`, a tester account) on the theory that a university-adjacent account being stuck on Primary/Grade-4 meant O-Level personalization had silently failed for her. That attribution was **wrong** — her account was deliberately set up for Primary/Grade-4 testing, and her actual complaint (profile page showing "no subject selected" while the Add-Subject flow correctly said "all already selected") turned out to be a separate, still-open frontend issue, not this one. The O-Level exam-board bug documented below is independently real and confirmed — via direct production DB inspection and a second account (`mupezeni2001@gmail.com`) whose UI still shows stale O-Level-tagged content from before this regression — just not the cause of the report that originally surfaced it.

## Summary
Neither exam board in the production database currently declares `zimsec_olevel` in `supported_levels`, so no student going through personalization can land on O-Level at all, regardless of what they actually need. O-Level is the platform's documented entry point (`vision.md`: "we enter through the exam classes"), so this affects every O-Level-bound student currently onboarding or resetting their level.

## Symptoms
- Student report: "no longer seems [I] can see subjects."
- Her `SubjectListView` response is non-empty (6 subjects) but wrong for her — Grade 4 primary curriculum, not O-Level.
- `level_last_reset_at = 2026-09-09 05:45:50 UTC`, `level_change_count = 1` — a genuine, DB-committed first assignment made hours before the complaint, not a caching artifact.

## Environment Details
- **Server/Host:** `hbca-vps` production (`/opt/hbec`, `hbec-postgres`, DB `hbec_student`)
- **Services Affected:** Student Backend (`STUDENT/hbec_backend`) — `apps.curriculum`, `apps.accounts`, `apps.replication`
- **Related Components:** `SubjectListView`, `StudentProfile.can_change_level`, the admin→student curriculum replication stream
- **Time First Observed:** 2026-09-09, via a direct student support report

## Investigation Steps

### 1. Initial Diagnosis
Queried the student's account directly against production Postgres to rule out an empty/broken query before looking at code:

```bash
ssh hbca-vps 'PW=<redacted>; docker exec -e PGPASSWORD="$PW" hbec-postgres psql -U hbec -d hbec_student -x -c "
WITH me AS (
  SELECT u.id AS user_id, u.email, sp.grade, sp.level, sp.exam_board_id, sp.is_complete,
         sp.subjects AS onboarding_subjects, sp.level_change_count, sp.level_last_reset_at
  FROM accounts_user u LEFT JOIN accounts_studentprofile sp ON sp.user_id = u.id
  WHERE u.email = '\''mutsa.mutepfa@students.uz.ac.zw'\''
)
SELECT me.*, eb.code, eb.is_active,
  (SELECT count(*) FROM curriculum_grade g WHERE g.exam_board_id = me.exam_board_id AND g.code = me.grade AND g.is_active) AS grade_known_count,
  (SELECT count(*) FROM curriculum_subject s WHERE s.exam_board_id = me.exam_board_id AND s.level = me.level AND s.is_active) AS subjects_level_examboard_only,
  (SELECT count(*) FROM curriculum_subject s WHERE s.exam_board_id = me.exam_board_id AND s.level = me.level AND s.grade_code = me.grade AND s.is_active) AS subjects_with_grade_filter
FROM me LEFT JOIN curriculum_examboard eb ON eb.id = me.exam_board_id;"'
```

Result: `level=primary`, `grade=GRADE-4`, `exam_board_code=ZIM-HBCA` (active), `grade_known_count=1`, `subjects_with_grade_filter=6`. The backend was not returning zero — it was returning the *wrong six*.

### 2. Root Cause Analysis
Listed the 6 subjects and every exam board in the system:

```sql
SELECT code, name, level, grade_code FROM curriculum_subject
WHERE exam_board_id = '2ca0b0af-cee9-4126-8006-83fc80a544f0' AND level='primary' AND grade_code='GRADE-4' AND is_active;
-- 401 English Language, 402 Mathematics, 403 Indigenous Language, 404 Agriculture/Science/Tech, 406 Social Sciences, 407 PE and Arts

SELECT id, code, name, is_active, supported_levels FROM curriculum_examboard ORDER BY code;
--  CAIE     | Cambridge Assessment International Education | inactive | ["zimsec_alevel","primary","lower_secondary"]
--  ZIM-HBCA | Heritage Based Curriculum Assistant           | active   | ["zimsec_alevel","primary","lower_secondary"]
```

Both boards — the only two that exist — omit `zimsec_olevel`. Traced `level_last_reset_at`/`level_change_count` to their one writer: `StudentProfile.can_change_level()` (`STUDENT/hbec_backend/apps/accounts/models.py:325-357`), called from `apply_personalization()` (`apps/accounts/personalization_service.py:83`), itself hit by `StudentPersonalizationView.post` (`apps/accounts/views.py:725`) and `ChildPersonalizationView` (`apps/accounts/parent_views.py:240`). No cron/scheduled job touches these fields — this was a live, first-ever personalization submission, not a background reset.

Traced the field to its actual source. `supported_levels` (student side, the name used above) does not exist as a stored field on Admin's side at all — it's derived at replication time (`ADMIN/adminBackend/apps/replication/signals.py:64`, `_serialize_exam_board`) from `ExamBoard.grade_levels` (`apps/exam_boards/models.py`), a `JSONField` with **no validation at all** — editable as raw, unstructured JSON straight from the Django admin panel (`apps/exam_boards/admin.py` restricted nothing) or via a DRF `PATCH` (`ExamBoardCreateSerializer.gradeLevels` was a bare `ListField(child=CharField())`, accepting literally any string). No seed script or migration owns the `ZIM-HBCA` board (`grep -r "ZIM-HBCA"` across Admin's Python turned up nothing outside one unrelated comment) — it was created and edited entirely by hand through the admin UI/API, and the value that landed there (`["a_level","primary","lower_secondary"]`, confirmed by reading the live Admin DB row directly) is simply missing `o_level` and contains one value (`"lower_secondary"`) that matches nothing on either side. `stream_consumer.py`'s `_handle_exam_board` (`STUDENT/hbec_backend/apps/replication/stream_consumer.py:401-410`) translates Admin's own phase vocabulary (`primary`/`o_level`/`as_level`/`a_level`) into the student backend's canonical Level codes on receipt — via a lookup that passes any *unrecognized* string through unchanged rather than rejecting it, which is exactly why a typo like this shipped invisibly instead of erroring anywhere.

### 3. Key Findings
- `level_change_count=1` with `self.level` starting `""` confirms this was the account's *first* level submission, not a corruption of prior data — there's an unresolved open question already logged in `planning/state.md:68-70` about whether a first assignment should consume a change credit at all, but that's a quota-fairness issue, separate from this bug.
- The personalization flow can only ever commit `primary`, `lower_secondary`, or `zimsec_alevel` today, because that's the full set any exam board in the live DB supports.
- A second account (`mupezeni2001@gmail.com`, `level=zimsec_alevel`, `grade=form-6`) still has old O-Level-labelled subjects showing in its Topic Revision UI, evidence that O-Level content and enrollment existed on this platform before — this is not a feature that was never built, `zimsec_olevel` support has regressed out of the live exam board configuration since then. (Full mechanism for *that* account's specific symptom is a separate, unrelated auth bug — see Related Issues.)

## Root Cause
Admin's `ExamBoard.grade_levels` for `ZIM-HBCA` — the only active exam board — is missing `o_level`, almost certainly a hand-edit typo/omission through the Django admin's unvalidated raw-JSON textarea for this field. There was nothing anywhere in the stack (model validator, serializer, admin widget, or a coverage test) that could have caught a level silently disappearing from an active board's configuration. Since Admin is the sole content authority and this field replicates near-verbatim to the student backend, every personalization submission was left able to resolve only to `primary`, `as_level`/`a_level`, or `other` — never O-Level, the platform's documented entry point.

## Solution

### Implemented (code, deployed to staging 2026-09-09)
- `ADMIN/adminBackend/apps/exam_boards/models.py`: added `LEVEL_CHOICES`/`VALID_LEVEL_CODES` (Admin's own phase vocabulary — `primary`/`o_level`/`as_level`/`a_level`/`other`/`igcse`) and a `validate_grade_levels` validator on the field.
- `ADMIN/adminBackend/apps/exam_boards/serializers.py`: `ExamBoardCreateSerializer.gradeLevels` is now a `ChoiceField`-validated list — the same mistake now 400s through the API instead of saving silently.
- `ADMIN/adminBackend/apps/exam_boards/admin.py`: replaced the raw JSON textarea with checkboxes (`ExamBoardAdminForm`), the likely proximate cause of the original typo.
- Corrected the same latent vocabulary mistake already sitting in `seed_zimsec.py` and `seed_curriculum.py` — both had been using the wrong vocabulary for `ExamBoard.grade_levels` too, meaning a fresh environment bootstrap would have recreated a version of this exact bug from scratch.
- Added regression tests (`apps/exam_boards/tests/test_models.py`, new `test_serializers.py`) covering valid/invalid/cross-vocabulary values.
- Deployed to staging via manual promotion (`docs/MANUAL_DEPLOY_PROMOTION.md`'s process, since the automated `cd.yml` staging deploy stalled again — see the GitHub Actions billing doc) and verified live: `ExamBoardCreateSerializer` now rejects `gradeLevels: ["lower_secondary"]` and accepts `["o_level","a_level"]`.

### Still pending — production data fix
The actual live `ZIM-HBCA` exam board record (both on `hbca-vps` production, and its staging counterpart, and the separate environment on `zchpc-hbca-vps`) still has the broken `grade_levels` value — the code fix prevents this recurring, it doesn't retroactively correct existing data. That requires a real `ExamBoard.save()` (via the Admin API/UI or a Django shell `ALTER`-equivalent, never raw SQL, so the `on_exam_board_save` replication signal fires) on each environment's own Admin database — deliberately not done automatically, since it mutates production data.

## Prevention
- [x] Code changes: `grade_levels` now validated at the model, serializer, and admin-widget layers (done, staging-verified)
- [x] Regression tests added for the vocabulary mix-up specifically
- [ ] Production data fix: correct the live `ZIM-HBCA` record on `hbca-vps` prod, `hbca-vps` staging's own Admin DB, and `zchpc-hbca-vps` (three independent Admin databases)
- [ ] Monitoring/alerts to add: alert when an exam board's level coverage shrinks while active students exist on the level being dropped
- [ ] Documentation to update: note in `CLAUDE.md`'s heritage/exam-board section that `grade_levels` is safety-critical for personalization, not just a display filter

## Related Issues
- [2026-09-09: Silent Auth Failure Falls Back to Stale Guest-Cached Subjects](./2026-09-09-stale-guest-subjects-on-silent-auth-failure.md) — surfaced in the same investigation, different account, unrelated root cause (auth/caching, not exam-board config)
- [2026-09-09: Staging Postgres/Pgbouncer Password Drift](./2026-09-09-staging-postgres-secret-drift-crash-loop.md) — hit while deploying this fix to staging, unrelated to this bug
- [2026-07-01: Subject Disappearing Bug (Grade Filtering Mismatch)](./2026-07-01-subject-filtering-bug.md) — an earlier, distinct subject-visibility bug in the same `SubjectListView`

## References
- `STUDENT/hbec_backend/apps/curriculum/views.py:145-258` (`SubjectListView`)
- `STUDENT/hbec_backend/apps/accounts/models.py:325-357` (`StudentProfile.can_change_level`)
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py:401-410` (`_handle_exam_board`, `phase_to_level`)
- `ADMIN/adminBackend/apps/exam_boards/models.py` (`LEVEL_CHOICES`, `validate_grade_levels`)
- `ADMIN/adminBackend/apps/exam_boards/serializers.py`, `admin.py`
- `ADMIN/adminBackend/apps/replication/signals.py:64` (`_serialize_exam_board`)
- `ADMIN/adminBackend/apps/curriculum/management/commands/seed_zimsec.py`, `seed_curriculum.py`
- `planning/state.md:68-70` (open, unrelated question on first-assignment quota)
- `vision.md` ("We enter through the exam classes")
- Commits: `1527ebb8`, `cb9d20ff` (the second corrects a wrong vocabulary assumption in the first — see its own message)

---

**Diagnosed and fixed by:** Claude Code (Sonnet 5) — code fix staging-verified; production data fix still outstanding on three environments
**Time to Diagnosis:** ~40 minutes

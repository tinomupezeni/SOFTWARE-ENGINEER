# Seed corpus exam_board codes don't match any deployed ExamBoard

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging (confirmed also present in Production data)
**Severity:** High
**Status:** Investigating

## Summary
`seed_exam_papers --dry-run` against staging resolved 0 of 684 seed files —
every single one failed with "no board". The seed corpus (`seeds/exam_papers/`,
merged in from the `experimental` branch) tags every paper with
`exam_board: "ZIMSEC"` or `exam_board: "CAMBRIDGE"`, but neither code exists
as an `ExamBoard` row in any environment.

## Symptoms
- `docker exec hbec-admin-backend-staging python manage.py seed_exam_papers
  --dir /tmp/seeds/exam_papers --aliases /tmp/seeds/reference/subject_aliases.json
  --dry-run` reported `papers created=0 updated=0 questions=0` and listed all
  684 seed files under `no board (684)`.

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142)
- **Services Affected:** Admin Backend seeding pipeline
  (`apps/exam_papers/management/commands/seed_exam_papers.py`), and by
  extension anything downstream that depends on this seed content reaching
  the student backend.
- **Related Components:** `seeds/tools/extract_papers.py`,
  `seeds/tools/extract_cambridge.py` (corpus generation), `apps/exam_boards`
  (the actual `ExamBoard` table)
- **Time First Observed:** 2026-09-21, during a staging deploy of the merged
  `experimental` seeding work

## Investigation Steps

### 1. Initial Diagnosis
Ran the documented dry-run per `seeds/README.md`. Every one of 684 files
failed identically with `board {code!r}` unresolved, not a subset — pointed
at the board lookup itself rather than a subject/grade issue.

### 2. Root Cause Analysis
```bash
docker exec hbec-admin-backend-staging python manage.py shell -c \
  "from apps.exam_boards.models import ExamBoard; print(list(ExamBoard.objects.values_list('code','name')))"
# -> [('ZIM-HBCA', 'Heritage Based Curriculum Assistant')]

docker exec hbec-admin-backend python manage.py shell -c \
  "from apps.exam_boards.models import ExamBoard; print(list(ExamBoard.objects.values_list('code','name')))"
# (production) -> [('CAIE', 'Cambridge Assessment International Education'), ('ZIM-HBCA', 'Heritage Based Curriculum Assistant')]

python3 -c "import json,glob,collections; c=collections.Counter(); \
  [c.update([json.load(open(f)).get('exam_board')]) for f in glob.glob('seeds/exam_papers/**/*.json', recursive=True) if not f.endswith('_skipped.json')]; \
  print(c)"
# -> Counter({'CAMBRIDGE': 346, 'ZIMSEC': 338})
```

### 3. Key Findings
- Production's real board codes are `ZIM-HBCA` and `CAIE`.
- The seed corpus's extraction tooling wrote `ZIMSEC` and `CAMBRIDGE` instead
  — plausible/human-readable names, but not the codes the database actually
  uses anywhere, in any environment.
- This is not staging drift: production has the identical mismatch, so the
  seed command has never been able to resolve a single one of these 684
  files against a real deployment, only against whatever ad hoc local DB the
  extraction/validation tooling was tested against.
- `seed_exam_papers` behaves correctly here — "a subject that does not exist
  is reported, not invented" extends to boards too (`board is None` short
  circuits per-file, nothing is silently created). The corpus, not the
  seeder, has the wrong assumption.

## Root Cause
`seeds/tools/extract_papers.py` and `extract_cambridge.py` hardcode
`exam_board: "ZIMSEC"` / `"CAMBRIDGE"` as the board code written into every
seed file, without checking that value against the `ExamBoard.code` values
the target databases actually use (`ZIM-HBCA`, `CAIE`).

## Prevention / Rule
**Guardrail:** `seeds/tools/validate_seeds.py` should reject any seed file
whose `exam_board` value is not one of a fixed, explicit allow-list of real
`ExamBoard.code` values (`ZIM-HBCA`, `CAIE`) — the same kind of closed-set
check the command already applies to `question_type` against `KNOWN_TYPES`.
That turns this from a seed-time discovery (684 files deep into a staging
deploy) into an extraction-time or pre-commit failure, before the files ever
reach `seeds/`.

## Solution

### Immediate Fix
Not yet applied — pending a decision on whether to bulk-rewrite the
`exam_board` field in all 684 seed JSON files, or add `ZIMSEC`/`CAMBRIDGE` as
accepted aliases resolved to `ZIM-HBCA`/`CAIE` inside `seed_exam_papers.py`
(mirroring how `GRADE_EQUIVALENTS` already handles a same-cohort spelling
difference). Seeding into staging is blocked until one of these lands.

### Long-term Fix
Add the allow-list validation described above to `validate_seeds.py` so a
future extraction run can't reintroduce an unresolvable board code.

## Prevention
- [ ] Decide and apply the field-vs-alias fix for the 684 existing seed files
- [ ] Add board-code allow-list check to `seeds/tools/validate_seeds.py`
- [ ] Re-run `seed_exam_papers --dry-run` on staging to confirm resolution
- [ ] Documentation to update: `seeds/README.md` / `seeds/AUTHORING.md` should
      state the exact accepted `exam_board` values, not just "ZIMSEC" as an
      example

## Related Issues
- Landed via commits `d44a80fa`, `cea124fd`, `467f1f74`, `983b5d10` on
  `experimental`, merged to `master` 2026-09-21 (`e119d2e6`).

## References
- `ADMIN/adminBackend/apps/exam_papers/management/commands/seed_exam_papers.py`
- `seeds/README.md`, `seeds/AUTHORING.md`

---

**Resolved By:** (unresolved — blocked pending decision)
**Time to Resolution:** N/A

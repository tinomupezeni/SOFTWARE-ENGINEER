# Admin Generation's Level String Never Matches Real Content, Blocking Grounding Platform-Wide

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** Critical
**Status:** Resolved

## Summary
Found while auditing content-population gaps ahead of launch: admin AI
generation's syllabus, exemplar, and house-style grounding all filter on an
exact `level` string match, but admin sends grade names ("Form 4") while
every real piece of content in the harness is tagged with exam-tier buckets
("O-Level"/"A-Level"/"grade_7"/"primary"). These never intersect. This
affects every Form-based subject in the curriculum — the large majority of
the 136 active subject+grade combinations — regardless of how much real
content exists for them.

## Symptoms
- No direct error — generation "succeeds" but silently runs ungrounded.
- Harness logs consistently show `papergen_no_exemplars` and
  `syllabus entries=0` for subjects later confirmed to have real content
  when queried directly.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Agentic Harness (`_fetch_syllabus`, `_fetch_exemplars`, `_measure_house_style`)
- **Related Components:** Admin curriculum `Subject`/`Grade` models
- **Time First Observed:** 2026-09-09, during a proactive content-gap audit

## Investigation Steps

### 1. Initial Diagnosis
Queried the harness's own `curriculum_content` and `papers` tables directly
for `level` values actually in use: only `A-Level`, `O-Level`, `grade_7`,
`primary`, and NULL ever appear — never a "Form N" string.

### 2. Root Cause Analysis
Confirmed in code: `_fetch_syllabus`, `_fetch_exemplars`, and
`_measure_house_style` all filter with `Paper.level == level_h` (or the
equivalent for `CurriculumContent`). Admin generation computes `level_h`
from `Subject.grade.name` (e.g. "Form 4"), passed straight through — the
existing `_LEVEL_CODE_MAP` translation table only covers the *student*
backend's canonical codes (`zimsec_olevel`, `zimsec_alevel`, `igcse`,
`primary`), which the admin path never sends.

### 3. Key Findings
- Ran a full audit across all 136 active subject+grade combinations: 111
  (81%) have zero syllabus and zero real exemplar content of any kind.
  Only 25 have anything, concentrated in a handful of subjects (Mathematics,
  English Language, Combined Science, Geography, Physics, a few smaller
  pockets).
- Of those 25, none are actually reachable by today's admin generation —
  the level-string mismatch zeroes them out regardless of real content
  volume. Syllabus content happens to mostly work anyway today only because
  it's currently all tagged NULL-level (universal), which the syllabus
  query treats as a wildcard — exemplars and house-style have no such
  escape hatch and are fully blocked.
- This is not a "differentiate by grade" problem to solve — ZIMSEC's real
  structure already groups Form 1-4 as O-Level and Form 5-6 as A-Level, so
  pooling grounding content across those forms is the *correct* behavior,
  not a bug to work around.

## Root Cause
No translation exists from admin's grade-name vocabulary ("Form 4") to the
exam-tier vocabulary ("O-Level") that all real content is actually tagged
with.

## Prevention / Rule
**Guardrail:** A single canonicalization function (`_normalise_level()`) is
the only place in the codebase allowed to translate between one service's
vocabulary and another's — enforce with a code-review/lint rule that no
other file may compare a locally-computed level/tier-like string directly
against another service's stored value. Pair it with a test that iterates
every distinct `Grade.name` value actually present in the admin database
and asserts each one normalizes to a known tier, so a brand-new grade name
fails CI immediately instead of silently generating ungrounded content.

This targets the exact failure shape here: two independently-evolving
vocabularies (admin's grade names, the harness's exam-tier codes) with no
enforced single point of translation between them, and no test that would
catch a new value on either side falling through untranslated.

## Solution

### Immediate Fix
None needed — no production incident, caught proactively on staging.

### Long-term Fix
Added `_normalise_level()` in `paper_generator.py`, replacing direct
`_LEVEL_CODE_MAP` lookups. It first checks the student-backend code map
(`zimsec_olevel`, etc.), then falls back to a set of grade-name regex
patterns: `Form 1-4` → `O-Level`, `Form 5/6` → `A-Level`, `Grade 7` →
`grade_7`, any other `Grade N` → `primary`. Applied at the single call site
that computes `level_h`, so `_fetch_syllabus`, `_fetch_exemplars`, and
`_measure_house_style` all inherit the fix without being touched
individually. Deployed to staging and verified live: admin generation for
Form-based subjects now finds real exemplars/house-style content instead of
running ungrounded.

## Prevention
- [x] Fix deployed and verified live on staging (commit `b68d017e`)
- [x] 16 unit tests added (`TestNormaliseLevel` in
      `tests/exam_practice/test_paper_generator.py`) covering every student
      code, every grade-name pattern, and the unrecognized-input fallback —
      so a newly added `Grade.name` shape can't silently fall through
      ungrounded again without a test forcing the question

## Related Issues
- Found during the same content-population audit that produced the
  111/136 zero-content gap numbers above

## References
- `AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py`
  (`_LEVEL_CODE_MAP`, `_fetch_syllabus`, `_fetch_exemplars`, `_measure_house_style`)

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
**Commit:** `b68d017e`

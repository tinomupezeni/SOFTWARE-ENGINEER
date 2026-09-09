# Admin Generation's Level String Never Matches Real Content, Blocking Grounding Platform-Wide

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** Critical
**Status:** Investigating

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

## Solution

### Immediate Fix
None yet — fix in progress in this session.

### Long-term Fix
Extend the existing `_LEVEL_CODE_MAP`/level-resolution logic to also
translate grade names: Form 1-4 → O-Level, Form 5 (Lower 6)/Form 6
(Upper 6) → A-Level, Grade 7 → grade_7, and the remaining primary grades →
primary — applied wherever admin generation computes `level_h`, so the fix
lands in one place rather than three.

## Prevention
- [ ] Fix landing this session — this entry will be updated to Resolved
      once deployed and verified live
- [ ] Add a test asserting every real `Grade.name` in the curriculum maps
      to a recognized exam tier, so a newly added grade can't silently fall
      through ungrounded again

## Related Issues
- Found during the same content-population audit that produced the
  111/136 zero-content gap numbers above

## References
- `AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py`
  (`_LEVEL_CODE_MAP`, `_fetch_syllabus`, `_fetch_exemplars`, `_measure_house_style`)

---

**Resolved By:** In progress
**Time to Resolution:** In progress

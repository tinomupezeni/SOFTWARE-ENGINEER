# Streak/XP "Correct" Definition (Full Marks) Disagrees With Mastery's (≥50% Ratio) for the Same Event

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`), which
introduces `AGENTIC_HARNESS/app/analytics/gamification/streak_writer.py`
**Severity:** Medium (two product-facing numbers silently disagree for the
same attempt; no crash, but a real correctness/consistency defect)
**Status:** Investigating (flagged in PR review, confirmed by code read)

## Summary
`streak_writer.py:44-50` (`_answer()`, new in PR #51) defines an answer as
"correct" for streak/XP/dashboard-accuracy purposes as:

```python
return Counted(questions=1, correct=int(out_of > 0 and score >= out_of))
```

i.e. only **full marks** count as correct. But `engine.py:57`
(`AnalyticsEngine`, the sole writer of topic mastery) defines "correct" for
the identical event payload (`question_answered` / `exam_submitted`, same
`score`/`max_score` fields) as:

```python
correct=ratio >= 0.5 if max_score > 0 else False,
```

i.e. **half marks or more**. These two definitions feed different parts of
the product from the same underlying data: `streak_writer`'s result feeds
`DailyActivity.correct` (shown as lifetime "accuracy" on the dashboard,
`service.dashboard()`) and gates `award_for_answer(is_correct=...)` XP;
`engine.py`'s result drives topic mastery.

## Symptoms
None reported yet — found via code read during PR review. Would surface as:
a student answers a 5-mark question and scores 4/5. Mastery marks the topic
as understood (ratio 0.8 ≥ 0.5). The same attempt earns **no** answer XP and
counts as "incorrect" in the dashboard's accuracy stat (4 < 5), so the
dashboard silently disagrees with what mastery says about the identical
attempt. This is not a rare edge case — the repo's own corpus research notes
that 63% of ZIMSEC question parts are worth ≤3 marks, i.e. partial credit is
the norm.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (FastAPI)
- **Services Affected:** streak/XP (`gamification/streak_writer.py`,
  `gamification/xp.py`), dashboard accuracy stat
  (`gamification/service.py::dashboard`), topic mastery
  (`analytics/engine.py::AnalyticsEngine`)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Reuse angle of the PR review asked whether any new code reimplements a
concept the codebase already defines canonically — "what counts as a
correct answer" is exactly such a concept, defined once in `engine.py` for
mastery.

### 2. Root Cause Analysis
Read both functions directly: both parse `score`/`max_score` (or
`max_marks`) from the same event metadata, but apply different thresholds
(full marks vs. ≥50% ratio).

### 3. Key Findings
- No shared helper or constant ties these two thresholds together; a future
  change to either (e.g. tightening/loosening the mastery threshold) will
  not propagate to the other, and nothing will catch the drift.

## Root Cause
`streak_writer.py` was written independently of `engine.py`'s existing
"correct" definition for mastery, introducing a second, incompatible
definition of the same concept for the same event data.

## Prevention / Rule
**Guardrail:** extract one shared `is_correct(score, max_score) -> bool`
helper (ratio ≥ 0.5, matching the existing mastery definition) in
`app/shared/` and have both `engine.py` and `streak_writer.py::_answer` call
it, so "correct" means one thing everywhere a `question_answered` /
`exam_submitted` event is interpreted. Add a test asserting the two modules
agree on a partial-credit case (e.g. 4/5).

## Solution

### Immediate Fix
None yet — flagged in PR #51 review for the author to address before merge.

### Long-term Fix
Extract the shared `is_correct()` helper as described above.

## Prevention
- [ ] Extract shared `is_correct(score, max_score)` helper
- [ ] Update `streak_writer._answer()` and `engine.py` to both call it
- [ ] Add a partial-credit regression test (e.g. 4/5 → correct under mastery,
      must also be correct under streak/XP)

## Related Issues
None.

## References
- `AGENTIC_HARNESS/app/analytics/gamification/streak_writer.py:44`
- `AGENTIC_HARNESS/app/analytics/engine.py:57`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending author fix before merge

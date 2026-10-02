# Teaching Loop's `plan()` Picks a 0-of-0 Tally Over a Proven Record Because `Tally` Is Always Truthy

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`), which
introduces `AGENTIC_HARNESS/app/shared/teaching_loop.py`
**Severity:** Medium (wrong/self-contradictory teaching-move justification
injected into the tutor's prompt; no student-visible crash)
**Status:** Investigating (flagged in PR review, confirmed by executing the
module)

## Summary
In `teaching_loop.plan()` (line 220):

```python
tally = record.on_topic.get(best) or record.overall[best]
```

`Tally` is a frozen dataclass with no `__bool__`/`__len__`, so **any**
instance — including `Tally(landed=0, missed=0)` — is truthy in Python. When
a teaching move has an **open (unresolved)** row on the current topic,
`build_record()` still creates an `on_topic[move] = Tally(0, 0)` entry for it
(via `Tally.add("")`, a no-op outcome). Because that entry is truthy, the
`or` never falls through to `record.overall[best]`, even though `best` was
selected *because of* a strong overall (cross-topic) record.

## Symptoms
None in production — found and reproduced during PR review before merge.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (FastAPI)
- **Services Affected:** Learning Guide's teaching-move directive (the text
  injected into the tutor's prompt explaining why a given move was chosen)
- **Related Components:** `app/shared/teaching_loop.py` (`plan`, `Tally`,
  `build_record`)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Line-by-line diff scan of the new `teaching_loop.py` flagged the `or`
expression as suspicious for a dataclass with no custom truthiness.

### 2. Root Cause Analysis
Executed `teaching_loop.plan()` directly against a constructed
`TeachingRecord` where `overall[analogy] = Tally(2, 0)` (landed twice on
other topics) and `on_topic[analogy] = Tally(0, 0)` (an open move on the
current topic). Reproduced: `MovePlan(move='analogy', reason='an analogy
has worked on this topic (0 of 0)')` — the self-contradictory "0 of 0"
message that should instead cite the real overall record.

### 3. Key Findings
- No test in `tests/shared/test_teaching_loop.py` exercises "a proven move
  has an open row on the current topic," so this path reaches production
  untested.
- This undermines the module's own stated design goal: "every move's reason
  [should be] explainable" and attributable to real evidence.

## Root Cause
`Tally` instances are always truthy; the `or` was written assuming it would
behave like a falsy-when-empty check (as it would for `None`, `0`, or an
empty dict), but a `Tally(0, 0)` is a real, non-empty object.

## Prevention / Rule
**Guardrail:** replace the truthiness check with an explicit resolved-count
check: `on_topic_tally = record.on_topic.get(best); tally = on_topic_tally
if on_topic_tally and on_topic_tally.resolved else record.overall[best]`.
Add a unit test with a proven overall record plus an open (unresolved)
on-topic row for the same move, asserting the overall tally is reported.

## Solution

### Immediate Fix
None yet — flagged in PR #51 review for the author to address before merge.

### Long-term Fix
Fix the `tally`/`where` selection in `plan()` as described above, and add
the missing test case.

## Prevention
- [ ] Fix `tally = record.on_topic.get(best) or record.overall[best]` to
      check `.resolved` rather than truthiness
- [ ] Add a unit test for "proven overall record + open on-topic row"

## Related Issues
- `HBEC-2026-10-02-teaching-loop-topic-key-mismatch.md` (a second,
  independent bug in the same module that also affects on-topic tallying)

## References
- `AGENTIC_HARNESS/app/shared/teaching_loop.py:220`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending author fix before merge

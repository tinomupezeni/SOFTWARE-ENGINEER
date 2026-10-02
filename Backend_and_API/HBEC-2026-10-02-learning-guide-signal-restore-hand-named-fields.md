# Learning Guide's "Restore Previous-Turn State" Fix Hand-Names Two Fields Instead of Round-Tripping the Row

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`)
**Severity:** Low (design flaw / future-bug risk, not a current defect)
**Status:** Investigating (flagged in PR review as an altitude/design issue)

## Summary
PR #51 fixes a real bug: Learning Guide's previous-turn comprehension was
measured every turn and then dropped, so the direct-teaching switch (which
keys on the *previous* reading) never fired. The fix,
`session_manager.py::get_last_signal` (line 152) +
`router.py:676` (`for key in ("comprehension_level", "emotion_signal"): if
session_snapshot.get(key) is not None: graph_state[key] = ...`), hand-names
exactly these two columns off the last assistant `LearningGuideMessage` row.

`LearningGuideMessage` has other nullable "post-generation analysis" columns
written every turn and never read back either (`misconception_detected`,
`concepts_mentioned`, `metadata_`). The fix repairs the two fields that
happen to gate the direct-teaching switch today, by name, rather than fixing
the general mechanism (nothing round-trips the full set of persisted
per-turn analysis into the next turn's graph state).

## Symptoms
None currently — the two fields this PR needed are correctly restored.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (FastAPI)
- **Services Affected:** Learning Guide graph state across turns
- **Related Components:** `app/learning_guide/services/session_manager.py`
  (`get_last_signal`), `app/learning_guide/router.py` (merge loop, line 676)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Altitude angle of the PR review asked whether this fix repairs the
mechanism or patches the two symptoms that happen to matter today.

### 2. Root Cause Analysis
Read `get_last_signal` and the router's merge loop directly: both hard-code
`comprehension_level`/`emotion_signal` by name, in two separate files.

### 3. Key Findings
- The next time a new per-turn analysis field needs to inform next-turn
  behavior (e.g. `misconception_detected`), someone must remember to repeat
  this exact two-step pattern (add to the SELECT's column list and to the
  literal tuple in the router) or the field silently reverts to "every turn
  starts as though the student just arrived" — the same bug class this PR
  just fixed, for a different field, with no test to catch the omission.

## Root Cause
The fix targeted the two fields that gate `needs_direct_teaching()` rather
than building a general "round-trip persisted per-turn signals into next
turn's state" mechanism.

## Prevention / Rule
**Guardrail:** have `get_last_signal` return the full set of persisted
analysis columns from the last assistant message as a dict, and have the
router merge all non-null keys from that dict into `graph_state` in one
step, instead of enumerating field names twice across two files. This makes
adding a new analysis field a one-line schema change with no risk of a
silent second site to forget.

## Solution

### Immediate Fix
None needed now — current behavior is correct for the two fields in use.

### Long-term Fix
Generalize `get_last_signal`/the router merge as described above before the
next per-turn analysis field is added.

## Prevention
- [ ] Generalize `get_last_signal` to return all persisted analysis columns
- [ ] Generalize the router's merge loop to merge all non-null keys

## Related Issues
None.

## References
- `AGENTIC_HARNESS/app/learning_guide/services/session_manager.py:152`
- `AGENTIC_HARNESS/app/learning_guide/router.py:676`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — design note for future work

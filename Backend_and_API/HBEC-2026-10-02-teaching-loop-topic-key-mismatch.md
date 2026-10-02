# Teaching Loop Writes Moves Under the Raw Session `topic_id` but Reads Them Back Under the Inferred `working_topic`

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`), which
introduces `AGENTIC_HARNESS/app/shared/teaching_loop.py` and wires it into
Learning Guide
**Severity:** Medium-High (the on-topic half of the teaching loop silently
never populates for the most common session shape)
**Status:** Investigating (flagged in PR review, confirmed by code trace)

## Summary
The teaching loop's write and read sides key teaching-move rows on two
different values:

- **Write side** — `AGENTIC_HARNESS/app/learning_guide/router.py:1070`:
  `teaching_loop.record_move(..., topic_id=session_snapshot.get("topic_id")
  or "", ...)` — the **raw session `topic_id`**, which the surrounding code
  comments acknowledge is "often empty" for free-chat sessions.
- **Read side** — `app/learning_guide/services/tutor_agent.py:354`:
  `working_topic = resolve_working_topic(topic_id, history, message)` (falls
  back to the first substantive thing the student said when `topic_id` is
  empty), then `assemble_context(topic=working_topic, ...)` →
  `context_assembler.py:774` → `teaching_loop.load_record(student_id,
  working_topic)`.

`build_record()` keys the on-topic tally on
`topic_id.strip().lower()` (the value passed to `load_record`) and matches it
against each row's own stored `topic_id`. For any session where the raw
`topic_id` was never explicitly set, every stored row has `topic_id=""`,
while the read side looks for the non-empty inferred `working_topic` — the
two values never match, so `TeachingRecord.on_topic` stays empty forever for
these sessions, even after many resolved moves.

## Symptoms
None in production — found via code trace during PR review.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (FastAPI)
- **Services Affected:** Learning Guide's per-topic teaching-move tracking
  (`record.stuck`-driven "try an untried move" logic, and the on-topic
  preference branch in `plan()`)
- **Related Components:** `app/learning_guide/router.py` (`record_move`
  call), `app/learning_guide/services/tutor_agent.py`
  (`resolve_working_topic`, `assemble_context` call),
  `app/shared/context_assembler.py` (`_load_teaching`),
  `app/shared/teaching_loop.py` (`build_record`, `load_record`)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Cross-file tracer angle of the PR review traced `record_move`'s and
`load_record`'s respective topic arguments back to their sources and found
they come from different variables (`session_snapshot.get("topic_id")` vs.
`resolve_working_topic(...)`).

### 2. Root Cause Analysis
Read `router.py:1067-1073`, `tutor_agent.py:335-470`,
`context_assembler.py:153-163,774`, and `teaching_loop.py`'s `build_record`
(the `key = topic_id.strip().lower()` / `(row.topic_id or
"").strip().lower() == key` comparison) directly. Confirmed: for a session
with no explicit topic, `record_move` always writes `topic_id=""`, while
`load_record` is always called with a non-empty inferred topic whenever the
student's message is substantive — so the comparison in `build_record` never
matches for these rows.

### 3. Key Findings
- This is a key/identity mismatch, not a logic error inside either function
  individually — each side is internally correct, but they disagree about
  what "this topic" means.
- Free-chat sessions with no explicit `topic_id` are described in the
  surrounding code's own comments as the common case, so this likely affects
  most Learning Guide sessions, not an edge case.

## Root Cause
`record_move`'s caller (`router.py`) was not updated to resolve the same
`working_topic` that `tutor_agent.py`/`context_assembler.py` already compute
for the read side; it independently re-reads the raw session `topic_id`.

## Prevention / Rule
**Guardrail:** `record_move` must be called with the same `working_topic`
value already computed for this turn's `assemble_context` call, not a fresh
read of the raw session `topic_id`. Thread `working_topic` out of the graph
node (store it in `graph_state`/`session_snapshot` under its own key) so the
router can pass the identical value to `record_move` that `load_record` used
for this turn — one computed value, read and write both keyed on it. Add a
test: a session with no explicit `topic_id` records a move, then a second
turn's `load_record` for the same inferred topic must see it in `on_topic`.

## Solution

### Immediate Fix
None yet — flagged in PR #51 review for the author to address before merge.

### Long-term Fix
Thread `working_topic` from the context-assembly step through to
`record_move`'s call site, as described above.

## Prevention
- [ ] Pass the same `working_topic` to both `load_record` and `record_move`
- [ ] Add a test for the no-explicit-topic_id, on-topic-tally-populates case

## Related Issues
- `HBEC-2026-10-02-teaching-loop-tally-truthy-bug.md` (a second, independent
  bug in the same module's on-topic tallying)

## References
- `AGENTIC_HARNESS/app/learning_guide/router.py:1070`
- `AGENTIC_HARNESS/app/learning_guide/services/tutor_agent.py:354`
- `AGENTIC_HARNESS/app/shared/context_assembler.py:774`
- `AGENTIC_HARNESS/app/shared/teaching_loop.py` (`build_record`)
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending author fix before merge

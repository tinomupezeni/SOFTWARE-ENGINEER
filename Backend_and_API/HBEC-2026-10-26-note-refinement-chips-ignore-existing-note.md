# Topic Revision refinement chips wrote a fresh note instead of refining the existing one

**Date:** 2026-10-26
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Four Topic Revision chips — "Simpler", "More examples", "Add diagrams",
"Exam focus" — are meant to take the note a student already has and change
it along one axis. Instead, the backend never saw the existing note for any
of them, so the model wrote an unrelated note from scratch, which the
frontend then substituted for the real one: reported as "removes existing
notes and fails to [simplify / add diagrams / ...]".

## Symptoms
- Four separate user reports, all the same shape:
  - "Topic Revision: Add Diagrams" — "Removes existing notes and fails to
    generate any diagrams"
  - "Topic Revision: Simpler" — "Also removed existing notes and fails to
    simplify"
  - "Topic Revision: Exam focus" — "Exam focus removes existing notes"
  - "Topic Revision: More examples" — "Removes existing notes and fails to
    add more examples"
- No error surfaced to the student or in logs — the request "succeeds" (the
  model does return a note), it's just the wrong note.

## Environment Details
- **Server/Host:** Agentic Harness, production.
- **Services Affected:** `app/revision/router.py`, `app/revision/nodes.py`,
  `app/revision/prompts.py`.
- **Related Components:** `STUDENT/Frontend/src/features/topic-revision/`
  (chip UI and accept/restore logic — investigated, found NOT at fault, see
  below).
- **Time First Observed:** 2026-10-26, four ProjectFlow reports.

## Investigation Steps

### 1. Initial Diagnosis
Traced one chip ("Add Diagrams") end to end: UI click → request body → SSE
stream → accept/replace logic → backend prompt construction, rather than
guessing from the symptom alone.

### 2. Root Cause Analysis
`app/revision/router.py::_run_graph` only looks up and sets
`graph_state["base_note"]` (the student's existing note, for the model to
work from) when `body.depth == "expanded"` — the "More notes" feature's own
mode. All four broken chips send `depth` at its default, `"standard"`, with
a `custom_instructions` string describing the requested change (e.g. "add
diagrams"). For that combination, **no branch ran**, so `base_note` was
never set, and `app/revision/nodes.py::generate_notes`'s prompt builder has
no fallback — its only `base_note` injection is gated on
`depth == "expanded"` too. The model therefore received "generate revision
notes for topic X" plus the free-text instruction, with zero awareness that
a note already existed to be changed, and wrote a fresh, unrelated one.

On the frontend, `judgeRefinedNote()`
(`src/features/topic-revision/data/noteRefinement.ts`) only applies a
"must be longer" rejection guard when `depth === 'expanded'`; for standard
depth it accepts any non-empty result unconditionally — so the fresh,
unrelated note was always swapped in for the real one.

### 3. Key Findings
- The frontend's accept/reject and error-handling logic is correct and not
  the bug: failures/timeouts already preserve the existing note, and
  (confirmed) `rememberPrevious()` is called unconditionally on every
  accepted note replacement regardless of depth
  (`SubjectContentPage.tsx`, the `done` handler), so a student could always
  reach "Go back to my previous notes" even before this fix — the symptom
  was real but not a total loss, and no frontend change was needed once the
  backend sends a genuine refinement.
- `app/revision/schemas.py` documents `base_note`/expand semantics as
  scoped to `depth: "expanded"` only — this was a deliberate design for
  "More notes" that was never extended to the sibling free-text refinement
  chips, not an accidental regression in previously-working code.
- Existing tests (`test_expanded_notes.py`, `test_note_additions.py`) only
  ever exercised the `depth == "expanded"` paths; nothing asserted what a
  `depth: "standard"` request with `custom_instructions` should see,
  which is exactly the coverage gap that let this ship unnoticed.

## Root Cause
The backend's "give the model the note it should change, not a blank page"
logic was implemented for exactly one trigger (`depth == "expanded"`,
i.e. "More notes") and never extended to the four refinement chips, which
use the OTHER steering mechanism (`custom_instructions` at standard depth)
the harness already supports for shaping emphasis — but that mechanism
alone has no way to tell the model "and here is the note you're changing."

## Prevention / Rule
**Guardrail:** Any new "change this note" UI action must be covered by an
explicit test asserting `base_note` reaches the prompt for its exact
`(depth, custom_instructions)` request shape — not just that the directive
text exists for whichever mode first needed it. The coverage gap here
(tests for "expanded" only) is precisely what would have caught this before
four separate chips shipped against the one mode that had no such test.

## Solution

### Immediate Fix
- `router.py::_run_graph`: added a third branch — `elif body.custom_instructions:`
  (standard depth, a refinement request) — that loads the existing note via
  the same `_note_to_expand()` helper "More notes" already used, so a plain
  first-time generate or a plain "regenerate" (neither sends
  `custom_instructions`) is completely unaffected.
- `nodes.py::generate_notes`: new prompt branch, gated on both
  `custom_instructions` AND a present `base_note` (not `base_note` alone,
  so a stray value in state can never alone trigger it), injecting
  `[THE NOTE THE STUDENT HAS - REFINE THIS ONE]` + the note content, with a
  new `REFINE_NOTES_DIRECTIVE` (`prompts.py`) instructing the model to
  rewrite the existing note along the requested axis, keep the standard
  length budget (unlike "More notes", which re-scopes it), and output the
  complete revised note.
- 7 new tests (`tests/revision/test_note_refinement_chips.py`): router wires
  `base_note` for a refinement request, does not for plain
  generate/regenerate, and `depth: "expanded"` still wins over this branch
  even if `custom_instructions` also happens to be present; prompt-level
  tests confirm the refine marker and note content appear only for this
  exact combination, never bleeding into the expanded-mode marker or
  firing without an instruction.

### Long-term Fix
None needed — the fix reuses the existing, already-correct `_note_to_expand`
lookup and directive-injection pattern; no new architecture.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — none identified; consider logging when a
      `custom_instructions` request has no prior note to refine (expected
      for a first-time topic) vs. when the lookup itself fails, if this
      needs visibility later.
- [ ] Documentation to update — `schemas.py`'s field docs still describe
      `base_note` in terms of "More notes" only; worth a follow-up comment
      noting the second trigger, not done here to keep this change minimal.
- [x] Code changes required — done, see Solution.

## Related Issues
- None directly. Sibling feature "More notes" (`depth: "expanded"`) was
  already correct and is unaffected by this change.

## References
- `AGENTIC_HARNESS/app/revision/router.py` (`_run_graph`, `_note_to_expand`)
- `AGENTIC_HARNESS/app/revision/nodes.py` (`generate_notes` prompt builder)
- `AGENTIC_HARNESS/app/revision/prompts.py` (`REFINE_NOTES_DIRECTIVE`)
- `AGENTIC_HARNESS/tests/revision/test_note_refinement_chips.py` (new)
- `STUDENT/Frontend/src/features/topic-revision/components/TopicContent.tsx`
  (`NOTE_REFINEMENTS`, the 4 chips — confirmed not at fault)
- `STUDENT/Frontend/src/features/topic-revision/data/noteRefinement.ts`
  (`judgeRefinedNote`, `rememberPrevious` — confirmed not at fault)

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** Same session as reported

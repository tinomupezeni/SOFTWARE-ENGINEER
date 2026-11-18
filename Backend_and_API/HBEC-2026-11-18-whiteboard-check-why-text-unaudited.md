# Whiteboard arithmetic audit never read a CheckItem's wrong-answer diagnoses

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in /code-review of PR #157, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`_texts()`, the function that extracts a board item's text for the
arithmetic-audit check, pulled only a `CheckItem`'s `prompt` and `options`,
never its `why` list (the per-option wrong-answer diagnosis shown to the
learner). A false numeric claim inside a diagnosis — e.g. "No — half of 10
is 6" — was therefore never caught, directly contradicting this module's own
stated purpose ("a confidently wrong board is worse than a shorter one").

## Symptoms
Not yet observed in production — caught in code review before merge. Would
have surfaced as a learner being shown a confidently wrong worked explanation
on a missed check question, with no code check ever looking at that text.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (Whiteboard pillar)
- **Services Affected:** `app/whiteboard/checks.py` (`_texts`,
  `arithmetic_problems`)
- **Related Components:** `app/whiteboard/board_script.py` (`CheckItem.why`)
- **Time First Observed:** N/A — code review

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` on PR #157 noted that `_texts()`'s `CheckItem` branch read
`[item.prompt, *item.options]` and nothing else, while `CheckItem.why` — free
text written by the model, one entry per option — was never passed to the
audit.

### 2. Root Cause Analysis
The arithmetic audit was built against the fields present when `CheckItem`
was first written (`prompt`, `options`); `why` was added later as a
per-option diagnosis field and the audit's text-extraction function was
never revisited.

### 3. Key Findings
- `arithmetic_problems` is driven entirely by what `_texts()` returns per
  item; anything it omits is invisible to the audit by construction.
- `why` is free text written by the model and is exactly the kind of content
  this audit exists to check (it routinely contains numeric claims, e.g.
  "No, that's $3 + $4 = $8").

## Root Cause
`_texts()`'s `CheckItem` branch was incomplete relative to the fields that
actually carry model-written prose on that item type.

## Prevention / Rule
**Guardrail:** A test asserting that every `StrictStr`/`list[StrictStr]`
field on each board item type dataclass is represented somewhere in
`_texts()`'s output for that type — so adding a new free-text field to any
item type fails a test until the extractor is updated, instead of silently
leaving it unaudited.

This closes the gap because the bug was exactly a free-text field invisible
to the one function responsible for surfacing text to the audit.

## Solution

### Immediate Fix
```python
if isinstance(item, CheckItem):
    return [item.prompt, *item.options, *item.why]
```

### Long-term Fix
Add the field-coverage test described above so a future field addition to
any board item type is caught automatically rather than depending on someone
remembering to update `_texts()`.

## Prevention
- [x] Code changes required (done)
- [ ] Field-coverage test — not added in this pass, worth doing before the
  next board-item schema change.

## Related Issues
- Found alongside two other Whiteboard/picture-repair bugs in the same
  review pass: `HBEC-2026-11-18-whiteboard-tickitem-dangling-reference.md`,
  `HBEC-2026-11-18-picture-swap-asymmetric-key-check.md`.

## References
- `AGENTIC_HARNESS/app/whiteboard/checks.py`
- `AGENTIC_HARNESS/app/whiteboard/board_script.py`

---

**Resolved By:** Claude Sonnet 5 (fork agent)
**Time to Resolution:** Same session as discovery

# Whiteboard drop_items left dangling TickItem references

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in /code-review of PR #157, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`drop_items` in the Whiteboard pillar's board-safety checks scrubbed dangling
`MarkItem` references to a removed board item, but not `TickItem` references,
even though `TickItem` carries the identical `target: Identifier` shape. A
`TickItem` left pointing at an item the arithmetic audit had just dropped
violated the board kit's own invariant that every `target` must resolve to a
still-present item.

## Symptoms
Not yet observed in production — caught in code review before merge. Would
have surfaced as a `TickItem` on a board turn pointing at a `PlanItem` that no
longer exists, which the board kit's generation-time validator forbids but
this post-hoc repair path did not re-check.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (Whiteboard pillar)
- **Services Affected:** `app/whiteboard/checks.py` (`drop_items`), used by
  the arithmetic-audit repair path that removes items with false numeric
  claims from a turn before it reaches the student
- **Related Components:** `app/whiteboard/board_script.py` (`TickItem`,
  `MarkItem`, `Turn` validator)
- **Time First Observed:** N/A — code review

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` on PR #157 flagged that `drop_items`'s list comprehension only
excluded `MarkItem`s pointing at a dropped id, not `TickItem`s, despite both
having a `target: Identifier` field.

### 2. Root Cause Analysis
`MarkItem` and `TickItem` were added to the board schema at different times;
the item-dropping safety net was written against `MarkItem` only and never
revisited when `TickItem` was introduced with the same `target` shape.

### 3. Key Findings
- `TickItem.target` and `MarkItem.target` are both `Identifier` references
  into the same turn's items.
- `drop_items` is the one function responsible for keeping the turn's
  cross-references consistent after items are removed for failing the
  arithmetic audit.
- No test exercised a `TickItem` referencing a dropped item.

## Root Cause
`drop_items`'s filter checked `isinstance(i, MarkItem) and i.target in ids`
only, omitting the structurally identical `TickItem` case.

## Prevention / Rule
**Guardrail:** Any new board-item type that carries a `target: Identifier`
field must be added to `drop_items`'s exclusion filter in the same commit —
enforced going forward by a test that constructs a turn with every
`target`-carrying item type pointed at a dropped id and asserts none survive
`drop_items`.

This closes the gap because the bug was exactly a new reference-carrying type
being added without updating the one place that scrubs dangling references.

## Solution

### Immediate Fix
Extended `drop_items`'s filter to also exclude `TickItem`s whose `target` is
in the dropped-ids set:

```python
kept = [
    i
    for i in turn.items
    if i.id not in ids
    and not (isinstance(i, MarkItem) and i.target in ids)
    and not (isinstance(i, TickItem) and i.target in ids)
]
```

### Long-term Fix
Consider a shared `_targets_removed_item` check keyed off a common
`HasTarget` protocol/mixin rather than one `isinstance` branch per item type,
so a future reference-carrying item type fails loudly (a missing branch) or
is covered automatically.

## Prevention
- [x] Code changes required (done)
- [ ] A generic "every target-carrying item type is covered" test — worth
  adding before the next board-item type is introduced.

## Related Issues
- Found alongside two other Whiteboard/picture-repair bugs in the same
  review pass: `HBEC-2026-11-18-whiteboard-check-why-text-unaudited.md`,
  `HBEC-2026-11-18-picture-swap-asymmetric-key-check.md`.

## References
- `AGENTIC_HARNESS/app/whiteboard/checks.py`
- `AGENTIC_HARNESS/app/whiteboard/board_script.py`

---

**Resolved By:** Claude Sonnet 5 (fork agent)
**Time to Resolution:** Same session as discovery

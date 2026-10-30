# Diagram canvas's role="img" would have flattened its interactive children from assistive tech

**Date:** 2026-10-30
**Project:** Archi
**Environment:** Development
**Severity:** Medium (accessibility)
**Status:** Resolved

## Summary

The webview's canvas `<svg>` root carried `role="img"`, a role whose ARIA semantics mean "a single, non-interactive graphic" — screen readers and other assistive technology generally treat an `img`-role element's subtree as flattened/opaque, meaning the diagram's actual interactive content (every node and edge is individually a `role="button"`, keyboard-focusable element) could be hidden from or misreported by assistive tech, even though the visual/mouse/keyboard interaction worked fine for sighted keyboard users. Found during the Phase 6 accessibility review, not reported by a user.

## Symptoms

- No user-reported symptom; found by code review against the plan's explicit "accessible labels" requirement, reasoning through what `role="img"` actually means for a subtree of focusable children rather than assuming the existing roles were already correct.

## Environment Details

- **Server/Host:** N/A — local VS Code extension webview.
- **Services Affected:** The diagram canvas in all three views (System, Data, Flows) — same rendering code (`render()` in `media/main.js`) for all of them.
- **Related Components:** None beyond the one `svg(...)` call constructing the canvas root.
- **Time First Observed:** Phase 6 accessibility pass, 2026-10-30.

## Investigation Steps

### 1. Initial Diagnosis

Reviewing `media/main.js`'s `render()` for the plan's accessibility requirement, found:

```js
const root = svg('svg', { ..., role: 'img', 'aria-label': 'Architecture diagram' });
```

### 2. Root Cause Analysis

Checked the ARIA spec's definition of the `img` role against what the canvas actually contains: dozens of `role="button"`, `tabindex="0"` node and edge elements with their own `aria-label`s and keyboard handlers (already correctly built in earlier phases). `role="img"` is defined for a single graphic with no exposed interactive descendants — assigning it to a container that *does* have meaningfully interactive descendants is a direct semantic contradiction, not merely a suboptimal choice.

### 3. Key Findings

- Every node (`.map-node`) and edge hit-target (`.link-hit`) already had correct, individual accessibility markup (`role="button"`, `tabindex="0"`, `aria-label`, `Enter`/`Space` keydown handlers) — this was never the problem.
- The single `role="img"` on their shared ancestor was the only thing wrong, but it was wrong at exactly the point that determines whether assistive tech exposes those children at all.

## Root Cause

`role="img"` was chosen for the canvas root early on (plausibly by analogy to "this is a picture of an architecture diagram") without checking that ARIA's `img` role specifically implies a non-interactive, flattened subtree — which directly conflicts with the canvas's actual, deliberately interactive content.

## Prevention / Rule

**Guardrail:** Any ARIA role assigned to a container with interactive descendants must be checked against that role's spec definition for whether it implies descendants are hidden/flattened from the accessibility tree (`img`, `presentation`, and `none` all do this) — not chosen by surface-level name match to what the element visually is. `group` (or `application`/`graphics-document` for a full custom widget) is the correct family for "a container of interactive things," never `img`.

## Solution

### Immediate Fix

Changed the canvas root's `role` from `'img'` to `'group'`, which does not suppress descendant semantics, while keeping the same `aria-label`.

### Long-term Fix

None needed; a regression test (`test/webview.test.cjs`) now asserts the canvas SVG's `role` is `'group'` and that a sampled node/edge each still carry `role="button"` + `tabindex="0"`, so a future change back to `role="img"` (or any role that flattens children) would fail a test instead of only being caught by a future manual review.

## Prevention

- [x] Code changes required (done, see above)
- [x] Documentation to update — `Archi/PHASE6_REVIEW.md` records this
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A (no automated accessibility audit tool is wired into CI yet; this was a manual review)

## Related Issues

- Found during the same accessibility pass described in `reports/ARCHI-2026-10-30-phase6-quality-and-distribution.md`.

## References

- `media/main.js` — the fix (`render()`'s SVG root construction).
- `test/webview.test.cjs` — the new regression test ("the canvas and its nodes/edges expose an accessible, non-flattened role tree").
- [WAI-ARIA: the `img` role](https://www.w3.org/TR/wai-aria-1.2/#img) — defines the semantics that made this role the wrong choice here.

---

**Resolved By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Time to Resolution:** Same session, caught before any release.

# Cockpit was clipped to a spec pane and no verdict below 1024px

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
Below 1024px the cockpit degraded to a single-column grid with implicit `auto` rows. The spec
pane — which has no height cap in that mode — grew to its full content height, and the root's
`overflow-hidden` clipped the editor and the telemetry pane out of existence. The result was
exactly the two things the product is not: a readable spec pane and no verdict, collision
timeline, or editor. The review's prescribed fix was not a tighter squeeze but a deliberate
state, and the layout is now gated on a container query so the cockpit is either laid out
properly or not rendered at all.

## Symptoms
- At widths under 1024px the editor and telemetry pane were invisible.
- The collision timeline — the product's centrepiece — was unreachable.
- No message explained why; the screen simply appeared broken.
- Breakpoint was a viewport media query, so it ignored the space the cockpit actually had.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite)
- **Services Affected:** `src/routes/index.tsx` (`ArchCode` root, new `NarrowNotice`)
- **Related Components:** `SpecPane`, `EditorPane`, `TelemetryPane`
- **Time First Observed:** 2026-09-25, HIG design review finding 6

## Investigation Steps

### 1. Initial Diagnosis
Read the grid definition against the review's analysis.

```bash
grep -n "grid-cols-1 lg:grid-cols" src/routes/index.tsx
# <div className="grid min-h-0 flex-1 grid-cols-1 lg:grid-cols-[minmax(280px,30%)_1fr]">
```

### 2. Root Cause Analysis
`grid-cols-1` applies at every width; `lg:grid-cols-[...]` only overrides it at ≥1024px. Below
that the grid has one column and therefore implicit `auto` rows. `SpecPane` is an `<aside>` in
a `flex-col` with no `min-h-0`, so in an `auto` row it sizes to content; the sibling column
holding the editor and telemetry is a `1.15fr/1fr` grid inside a `flex-1` parent that has
nothing left to divide. The root's `overflow-hidden` then clips the remainder rather than
scrolling it.

```bash
# the two ingredients of the bug
grep -n "overflow-hidden" src/routes/index.tsx   # root clips
grep -n "grid-cols-1" src/routes/index.tsx       # implicit auto rows
```

### 3. Key Findings
- The failure was not "tight" but "absent". No amount of breakpoint tuning fixes an `auto` row
  competing with an `fr` sibling under `overflow-hidden`; the layout has to be replaced.
- The review asked for the breakpoint to follow *available space* rather than device type
  (`layout.md › Size classes`). A viewport `lg:` query cannot do that: it counts scrollbars and
  browser chrome the cockpit never had.
- The review suggested linking to the read-only problem brief. **No brief route exists** in this
  scaffold, so the suggested fix would have produced a link to nowhere — the same class of dead
  affordance removed in the two preceding entries. The brief is rendered inline instead.
- The brief text existed in two places-in-waiting; hoisted to `BRIEF_TITLE` / `BRIEF_BODY` so the
  spec pane and the narrow state cannot drift.

## Root Cause
A responsive fallback was written as a *degradation* rather than a *decision*. `grid-cols-1` was
assumed to be a safe default, but below the two-column threshold the panes have fundamentally
different height requirements, and `auto` rows resolve that in the one way that guarantees
clipping.

## Prevention / Rule
**Guardrail:** `scripts/verify-semantics.ts` asserts a layout contract — the cockpit grid has no
`grid-cols-1` fallback and no viewport `lg:` breakpoint; a container query gates the cockpit at
exactly 1024px and hides the narrow state at exactly 1024px; a `NarrowNotice` exists and states
the 1024px requirement; the brief is rendered inline rather than linked; `BRIEF_BODY` is defined
once; and no `href` points at a brief route.

This closes the gap because the bug is a *pair of classes* whose interaction with `fr`/`auto`
rows and `overflow-hidden` is invisible to types, lint, and the DOM. It is also silent by
construction: a clipped pane throws no error. Asserting the absence of the specific fallback and
the presence of a deliberate replacement is the only mechanism that catches a reintroduction.

## Solution

### Immediate Fix
- Root is now `@container`, and the breakpoint is a **container query** (`@min-[1024px]`) rather
  than the viewport `lg:` variant, per `layout.md › Size classes`.
- The cockpit is wrapped in `hidden … @min-[1024px]:flex`; the `grid-cols-1` fallback is deleted.
  The two-column grid is now unconditional, because it only ever renders where it fits.
- New `NarrowNotice` renders below the threshold: the 1024px requirement, why it exists, and the
  **problem brief inline** (title, body, difficulty, domain, language) — the one part that
  genuinely reflows.
- Brief hoisted to `BRIEF_TITLE` / `BRIEF_BODY`, shared by `SpecPane` and `NarrowNotice`.

```bash
npm run verify    # 90 assertions, then tsc --noEmit
npx eslint src/ scripts/
npx vite build
```

### Long-term Fix
- Step 5 adds panes to this layout. The container query means that work is now gated on real
  available space, so a future third column degrades predictably instead of silently clipping.
- Native menu commands (blocked on the Tauri/Electron decision) should gate on the same
  availability check rather than duplicating it.

## Prevention
- [x] `grid-cols-1` fallback removed — the cockpit is laid out or not rendered
- [x] Breakpoint moved from viewport media query to container query
- [x] Deliberate narrow state with the 1024px requirement stated
- [x] Brief rendered inline; no link to a nonexistent route
- [x] Brief hoisted to one definition
- [x] Layout contract added to `verify-semantics.ts`, wired into `npm run verify`
- [x] All 11 layout rules negative-tested
- [x] Cascade order verified in the built CSS (both gates emit after base `.hidden`)
- [ ] `npm run verify` in CI

## Known Caveats
- **Not visually confirmed at any width.** The review itself noted it "could not confirm the
  failure visually; it follows from the grid definitions, and is worth a 30-second check at
  900px." That check still has not happened — no browser is available in this environment. The
  *absence* of the reported bug is now argued from the grid definitions and a source-order check
  of the built CSS, which is weaker than seeing it.
- **Pressing `?` in a narrow window still opens the shortcut sheet**, which lists pane bindings
  for panes that are not rendered. Harmless (it is a reference), but slightly incoherent. Gating
  it would need a `matchMedia`/`ResizeObserver` in JS, which was judged not worth the
  complexity for a milestone gap.
- The narrow state is English-only copy, consistent with the rest of the scaffold.

## Related Issues
- `ARCHCODE-2026-09-26-fabricated-verdicts-and-editable-overclaim.md` — the verdict this bug hid.
- `ARCHCODE-2026-09-26-primary-actions-live-but-inert.md` — the header density that made this
  worth folding in before step 5.
- `ARCHCODE-DESIGN-REVIEW.md` finding 6 — the original analysis.

## References
- `layout.md › Adaptability` — "Design a layout that adapts gracefully and consistently"
- `layout.md › Size classes` — gate breakpoints on available space, not device type
- `split-views.md › Phone (iOS)` — multiple panes need horizontal room
- `ARCHCODE-PRD.md` §13 — the collision timeline is desktop-only media
- CSS Containment — container queries (`container-type: inline-size`)

---

**Resolved By:** Claude (Anthropic)
**Time to Resolution:** ~1 session

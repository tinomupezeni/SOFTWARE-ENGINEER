# Radix `TabsContent` unmounts inactive panels by default, silently resetting Vision scan and Mesh buffer state on any tab switch

**Date:** 2026-10-02
**Project:** OrePulse Tech (pixel-perfect, `/home/shadowe/Projects/ORE PULSE/pixel-perfect`)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`src/routes/index.tsx` renders the three OrePulse tabs (`geotech`, `vision`, `mesh`) with
plain `<TabsContent value="...">`, which is the shadcn/Radix default: only the active panel
is mounted, the other two are unmounted entirely (not just CSS-hidden). Each tab's component
(`OreGradeScanner`, `MeshHealth`) keeps its demo-scenario state in local `useState`, so
switching away from a tab and back threw that state away and remounted the component fresh.
This is invisible in the scripted, linear demo flow (visit each tab once, in order) but
breaks immediately under any non-linear navigation — a live judge clicking around, or a
presenter switching tabs mid-recording for a retake.

## Symptoms
- Switching to the Mesh tab, enabling "Simulate 2G/SMS Uplink Detected" mid-flush, then
  switching to another tab and back: the buffer snaps back to the initial `4,820` and the
  switch reverts to unchecked — all visible flush progress is lost.
- Switching to the Vision tab, running Scenario C to get a result, then switching away and
  back: the component remounts and its `scanToken`-keyed effect fires again on mount, so the
  scan animation silently replays (brief skeleton flash) rather than the "done" result simply
  persisting as presumably intended.
- No console errors — the state loss is a silent UX regression, not a crash.

## Environment Details
- **Server/Host:** local dev (`bun run dev`, Vite, port 8080)
- **Services Affected:** `src/routes/index.tsx` (`Cockpit`), `src/components/orepulse/OreGradeScanner.tsx`,
  `src/components/orepulse/MeshHealth.tsx`
- **Related Components:** `@radix-ui/react-tabs`, `src/components/ui/tabs.tsx` (shadcn wrapper)
- **Time First Observed:** 2026-10-02, while driving the app headlessly (puppeteer-core against
  a local Chrome) to verify "record-readiness" for the MineTech Innovation Challenge demo video

## Investigation Steps

### 1. Initial Diagnosis
Drove the app with a headless-Chromium script to walk through Scenario A/B/C and manually
toggle the Mesh uplink switch, taking screenshots at each step to check for layout/overlap
issues ahead of recording a demo video. A first pass (clicking via `element.click()` inside
`page.evaluate`) showed several non-responsive buttons/tabs; re-testing with real Puppeteer
mouse-event clicks (`elementHandle.click()`) showed those were testing-script artifacts, not
app bugs — Radix's trigger activation and plain `<button onClick>` handlers both respond fine
to a real click event, just not reliably to a bare DOM `.click()` call dispatched this way.
Isolating that false trail left one reproducible, real issue: state loss across tab switches.

### 2. Root Cause Analysis
Inspected the installed Radix Tabs source directly to confirm panel mount behavior instead of
assuming it from the shadcn wrapper:

```bash
grep -n -A 25 "forceMount" node_modules/@radix-ui/react-tabs/dist/index.mjs
```

```js
return jsx(Presence, { present: forceMount || isSelected, children: ({ present }) => jsx(
  Primitive.div,
  {
    "data-state": isSelected ? "active" : "inactive",
    hidden: !present,
    children: present && children,   // <-- unmounted entirely when not present
    ...
  }
) });
```

Confirmed via an instrumented headless run that inspects `[role="tabpanel"]` nodes directly:

```
initial panels: [
  { hidden: false, dataState: 'active',   snippet: 'Shaft Cross-Section ...' },
  { hidden: true,  dataState: 'inactive', snippet: '' },   // empty — not just hidden, gone
  { hidden: true,  dataState: 'inactive', snippet: '' }
]
```

```
buffered before toggle: 4,820
buffered during flush (1.5s after toggle): 2,740
... switch to Vision, then back to Mesh ...
buffered after returning to mesh tab: 4,820 | switch state: unchecked
```

### 3. Key Findings
- `src/components/ui/tabs.tsx`'s `TabsContent` forwards all props straight to Radix's
  `TabsPrimitive.Content` with no `forceMount`, so the shadcn default applies: inactive panels
  are unmounted (`children: present && children`), not merely hidden.
- `OreGradeScanner` and `MeshHealth` both hold their demo-scenario progress in component-local
  `useState`, with no persistence in the shared `OrePulseProvider` context
  (`src/components/orepulse/store.tsx`). Local state cannot survive an unmount.
- The scripted recording flow in the Lovable prompt (visit geotech → vision → mesh once, in
  order) never triggers the bug, which is why it wasn't caught at build time — it only shows
  up on backtracking.

## Root Cause
Radix's `TabsContent` only keeps the currently-selected panel mounted unless `forceMount` is
passed; OrePulse's three demo panels rely on local component state for scenario progress but
were never given `forceMount`, so Radix's default unmount-on-deselect silently discarded that
state on every tab switch away and back.

## Prevention / Rule
**Guardrail:** Whenever a `<TabsContent>` wraps a component with its own local `useState`
(not lifted to shared context), require `forceMount` plus a `data-[state=inactive]:hidden`
class on that `TabsContent` — don't rely on the shadcn/Radix default. This is a one-line
per-tab convention, not a new abstraction, so it's cheap to apply as a code-review checklist
item for this component.

This closes the gap because it's the exact place the drift is invisible: the component looks
correct in isolation (its own state logic has no bug), and the bug only appears on a specific
interaction order (leave-and-return) that a straight-through manual click-test or the intended
demo script never exercises.

## Solution

### Immediate Fix
Added `forceMount` and `className="data-[state=inactive]:hidden"` to all three
`<TabsContent>` elements in `src/routes/index.tsx`:

```tsx
<TabsContent value="geotech" forceMount className="data-[state=inactive]:hidden">
  <GeotechMonitor />
</TabsContent>
<TabsContent value="vision" forceMount className="data-[state=inactive]:hidden">
  <OreGradeScanner />
</TabsContent>
<TabsContent value="mesh" forceMount className="data-[state=inactive]:hidden">
  <MeshHealth />
</TabsContent>
```

With `forceMount`, Radix keeps all three panels mounted and still sets
`data-state="active"|"inactive"` correctly; the Tailwind class hides inactive panels visually
(`display: none`) without unmounting them, so each tab's intervals and local state keep
running in the background exactly as they would on a real always-on telemetry feed.

Verified by re-running the same instrumented headless script after the fix:

```
buffered before toggle: 4,820
buffered during flush (1.5s after toggle): 2,740
... switch to Vision, then back to Mesh ...
buffered after returning to mesh tab: 1,440 | switch state: checked
```

Buffer continued draining in the background while on another tab, and the switch stayed
`checked` — state and the running interval both now survive tab switches. A follow-up full
screenshot pass (normal → Scenario B critical → switch to Vision while critical is still
active → Scenario C → Mesh tab) showed each panel rendering only its own content, no
cross-panel bleed-through, no layout overlap with the fixed Demo Controller panel, and no
console errors.

### Long-term Fix
No further action needed for this specific defect; the three tabs are the entire surface
area affected. If more tabs/panels are added with their own local state, apply the same
`forceMount` + hide convention from the start.

## Prevention
- [x] Applied `forceMount` + `data-[state=inactive]:hidden` to all three `TabsContent` panels
- [ ] No automated guardrail added (single small app, three call sites, checked by hand);
      revisit if the tab count grows enough to warrant a lint rule

## Related Issues
- None on file yet for this project (first OrePulse entry in this repo).

## References
- `src/routes/index.tsx`
- `src/components/orepulse/OreGradeScanner.tsx`
- `src/components/orepulse/MeshHealth.tsx`
- `src/components/ui/tabs.tsx`
- `@radix-ui/react-tabs` (`node_modules/@radix-ui/react-tabs/dist/index.mjs`, `forceMount` /
  `Presence` handling)

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~45 minutes

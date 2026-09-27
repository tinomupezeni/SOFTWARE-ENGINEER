# Vendored shadcn resizable wrapper kept v2/v3 data-attribute class names, dead under v4

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved (avoided, not patched in place)

## Summary
`src/components/ui/resizable.tsx` imports `Group`, `Panel` and `Separator`, so it had been
migrated to the `react-resizable-panels@4` export names — but its conditional styling still
keyed off `data-[panel-group-direction=vertical]`, which v4 never emits. v4 applies
orientation itself, by setting `flexDirection` inline from the `orientation` prop. Every one
of those variant prefixes is therefore an inert selector. Nothing had used the wrapper before
step 5, so the defect was latent rather than shipped; it was avoided by using the library
directly instead of relying on the wrapper.

## Symptoms
- No visible failure at the time of discovery — the wrapper was simply unused. That is what
  kept it from being noticed.
- Under v4, a `<ResizablePanelGroup>` with `orientation="vertical"` would keep the wrapper's
  base `flex` (row) and never become a column, so the intended vertical stack would lay out
  side by side.
- Its handle would keep `w-px` in that stack, i.e. a 1px-wide drag target — the exact
  "keyboard-driven cockpit with a mouse-only seam" problem the design review flagged.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite)
- **Services Affected:** `src/components/ui/resizable.tsx`
- **Related Components:** `react-resizable-panels@4.13.3`
- **Time First Observed:** 2026-09-26, while choosing a resizable-pane API for step 5

## Investigation Steps

### 1. Initial Diagnosis
Picked the resizable primitive for the spec/editor/telemetry split and read the vendored
shadcn wrapper before deciding whether to use it.

### 2. Root Cause Analysis
Compared the selectors the wrapper relies on against what the installed major actually emits.

```bash
# what the installed major exports
node -e "console.log(require('./node_modules/react-resizable-panels/package.json').version)"
# -> 4.13.3
node -e "console.log(Object.keys(require('.../dist/react-resizable-panels.js')))"
# -> Group, Panel, Separator, SeparatorOverlay, ...

# does v4 emit the data attributes the wrapper's class names key off?
grep -ro 'data-panel-group[a-z-]*' node_modules/react-resizable-panels/dist/ | sort -u
# -> (no output)

# how v4 actually applies orientation
grep -o 'flexDirection[^,;)]*' node_modules/react-resizable-panels/dist/*.js | sort -u
# -> flexDirection: l === "horizontal" ? "row" : "column"
```

### 3. Key Findings
- v4 exports `Group`/`Panel`/`Separator`, so the wrapper's *imports* were correct.
- v4 emits **no** `data-panel-group-*` attribute, and sets `flexDirection` inline instead.
- Six variant prefixes in the wrapper — `flex-col`, `h-px`, `w-full`, and three `after:`
  placements — are permanently dead under v4.
- The defect is partial-migration, not a version mismatch: it looks up to date in review
  because the import line is right.

## Root Cause
The wrapper was migrated to the v4 *export names* but not to the v4 *markup contract*. In
v2/v3 the group published its orientation as a `data-panel-group-direction` attribute, which
Tailwind could target with arbitrary variants; v4 removed that attribute in favour of inline
styles. Tailwind compiles `data-[panel-group-direction=vertical]:flex-col` to a real CSS rule
regardless of whether any element ever carries the attribute, so the rule is present in the
stylesheet and can never match. This is the same class of defect as
`ARCHCODE-2026-09-26-border-strong-token-never-mapped`: a stylesheet-level artefact that
exists, matches nothing, and produces no warning.

## Prevention / Rule
**Guardrail:** In `scripts/verify-semantics.ts`, assert that no `src/**` file references a
`data-[panel-group-*]` variant, and — for any vendored `components/ui/*` wrapper around a
third-party library — assert the selector contract the library actually emits.

Because Tailwind cannot know that a variant key is dead, an attribute-based selector for an
attribute the library no longer sets is unfixable by lint. The check has to compare the
selectors a wrapper uses against the attributes the installed version emits, which is the
only place the drift is observable.

## Solution

### Immediate Fix
Used `react-resizable-panels` directly via a new `src/components/arch/split.tsx`, which
passes `orientation` to the library and styles the handle from its own `orientation` prop
rather than from a data attribute. The vendored wrapper was left untouched rather than edited,
per the repo convention against modifying generated `components/ui` code.

Verified by drag: the spec pane stops at exactly 280px, and the vertical split drags and
resizes correctly.

### Long-term Fix
Either delete the unused wrapper, or repair it to v4 and cover it with the guardrail above.
It currently has zero call sites, so the cheapest correct action is deletion once confirmed
unused.

## Prevention
- [ ] Add the dead-`data-attribute`-variant guardrail to `verify-semantics.ts`
- [ ] Decide: delete the unused vendored wrapper, or repair it to the v4 contract
- [x] Step 5 avoids the wrapper entirely
- [ ] Audit the other vendored `components/ui/*` wrappers for the same partial-migration risk

## Related Issues
- `Frontend_and_UI/ARCHCODE-2026-09-26-border-strong-token-never-mapped.md`
- `reports/ARCHCODE-2026-09-26-step5-product-surface.md`

## References
- `src/components/ui/resizable.tsx`
- `src/components/arch/split.tsx`
- `react-resizable-panels@4.13.3` (inline `flexDirection`, no `data-panel-group-*`)

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~30 minutes

# Diagram Authoring Was Raw Hand-Typed JSON — Built a Visual Form for All 12 Kinds

**Date:** 2026-10-27
**Project:** HBEC
**Environment:** Admin frontend (development, pending deploy)
**Severity:** Medium (Admin UX)
**Status:** Resolved

## Summary
Reported by Mutsa in the HBCA ProjectFlow channel (2026-10-16): "I think we
need a simpler way to generate diagrams" / "its a bit difficult to,
specifically to format to a specific diagram." This was raised while testing
the "Graph diagrams on Maths papers (admin authoring + AI generation)" QA
task.

## Symptoms
- The admin's question diagram editor offered template buttons (one per
  diagram kind), but clicking one just dropped starter JSON into a plain
  `<Textarea>` — authoring a diagram meant hand-editing raw JSON (axis
  min/max/step, polynomial coefficients, point arrays, SMILES strings, music
  notation, etc.) with no form controls at all.

## Root Cause
Not a bug — a genuine missing feature. `DiagramEditor.tsx` was built purely
as a JSON text box with live validation/preview; no structured input UI was
ever built for any of the 12 diagram kinds defined in
`ADMIN/adminFrontend/src/features/exam-practice-admin/diagrams/spec.ts`
(manometer, pulley, roof truss, resistor circuit, music stave, right
triangle, Venn diagram, bar chart, number line, Cartesian graph, displayed
formula, plotting grid).

## Solution
Built a real visual form for every diagram kind:
1. Added shared field primitives (`components/diagram-forms/fields.tsx`):
   `TextField`, `NumberField`, `BoolField`, `ChoiceField`, `AxisFields`
   (min/max/step/label), and a generic `ListEditor` for add/remove/edit rows
   (curves, points, bars, resistors, symbols, etc.).
2. Added one form component per kind in `components/diagram-forms/`:
   `ManometerForm`, `PulleyForm`, `TrussForm`, `CircuitForm`,
   `MusicStaffForm`, `RightTriangleForm`, `VennForm`, `BarChartForm`,
   `NumberLineForm`, `CartesianGraphForm`, `DisplayedFormulaForm`,
   `PlotGridForm` — each mapping labeled inputs directly to/from that kind's
   typed spec, matching the exact constraints the validator already enforces
   (e.g. pulley strand-count ranges per arrangement, circuit resistor-count
   minimums, Venn region sets for 2 vs 3 sets, number-line open-ended
   intervals).
3. Rewrote `DiagramEditor.tsx` to default to the new "Form" mode (per-kind
   component + a shared alt-text field), while keeping an "Advanced (JSON)"
   toggle as an escape hatch for pasted specs or anything a form doesn't yet
   cover. Both modes share the same validate-as-you-type/preview/Save-gating
   behavior as before.
4. Exported `MIN_ALT`/`MAX_ALT` from `diagrams/spec.ts` (previously
   module-private) so the alt-text field's hint matches the validator
   exactly instead of a hardcoded guess.

Verified with `tsc --noEmit` (clean), `eslint` (clean after removing one
unused import), and the full `exam-practice-admin` vitest suite — all 82
tests passing, including the existing `DiagramEditor.test.tsx` (updated to
exercise the new Advanced-JSON toggle explicitly for its raw-spec case).

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (new form components + DiagramEditor rewrite)

## Follow-ups
- Not yet deployed to the admin frontend; pending the next admin release.
- The music-stave and displayed-formula (SMILES) forms are still fairly
  technical by nature of the underlying notation — worth a follow-up pass if
  admins other than Mutsa find those two specifically still hard to use.

---

**Resolved By:** Tinotenda Mupezeni (with Claude Code)
**Time to Resolution:** ~90 minutes

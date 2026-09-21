# Admin "Add Topic" Silently Fails When Display Order Goes Negative

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Development (found by user report; not yet confirmed on staging/prod)
**Severity:** Low-Medium (no bad data reaches the database, but the form fails with zero feedback, reading as broken)
**Status:** Resolved

## Summary
Admin reported "adding a topic... on order it's also giving negative, it's supposed to just give
positive numbers." `TopicForm.tsx`'s "Display Order" field is a plain
`<input type="number">` with no `min={0}`, so the browser's native spinner
(or manual typing) lets the value go negative. Both the zod schema
(`order: z.number().min(0)`) and the backend DRF field correctly reject a
negative value, so no bad data ever reached the database — but the form
never rendered `errors.order`, so a rejected submission just silently did
nothing. From the admin's side that looks exactly like "the order field is
broken."

## Symptoms
- In the "Add Topic" / "Edit Topic" dialog, typing or spinning the Display
  Order field to a negative number and clicking Create/Update does nothing —
  no error, no created topic, no visible explanation.

## Environment Details
- **Services Affected:** Admin Frontend (`ADMIN/adminFrontend`)
- **Related Components:** `src/features/curriculum/components/TopicForm.tsx`
- **Time First Observed:** 2026-09-21, reported by the user while adding a topic

## Investigation Steps

### 1. Initial Diagnosis
Traced "adding a topic on admin side... order... giving negative" to
`TopicForm.tsx`'s Display Order input, the only place `order` is entered on
topic creation. `TopicList.tsx`'s drag-reorder path and the ingestion
pipeline were ruled out — neither ever assigns an order value below 0
(`newRoots.map((n, idx) => ({ id, order: idx }))` always starts at 0; there
is no bulk-create path for topics anywhere in the backend).

### 2. Root Cause Analysis
Checked whether the negative value could actually reach the database:

```python
# apps/curriculum/serializers.py — confirmed empirically, not assumed
s = TopicWriteSerializer()
f = s.fields['order']
# IntegerField min_value=0 required=False default=<empty>
```

Confirmed the backend already rejects negative `order` (DRF auto-derives
`min_value=0` from the model's `PositiveIntegerField`). Confirmed the
frontend zod schema also rejects it (`z.number().min(0)`). Then found the
actual gap: `TopicForm.tsx` never renders `errors.order` — unlike `errors.name`,
which does — so a validation failure on this one field is completely silent.
Compared against `GradeForm.tsx`, which has the identical "order" field
pattern but **does** carry `min={0}` on its native input (line 168) — the
guard exists on one sibling form and was never propagated to the other.

### 3. Key Findings
- No bad data ever reached the database — this was a UX/feedback bug, not a
  data-integrity bug.
- Same shape as the `Record<Union, Config>` fallback issue already logged in
  this codebase's `CLAUDE.md`: a fix applied to one component (`GradeForm.tsx`)
  and never propagated to its sibling (`TopicForm.tsx`) doing the same thing.

## Root Cause
`TopicForm.tsx`'s Display Order `<Input type="number">` was missing
`min={0}`, letting the browser's native spinner/typing produce a negative
value. The zod schema and backend both correctly rejected it, but the
component never rendered the resulting `errors.order`, so the rejection was
invisible — the form just failed to submit with no explanation.

## Prevention / Rule
**Guardrail:** none added beyond the fix itself — this is a two-line gap, not
a class of bug worth a lint rule. The applicable existing guardrail is
already documented in `HBEC/CLAUDE.md`'s `Record<Union, Config>` entry:
**add the fallback/guard when you add the field, not after someone hits the
gap** — the same principle, just for form validation UX instead of a status
badge map.

## Solution

### Immediate Fix
`ADMIN/adminFrontend/src/features/curriculum/components/TopicForm.tsx`:
1. Added `min={0}` to the Display Order `<Input>`, matching `GradeForm.tsx`.
2. Added the missing `{errors.order && <p>...</p>}` block so a rejected
   value is now visible instead of silent.
3. Gave the zod validator's `.min(0)` an explicit message
   (`'Order must be 0 or greater'`) instead of the generic message a bare
   `z.union` produces.

`npm run typecheck` clean; confirmed the shared `Input` component forwards
`min` straight through to the native element (`{...props}` spread, no
prop-stripping).

### Long-term Fix
None needed beyond the above — this is the complete fix.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [x] Code changes required — done (see Solution)

## Related Issues
- Same pattern class as the `Record<Union, Config>` / `ProviderBadge`
  fallback issue already documented in `HBEC/CLAUDE.md` (Agentic Harness
  section) — a guard added to one component never propagated to its sibling.

## References
- `ADMIN/adminFrontend/src/features/curriculum/components/TopicForm.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/components/GradeForm.tsx`
  (the sibling that already had the `min={0}` guard)
- `ADMIN/adminBackend/apps/curriculum/serializers.py` (`TopicWriteSerializer`
  — confirmed already correctly enforces `min_value=0`)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session, found and fixed within the hour

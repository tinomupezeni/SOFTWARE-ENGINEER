# "Add part" silently produces a blank-labelled part after a sub-part is added to the last part

**Date:** 2026-11-03
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
An admin (Mutsa) reported on 2026-10-29: "after adding sub parts I cannot add other parts like part d." Root cause: `nextLabel()` in the admin's question-parts editor (`ADMIN/adminFrontend/src/features/exam-practice-admin/utils/parts.ts`) computed the next top-level part letter by reading the literal last element of the flat `parts` array — which works until a sub-part (e.g. "c(i)") gets appended to the *last* top-level part, after which the array's last element is a compound sub-part label, not a bare letter, and the function silently returned `''` instead of the next letter.

## Symptoms
- Admin adds parts (a), (b), (c) to a question, then adds a sub-part to (c), producing (c)(i).
- Clicking "Add part" afterward produces a new part with no label at all (the button itself degraded from showing "Add part (d)" to "Add part (next)"), rather than adding "(d)" as expected.
- Not reproducible when a sub-part is added to an *earlier* part (e.g. adding a sub-part to (a) when (b) and (c) already exist after it) — only when the sub-parted part is the last one in the list, which is why it read as an inconsistent/confusing bug rather than an always-reproducible one.

## Environment Details
- **Server/Host:** HBEC ADMIN frontend
- **Services Affected:** `ADMIN/adminFrontend` (`exam-practice-admin` feature)
- **Related Components:** `utils/parts.ts` (`nextLabel`), `components/PartsEditor.tsx` (`addPart`, "Add part" button)
- **Time First Observed:** 2026-10-29

## Investigation Steps

### 1. Initial Diagnosis
Traced "Add part" (`PartsEditor.tsx` → `addPart` → `nextLabel(parts)`) and "Add sub-part" (`addSubPart` → `nextSubLabel`, inserting the new sub-part into the flat `parts` array right after its parent's existing sub-parts — not as a separate nested structure).

### 2. Root Cause Analysis
```ts
export function nextLabel(parts: SubQuestion[]): string {
  if (!parts.length) return 'a';
  const last = parts[parts.length - 1].label.toLowerCase();
  const at = PART_LETTERS.indexOf(last);
  return last.length === 1 && at >= 0 && at < PART_LETTERS.length - 1 ? PART_LETTERS[at + 1] : '';
}
```
For `parts = [a, b, c, c(i)]` (a sub-part added to the last top-level part "c"), `parts[parts.length - 1]` is `c(i)`, whose label has `length !== 1`, so the function falls through to `return ''`.

### 3. Key Findings
- `addPart` appends `{ label: nextLabel(parts), ... }` unconditionally — a blank `nextLabel` result produces a genuinely unlabeled part, not a disabled button or an error, so the failure mode was a silently broken part rather than a visible block.
- The bug is positional, not structural: it only triggers when the most recently sub-parted top-level part happens to be the *last* one in the array, which is common (admins tend to work left-to-right) but not guaranteed — explaining why it read as intermittent.

## Root Cause
`nextLabel` assumed the array's last element is always a plain top-level label, but `addSubPart`'s insertion point can place a compound sub-part label at the very end of the flat array.

## Prevention / Rule
**Guardrail:** Any function deriving "the next X" from a flat list that can contain two different kinds of entries (here: top-level parts and their nested sub-parts, stored in one flat array) must filter to the relevant kind first, never assume the list's last element is representative. Covered going forward by `utils/__tests__/parts.test.ts`, which specifically exercises a sub-part sitting at the end of the array.

## Solution

### Immediate Fix
N/A — no incident, just a broken control.

### Long-term Fix
`nextLabel` now filters to only the top-level (bare single-letter) entries before finding the last one, so a sub-part anywhere in the array — including at the very end — no longer affects top-level letter computation.

```ts
export function nextLabel(parts: SubQuestion[]): string {
  if (!parts.length) return 'a';
  const topLevel = parts.filter(
    (part) => part.label.length === 1 && PART_LETTERS.includes(part.label.toLowerCase()),
  );
  if (!topLevel.length) return '';
  const last = topLevel[topLevel.length - 1].label.toLowerCase();
  const at = PART_LETTERS.indexOf(last);
  return at < PART_LETTERS.length - 1 ? PART_LETTERS[at + 1] : '';
}
```
Added `utils/__tests__/parts.test.ts` (6 tests): empty list, normal continuation, sub-part at the end of the array (the reported bug), sub-part in the middle, no top-level letters at all, and the "z" ceiling. Full `exam-practice-admin` vitest suite (93 tests) and `tsc --noEmit` both clean.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `HBEC-2026-11-03-question-parts-exploded-into-sibling-rows.md` — same admin feedback thread, a separate backend bug in the same general "parts/sub-parts" feature.

## References
- `ADMIN/adminFrontend/src/features/exam-practice-admin/utils/parts.ts`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PartsEditor.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/utils/__tests__/parts.test.ts`

---

**Resolved By:** Claude (session with Tinotenda Mupezeni)
**Time to Resolution:** Same session as investigation

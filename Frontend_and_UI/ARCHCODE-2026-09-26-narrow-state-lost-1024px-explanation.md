# Step-5 refactor silently dropped the narrow state's 1024px explanation, and a rename broke its guardrails

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Rewriting `src/routes/index.tsx` for step 5 replaced the `NarrowNotice` component with a
`CompactWorkspace` that offers Brief / Editor / Telemetry tabs instead of a read-only notice.
The redesign is an improvement — it gives narrow users the editor and telemetry rather than
only prose. But it silently dropped a guarantee finding 6 had logged as fixed: the state no
longer told the user *why* it was reduced. The copy that stated the 1024px requirement
disappeared entirely. The guardrail for it did not fire, because the component was renamed in
the same edit and the check was coupled to the old name — so the guard went stale and the
regression passed.

## Symptoms
- Below 1024px the app shows a compact workspace with no explanation of the constraint.
- A user at 900px cannot distinguish "the app is broken" from "my window is too small".
- The guardrail `the narrow state states the 1024px requirement` was passing against a
  component name (`NarrowNotice`) that no longer existed in the file.
- `BRIEF_BODY` appeared to be rendered by only one surface, contradicting the comment
  claiming two — which looked like a second regression but was not.

## Environment Details
- **Server/Host:** local dev (`npx tsx scripts/verify-semantics.ts`)
- **Services Affected:** `src/routes/index.tsx`, `scripts/verify-semantics.ts`
- **Related Components:** `CompactWorkspace`, `SpecPane`, finding 6's container-query gate
- **Time First Observed:** 2026-09-26, after switching to `bun run verify`

## Investigation Steps

### 1. Initial Diagnosis
`bun run verify` reported three failures about the narrow-window state, from a suite that had
been green minutes earlier. The first `FAIL` names were the only clue; the `ReferenceError`
that followed hid the detail.

### 2. Root Cause Analysis
```bash
grep -c 'NarrowNotice' src/routes/index.tsx          # 0  -- renamed
grep -n 'function CompactWorkspace' src/routes/index.tsx   # the new name
grep -n '1024' src/routes/index.tsx | grep -v 'min-\[1024px\]'   # empty -- the copy is gone
grep -n 'BRIEF_BODY' src/routes/index.tsx            # declared once, referenced once
```

### 3. Key Findings
- **The 1024px explanation was genuinely gone.** This is a real content regression, and the
  reason it matters: finding 6's fix was specifically "a deliberate state, not a clipped
  cockpit", and a deliberate state that does not announce its condition is indistinguishable
  from a broken one.
- **The brief was not actually lost.** `CompactWorkspace` renders `<SpecPane>` for its Brief
  tab, and `SpecPane` renders `BRIEF_BODY`. One declaration, two surfaces — the hoisting
  worked exactly as intended, and only the *grep* made it look broken. The old guard matched
  `{BRIEF_BODY}` literally inside `NarrowNotice`, so it could not follow the indirection.
- **Both failures were reported from the same rename.** Nothing about the rename was
  behaviour-preserving: a guardrail that asserts a component *name* cannot survive it.

## Root Cause
Two distinct problems compounded. The product regression was a redesign that dropped copy
without anyone checking whether the copy was load-bearing. The verification weakness was that
the guardrails were coupled to identifiers — a component name and a literal JSX shape — rather
than to behaviour, so a legitimate refactor invalidated the checks that were supposed to
protect the behaviour. A check that breaks on rename produces a false alarm, and a check that
is easy to "fix" by deleting is not protecting anything.

## Prevention / Rule
**Guardrail:** The narrow-state guardrails must assert the *user-visible contract* and be
rename-proof: (a) a stated minimum width exists, (b) the number in that copy equals the number
in the container-query gate — compared programmatically, since a Tailwind arbitrary value
cannot be interpolated and the two can only be kept in agreement by an assertion, and (c) the
narrow state renders the brief, matched by the `pane === "Brief" && <SpecPane` reuse rather
than by `{BRIEF_BODY}` appearing inside a named function.

Coupling a guardrail to a symbol name makes it fail on harmless refactors, which trains people
to delete the guardrail. The contract is "a reduced state states its requirement", and that
has to be expressible without naming the component that implements it.

## Solution

### Immediate Fix
- Restored the explanation, sourced from a single `MIN_COCKPIT_PX` constant:
  `Compact workspace. The full cockpit needs at least {MIN_COCKPIT_PX}px wide; each pane is below.`
- Rewrote the three guardrails to be rename-proof and to compare the stated width against the
  `@min-[1024px]:` gate numerically, so the copy and the layout cannot drift apart.
- Changed the brief assertion to match the `SpecPane` reuse, which is what actually makes the
  brief appear in both surfaces.

### Long-term Fix
The same rename-coupling risk applies to the other name-based checks; audit them for symbols
that a refactor could change.

## Prevention
- [x] 1024px explanation restored, sourced from one constant
- [x] Copy-vs-gate agreement asserted numerically
- [x] Brief assertion follows the reuse rather than a literal
- [x] All three now mutation-tested (3 of the 25 cases)
- [ ] Audit remaining guardrails for rename-coupled symbol references

## Related Issues
- `Frontend_and_UI/ARCHCODE-2026-09-26-cockpit-clipped-below-1024px.md` (the original finding)
- `Frontend_and_UI/ARCHCODE-2026-09-26-guardrails-that-could-not-fail.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-honesty-reporter-crashed-on-first-failure.md`

## References
- `src/routes/index.tsx` (`MIN_COCKPIT_PX`, `CompactWorkspace`, `SpecPane`)
- `scripts/verify-semantics.ts` (narrow-state guardrail block)

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~40 minutes

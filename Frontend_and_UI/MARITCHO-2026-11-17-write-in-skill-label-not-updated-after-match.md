# Write-in skill keeps raw typed text as its label even after matching a real skill

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Low
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
`composeSkillWithWriteIn` (`frontend/src/core/format/trades.ts:392-418`) resolves a write-in skill
string through `predictSkills`, and when a match is found it correctly copies the matched skill's `id`
and `trade`, but hard-codes `label: trimmed` (the raw typed text) regardless of whether a match was
found. A short prefix like "pl" resolves via `predictSkills` to the real "Plumber" skill
(`id: "plumber"`, `trade: "PLUMBING"`), but the returned object's `label` stays `"pl"` — so the UI
shows "Done — pl" instead of "Done — Plumber," and if persisted as-is, the saved skill selection
displays the wrong label everywhere it's rendered.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- Typing a short, unambiguous prefix (e.g. "pl") into the skill write-in box resolves the correct
  skill internally (`id`/`trade` are right) but displays the raw typed text as the label in
  `TradePickerSheet`'s "Done — <label>" footer button.

## Environment Details
- **Server/Host:** N/A (Next.js frontend)
- **Services Affected:** Job posting skill picker (`TradePickerSheet`, `PostJobScreen`)
- **Related Components:** `trades.ts` (`composeSkillWithWriteIn`, `predictSkills`)
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding claimed the write-in resolution path updates `id`/`trade` from a matched skill but
never updates `label` to match, leaving the UI showing the raw typed text even when a real skill was
identified.

### 2. Root Cause Analysis
- Exact code (lines 416-418):
  ```ts
  const matched = predictSkills(trimmed)[0];
  return {
    id: matched?.id ?? "custom",
    label: trimmed,
    trade: matched?.trade ?? "BUILDING",
  };
  ```
  `label` is unconditionally set to `trimmed`, never reassigned to `matched.label`.
- `composeSkillWithWriteIn(null, "pl")` → `matched = predictSkills("pl")[0]` resolves via `byPrefix`
  (since `"plumber".startsWith("pl")`) to `{ id: "plumber", label: "Plumber", trade: "PLUMBING" }`, but
  the function still returns `{ id: "plumber", label: "pl", trade: "PLUMBING" }`.
- `TradePickerSheet.tsx`'s footer button reads `` {resolved ? `Done — ${resolved.label}` : "Pick a skill"} ``,
  so this renders "Done — pl." In `PostJobScreen.tsx`'s specific wiring, `onWriteInChange` is passed
  and `handleDone` re-derives the base skill via `findSkill(resolved.id)`, recombining into
  "Plumber — pl" on that particular path — but the sheet's own visible button text, and any caller
  using `onSelect(resolved)` directly without `onWriteInChange`, get the raw-text-label object as-is.
- No existing test in `TradePickerSheet.test.tsx` covers this short-prefix/no-base-skill case — only
  exact-label and "write-in on top of an existing pick" cases are tested.

### 3. Key Findings
- The bug is purely in `label`; `id`/`trade` resolution is correct, so any downstream logic keyed on
  `id`/`trade` (e.g. worker routing) is unaffected — this is a display/labeling bug, not a
  matching/routing bug (see the separate, related entry on the `trade` default).

## Root Cause
`composeSkillWithWriteIn` was written to preserve the user's typed text as the label by default (a
reasonable choice for a true custom/unmatched skill), but the same unconditional assignment was never
special-cased for the matched branch, where the matched skill's own display label should take
precedence.

## Prevention / Rule
**Guardrail:** Add a unit test asserting `composeSkillWithWriteIn(null, "pl").label === "Plumber"` (or
whatever the matched skill's label is) whenever `predictSkills` returns a non-empty result, alongside
the existing "no match → label stays as typed text" case — covering both branches of the `matched ?`
conditional that the current tests only cover for `id`/`trade`.

This closes the Root Cause gap directly: the existing tests already distinguish matched vs. unmatched
cases for `id`/`trade`; extending the same matched-case assertion to `label` would have caught this
immediately.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed (low-severity) display bug found during review of
PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Change line 417 to `label: matched?.label ?? trimmed`, mirroring the `id`/`trade` pattern already
  used on the surrounding lines.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [ ] Documentation to update — none
- [x] Code changes required — fix `label` assignment in `composeSkillWithWriteIn` (not yet implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced this function.
- Related: `Frontend_and_UI/MARITCHO-2026-11-17-write-in-skill-defaults-to-building-trade.md` — same
  function, a different bug in the unmatched branch's `trade` field.

## References
- `frontend/src/core/format/trades.ts:392-418` (`composeSkillWithWriteIn`)
- `frontend/src/features/jobs/TradePickerSheet.tsx` (footer button rendering)
- `frontend/src/features/jobs/TradePickerSheet.test.tsx`
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)

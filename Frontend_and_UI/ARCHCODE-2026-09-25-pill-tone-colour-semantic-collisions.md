# Red signalled both "hard invariant" and "failed verdict" on one screen

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

The `Pill` component has a `tone` prop with red, green, amber and blue variants. Red was
used both for invariants classified "hard" — a static property of the problem statement,
rendered identically whether the run passed or failed — and for a failed verdict. A learner
looking at a fully passing run saw four red badges, immediately above a green "ACCEPTED"
verdict. Amber carried three unrelated meanings at once: "Medium" difficulty, "soft"
invariant, and the Run action.

## Symptoms

- A passing run displayed four red "hard" badges while the verdict read "ACCEPTED" in green.
- A failing run displayed the same four red badges in the same positions, so the invariant
  list conveyed no information about the outcome.
- The Run button was amber; a "soft" invariant chip and the "Medium" difficulty chip were
  also amber. Nothing tied them together.
- One dead tone, `zinc`, was defined and never used.

## Environment Details

- **Server/Host:** Local development
- **Services Affected:** Invariant list, difficulty display, verdict display, Run action
- **Related Components:** `Pill` in `src/routes/index.tsx`; call sites at the invariant list
  and the verdict
- **Time First Observed:** 2026-09-25, during the HIG design review

## Investigation Steps

### 1. Initial Diagnosis

Enumerated every `Pill tone=` call site and mapped each tone to the meaning it was carrying.

### 2. Root Cause Analysis

```bash
grep -n "Pill tone=" src/routes/index.tsx
```

Four semantic axes — problem difficulty, invariant severity, run verdict, and affordance —
were all funnelled through one five-value colour prop. The prop's type made every collision
type-correct.

### 3. Key Findings

| Tone | Meaning 1 | Meaning 2 | Meaning 3 |
| --- | --- | --- | --- |
| red | "hard" invariant | failed verdict | — |
| amber | "soft" invariant | "Medium" difficulty | Run action |
| green | accepted verdict | — | — |

- The red collision is the damaging one. `kind === "hard" ? "red" : "amber"` is evaluated
  from static problem data, so its output is invariant across both states — the component
  was structurally incapable of reflecting the run's outcome.
- The amber collision matters less only because "Medium" and the Run button are rarely on
  screen at the same moment.

## Root Cause

A colour prop with no ownership model. Nothing tied a tone to a single meaning, so tones
accumulated meanings as call sites were added, and the type system had no way to object. The
deeper issue is that difficulty and severity are different *kinds* of thing — one describes
the problem, one describes the run — and both were expressed in the same vocabulary.

## Prevention / Rule

**Guardrail:** Reserve the verdict palette — red and green — exclusively for pass/fail state,
and never encode a static property of the input in a colour that also encodes the outcome.

This closes the gap because the defect is a category error rather than a wrong value: no
choice of `tone` string could have been both correct and distinct, since two unrelated axes
were sharing five slots. Declaring red and green as verdict-exclusive makes a second
meaning impossible to express, so the compiler rejects it rather than the reviewer's eye.

## Solution

### Immediate Fix

- Hard/soft invariant now renders as `tone="outline"` (solid `--border-strong` border,
  foreground text) versus `tone="zinc"` (muted). The distinction is preserved but carried by
  weight and border, not hue.
- Red and green are now used only by the verdict pill.
- The unused `zinc` tone is now in use, and the new `outline` tone replaces it as the
  neutral-strong option.

### Long-term Fix

- Difficulty was left as a text badge rather than given a colour, per the review's
  recommendation. Difficulty is a property of the problem and should read as part of the
  problem statement.
- Consider splitting `Pill` into a verdict badge and a metadata chip so the two vocabularies
  are separate types rather than one union.

## Prevention

- [x] Verdict palette reserved for pass/fail
- [x] Invariant severity encoded typographically
- [ ] Split `Pill` so verdict and metadata cannot share a tone type

## Related Issues

- `ARCHCODE-2026-09-25-design-tokens-nontext-contrast-unmeasured.md` — same token system,
          same session
- Design review Critical 3

## References

- `ARCHCODE-DESIGN-REVIEW.md` — Critical 3
- `src/routes/index.tsx` — `Pill` and its call sites
- Apple HIG, *Color* — consistent use of color for status

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~20 minutes

# Step-5 product-surface guardrails could not fail: `|| true`, a `? :` else-branch, and assertions satisfied by comments

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The step-5 checks added to `scripts/verify-semantics.ts` were written so that they could not
fail. One assertion ended in `|| true`; one used a ternary whose false branch was the passing
state; the 280px pane-floor assertion matched a regex against raw source and was satisfied by
the explanatory comment I had just written *describing* the floor; and the Plan/Trace tab
assertion tested for the string `"Trace"` anywhere in the file, which was true because
`tab === "Trace" && <TraceView />` and the shortcut table mention it — not because the tab
existed. Separately, nothing asserted `role="radio"` on the options, so swapping them for
`role="option"` (turning the radiogroup into a listbox) passed. The suite reported green the
entire time the features it was supposed to protect were being removed.

## Symptoms
- Removing a scenario from the picker's data flow left the suite green.
- Removing the stub-gateway flag from the PRD's scenario 3 left the suite green.
- Deleting the `"Trace"` entry from `TELEMETRY_TABS` left the suite green.
- Changing every option's `role="radio"` to `role="option"` left the suite green.
- Removing the `minSize={280}` floor left the suite green.
- The suite printed `all assertions passed` throughout — including while it was failing to
  check anything.

## Environment Details
- **Server/Host:** local dev (`npx tsx scripts/verify-semantics.ts`)
- **Services Affected:** `scripts/verify-semantics.ts` (step-5 product-surface block)
- **Related Components:** `scenario-picker.tsx`, `problem.ts`, `index.tsx`, `split.tsx`
- **Time First Observed:** 2026-09-26, by mutation testing the suite just written

## Investigation Steps

### 1. Initial Diagnosis
The suite went green as soon as the step-5 features existed and never went red afterwards. A
check that has never failed is not known to work. Wrote a mutation harness: back up the
sources, break one thing at a time, assert the suite goes red, restore.

### 2. Root Cause Analysis
```bash
# 19 mutations, each must turn the suite red
/tmp/opencode/negtest.sh
# first run: 15 caught, 4 escaped
```

Triaging the four escapes showed three different causes:

```bash
# 1. a "Trace" deletion is invisible to a whole-file string test
sed -i '/^  "Trace",$/d' src/routes/index.tsx && npx tsx scripts/verify-semantics.ts  # still green

# 2. role="option" over role="radiogroup" is a listbox, and nothing looked
sed -i 's/role="radio"/role="option"/' src/components/arch/scenario-picker.tsx  # still green
```

Two of the four "escapes" were my own harness's fault and not the suite's: one mutation
`sed -i 's/"Trace",//'` never matched (no trailing comma on the last array element) and one
`sed -i 's/collapsible$//'` never matched (the token is mid-line, not at end of line) — both
were no-op mutations that trivially "passed". The fourth was caught, by a different rule than
the probe's expected message, i.e. a false negative in the harness.

### 3. Key Findings
- **Literal `|| true`:** the assertion's boolean was `test(x) || true`, which is always true.
- **Inverted ternary:** a check of the shape `cond ? mustBeTrue : true` passes whenever
  `cond` is false — the *else* branch encoded the passing state.
- **Comment-satisfiable regex:** `/minSize={280}/` tested raw source, and my own comment
  contained the literal text `minSize={280}` while explaining it. The assertion was satisfied
  by the documentation of the feature rather than the feature.
- **Whole-file string test:** `/"Trace"/.test(routeSrc)` passed on any mention of the word,
  including the render guard and the shortcut table.
- **Unasserted semantics:** `role="radio"` was never checked at all. The radiogroup check
  alone is satisfiable by a listbox.
- **Unasserted membership:** nothing verified `"Trace"` was an entry of `TELEMETRY_TABS`, or
  that the array had six entries.

## Root Cause
The guardrails were written as *descriptions* of the intended implementation rather than as
*falsifiable claims* about it, and then never tested against a deliberate break. Three
distinct failure modes share one root cause — the assertions were never shown to be capable
of failing:

1. **Never executed as a boolean.** `|| true` and a `? :` with a passing `else` make the
   check structurally incapable of returning the failure state. These pass review because the
   surrounding text reads like a real check.
2. **Not scoped to code.** Regexes were run against raw file text, so anything in the file —
   including prose about the invariant — satisfies them. Comments are not code but they match.
3. **Not falsifiable.** A guardrail is only known to work if it has been observed to fail.
   Nothing in the normal loop produces a red suite when these checks are wrong, because
   removing a feature removes the code the check was written against and the check is either
   absent, short-circuited, or satisfied by the text that remains.

## Prevention / Rule
**Guardrail:** Every assertion in `scripts/verify-semantics.ts` must be mutation-tested before
it is trusted: for each check, break the specific thing it claims to protect and require the
suite to go red. Additionally, mechanically reject the two unfalsifiable shapes — fail on a
literal `|| true` in an assertion, and fail on a ternary whose branches are not both boolean
checks — and run all source-inspection assertions against a comment-stripped copy of the file
via a shared `stripComments` helper, so only code can satisfy them.

Assertions over source text are only trustworthy if (a) they cannot be satisfied by prose and
(b) they have been observed to fail. (a) is mechanical and cheap: strip comments first, and
forbid the short-circuit shapes. (b) is the part this repo was missing — a mutation harness
(`/tmp/opencode/negtest.sh`) is the only thing that distinguishes a real guardrail from a
decorative one, so it is part of the definition of done for a new check, not an optional
extra. Membership checks must parse the actual declaration (e.g. extract the
`TELEMETRY_TABS` array and assert on its entries) rather than grepping for a token.

## Solution

### Immediate Fix
- Replaced the `|| true` and the inverted ternary with real checks: the picker must map
  `SCENARIOS`, exactly the PRD's scenario 3 requires the stub gateway, and every scenario must
  declare the flag.
- Added a shared `stripComments` helper and routed every source-inspection assertion through
  the stripped text, so a comment can no longer satisfy a code check.
- Added the two missing semantics: `role="radio"` **and** `aria-checked` on each option, and
  membership in the parsed `TELEMETRY_TABS` array (plus `length === 6`).
- Required a non-empty literal `aria-label` at both call sites of the split handle.

### Long-term Fix
Promote the mutation harness into the repo (e.g. `scripts/verify-guardrails.ts`) so the
"every check can fail" property is enforced on every run, rather than living in `/tmp` and
being re-run by hand.

### Result
```
19 caught, 0 escaped
```

## Prevention
- [x] Vacuous assertions replaced with falsifiable ones
- [x] `|| true` and inverted-ternary shapes removed
- [x] All source assertions run against comment-stripped source
- [x] `role="radio"` + `aria-checked` asserted
- [x] `TELEMETRY_TABS` membership and count asserted, parsed from the declaration
- [x] Handle labels asserted non-empty at the call sites
- [x] 19/19 mutations caught
- [ ] Move the mutation harness into `scripts/` and run it as part of verification
- [ ] Add mechanical rejection of `|| true` / inverted ternaries in assertions

## Related Issues
- `Frontend_and_UI/ARCHCODE-2026-09-26-modal-dialog-without-focus-trap.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-border-strong-token-never-mapped.md`
- `reports/ARCHCODE-2026-09-26-step5-product-surface.md`

## References
- `scripts/verify-semantics.ts`
- `/tmp/opencode/negtest.sh` (mutation harness, 19 cases)
- ESLint `no-constant-condition` does not catch `x || true`; a custom rule or a grep for the
  shape is required

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~2 hours (most of it spent establishing that the checks could fail at all)

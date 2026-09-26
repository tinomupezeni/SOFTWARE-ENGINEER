# Cockpit displayed fabricated verdicts, a score, and an editability it did not have

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The cockpit's most prominent surfaces asserted things no run had produced. A
"Toggle Pass / Fail State" button let a user flip between two invented verdicts
("Status: ACCEPTED" / "Status: ARCHITECTURAL COLLAPSE"), the top bar printed a Resilience
score of 1874/1840 for work that had never been submitted, the invariants checklist drew a
green check on exactly one of three "must hold" items for no stated reason, and the editor
status bar labelled a static `<table>` of pre-baked constants as "editable" while a 9px `RO`
badge marked the files that were supposedly writable. Nothing had been executed. A score is
the product's payoff for Submit, so showing one beforehand misrepresents the learner's
standing — and the review had already flagged the `RO`/editable pair as an overclaim.

## Symptoms
- "Toggle Pass / Fail State" button swapped the entire cockpit between pass and fail fixtures.
- Top bar: `Resilience 1874` / `1840` with a "Top 4%" ranking.
- Telemetry banner: `Status: ACCEPTED — Invariants validated…` or `Status: ARCHITECTURAL
  COLLAPSE — Race condition & pool starvation detected`.
- Invariants checklist marked 1 of 3 "Hard Invariants (Must Hold)" as passing via
  `passed || i === 1`, with no basis for item 1 specifically.
- Editor status bar printed "editable" for `solution.py`; the file data set `ro: false` while
  the pane rendered a read-only table.
- `RO` badge rendered at `text-[9px]`, below the 10px legibility minimum.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite)
- **Services Affected:** `src/routes/index.tsx`, `src/components/arch/collision-timeline.tsx`
- **Related Components:** `TopBar`, `SpecPane`, `TelemetryPane`, `EditorPane`, `CollisionTimeline`
- **Time First Observed:** 2026-09-25, HIG design review findings (scaffolding removal, step 4)

## Investigation Steps

### 1. Initial Diagnosis
Traced every consumer of the `passed` boolean to establish how far the fabricated state spread.

```bash
grep -n "passed" src/routes/index.tsx
# 13 sites: top-bar score, invariants checklist, telemetry banner, log tones,
# invariant matrix, metrics-vs-root-cause branch, DB diff, timeline prop, page state
```

### 2. Root Cause Analysis
The scaffold was built to make a screenshot look right. Pass/fail fixtures were the cheapest
way to populate every verdict surface at once, and a toggle was the cheapest way to make both
branches reachable for review. Nothing in the type system, lint, or DOM inspection objects to
a hardcoded score string — the fabrication was syntactically identical to real data.

```bash
grep -rn "1874\|1840\|>editable<\|Toggle Pass" src/routes src/components
# 1874 / 1840 / the toggle / the editable claim
```

### 3. Key Findings
- The `passed || i === 1` expression was the clearest tell: a decorative "mostly fine" detail
  with no referent. It was also the only green check in a list of things the seeded incident
  violates.
- `VERDICT_SURFACE[passed ? "pass" : "fail"]` meant the banner's *colour* was driven by the
  same fiction, so the semantic colour contract from step 2 was being fed a fabricated
  verdict.
- The `ro` flag had the inverse problem: `solution.py` was marked `ro: false`, so the pane
  actively claimed the learner's own code file was writable.
- The review's step 4 also called for removing a dead `zinc` pill tone. That was already gone
  — it was removed as a side effect of step 2's semantic-role rewrite, not as separate work.
  Verified rather than assumed.

## Root Cause
Mock data was promoted to displayed truth. The scaffold had no notion of "this has not run
yet", so every state variable doubled as a verdict, and no check distinguished a real result
from a fixture.

## Prevention / Rule
**Guardrail:** `scripts/verify-semantics.ts` now enforces an honesty contract over
`src/routes` and `src/components/arch`, failing the build on a hardcoded verdict status, a
hardcoded score, a `passed` boolean threaded into the UI, an `>editable<` claim, a
pass/fail toggle, or any `text-[0-9px]`.

This closes the gap because the failure mode is *prose and literals in JSX* — a fabricated
verdict is indistinguishable from a real one to the type system, to lint, and to the DOM, so
only a check that reads the string literals can catch it. The rule is deliberately blunt
string matching rather than a type: there is no type that distinguishes "1874" the fixture
from "1874" the result.

## Solution

### Immediate Fix
- Deleted the toggle button, the `passed` state, and its 13 prop-threading sites.
- Deleted the `PASS_ROWS` / `PASS_LOGS` fake-pass fixtures; renamed `FAIL_*` → `SEEDED_*` so
  the naming stops implying a verdict about the learner.
- Top bar: `Resilience —` / "Not scored". A score is granted by Submit; nothing was submitted.
- Banner: relabelled "Reference incident — the seeded failure you are asked to diagnose. No
  run yet, so there is no verdict", on a neutral surface instead of a pass/fail surface.
- Invariants checklist: removed the `passed || i === 1` fake partial pass.
- Root-cause analysis kept; the fake-pass "Runtime 34ms / Lock Contention / Memory" metrics
  branch removed.
- DB diff: kept the seeded incident's diff, removed the fake-clean branch.
- `CollisionTimeline`: dropped the `passed` prop; renders the seeded incident only.
- Editor: removed the per-file `ro` flag and the 9px `RO` badge; status bar now reads
  "read-only" unconditionally.

```bash
npm run verify     # 88 assertions, then tsc --noEmit
npx eslint src/routes/index.tsx src/components/arch/ src/lib/ scripts/
npx vite build
```

### Long-term Fix
- Step 5 (`schema.sql` / `solution.py` genuinely editable, scenario selector, Plan/Trace,
  pane resizing) restores the per-file `ro` flag with something behind it.
- A real runner makes `PASS_ATTEMPTS` live again — it is currently exercised only by
  `verify-timeline.ts`, which needs it to prove the detector reports zero windows when there
  is no collision. That is a real invariant of the model, so it was kept rather than deleted
  as dead code.

## Prevention
- [x] Pass/fail toggle and `passed` state removed
- [x] Hardcoded score removed
- [x] Verdict banner reframed as a reference incident on a neutral surface
- [x] Fake partial-pass removed from the invariants checklist
- [x] `RO`/editable overclaim removed; status bar honest
- [x] 9px `RO` badge removed; 10px minimum now enforced
- [x] Honesty contract added to `scripts/verify-semantics.ts`, wired into `npm run verify`
- [x] Every new rule negative-tested (score, `editable`, 9px, verdict status all fail when
      injected)
- [ ] `npm run verify` in CI

## Related Issues
- `ARCHCODE-2026-09-25-pill-tone-colour-semantic-collisions.md` and
  `ARCHCODE-2026-09-25-colour-roles-not-hues.md` — the colour contract this fabricated state
  was feeding.
- `reports/ARCHCODE-2026-09-26-scaffolding-removal.md` — implementation report.
- `ARCHCODE-DESIGN-REVIEW.md` — sequencing step 4, and the corrected note that these bindings
  and states were never PRD requirements.

## References
- `ARCHCODE-PRD.md` §5.2 — a Resilience Score is granted by Submit, and Run never touches it
- `typography.md › Ensuring legibility` — 10px minimum, per the review's note on the 9px badge
- WCAG 2.1 SC 3.3.1 Error Identification / SC 1.3.1 — state must reflect real system state

---

**Resolved By:** Claude (Anthropic)
**Time to Resolution:** ~1 session

# Removing the cockpit's fabricated state (HIG review, step 4)

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Type:** Cleanup / Scope Decision
**Status:** Completed

## Summary
Executed step 4 of the HIG review: removed the mock scaffolding that let the cockpit assert a
verdict, a score, and an editability no run had produced. The design decision underneath was
how to keep a useful cockpit after deleting the fake state — the answer being to reframe the
remaining fixture as the *seeded incident* the learner is asked to diagnose, which is real
reference data rather than a fabricated result, and to make "not run yet" an explicit,
visible state instead of an implied one.

## Context / Trigger
Step 4 of `ARCHCODE-DESIGN-REVIEW.md`: "**Remove the scaffolding**: the pass/fail toggle, the
`RO`/editable overclaim, the dead `zinc` tone."

A prior step in this session had mischaracterised step 4 as "the execution engine" and said so
in two pushed documents. Re-reading the review showed step 4 is a *removal* task and the runner
is step 5. Both documents corrected in this commit.

## Scope
**Included:** pass/fail toggle and `passed` state; hardcoded Resilience score; verdict banner;
fake partial-pass in the invariants checklist; fake-pass metrics and clean-DB-diff branches;
`RO` badge and `ro` flag; "editable" status-bar claim; dead `zinc` tone (verification only).

**Deliberately excluded:**
- **Making `schema.sql` / `solution.py` actually editable.** Step 5. Doing it now would have
  required standing up a real editor (CodeMirror/Monaco) — a dependency and architecture
  decision, not a cleanup.
- **The 45 unused vendored shadcn components.** A separate Low finding, not part of step 4.
- **`PASS_ATTEMPTS` in `lib/timeline.ts`.** Kept: `verify-timeline.ts` needs a
  non-colliding dataset to prove the detector reports zero windows when there is no collision.
  That is a genuine invariant of the model, not dead code. It is now fixture-for-the-verifier
  only, and that is stated in a comment.
- **Any real Run/Submit behaviour.** Step 5.

## Method
Read the review's step 4 line rather than my own summary of it, then traced every consumer of
the `passed` boolean (13 sites) before deleting anything, so the removal was driven by the
data flow rather than by the visible button. Each change was checked against the PRD's actual
rules — specifically §5.2, that a Resilience Score is granted by Submit and that Run never
touches it — rather than against aesthetic judgement about which state looked better.

## Decisions & Findings

**The "not run" state had to become visible, not implicit.** Deleting the toggle leaves a
question the old UI answered with a lie: what should the telemetry pane say? The options were
(a) pick one fixture and present it as the current state, (b) build a real empty state. I
chose a third framing: label the data as the **reference incident** — a recorded run of the
flawed schema, supplied as the problem to diagnose. Its `verdict: ARCHITECTURAL COLLAPSE` log
line is then honest, because a historical incident log legitimately ends in a verdict. It is
not a claim about the learner's unsubmitted work.

**The banner had to lose its colour too, not just its wording.** It was
`VERDICT_SURFACE[passed ? "pass" : "fail"]` — the semantic colour contract from step 2 was
being fed a fabricated verdict, so a green or red banner was itself the lie. It is now a
neutral surface. This is the clearest instance in the project of a colour contract and a data
honesty problem being the same problem.

**The score could not be kept at either value.** With the toggle gone, one of 1874/1840 had
to survive. Keeping 1840 would fabricate a score for unsubmitted work, violating the PRD's
central mechanic. So the top bar reads `Resilience —` / "Not scored". The visual weight of
that slot is intentional: it is the thing the learner is working toward.

**`passed || i === 1` was the most diagnostic single expression in the file.** It marked one
of three "must hold" invariants as passing with no referent for the `i === 1` case. It existed
to make the panel look less uniformly bad. All three are shown as violated, which is what the
seeded incident actually does.

**The `ro` flag was backwards from the overclaim.** The data set `solution.py: ro: false`, so
the status bar claimed the learner's own code file was writable while the pane rendered a
read-only `<table>`. The review's suggestion — "change the status bar to read read-only and
treat the whole pane as a figure" — is the one taken. The flag is removed rather than left
dormant, and a comment records that step 5 restores it once the editor is real, so the
removal does not read as an oversight.

**`zinc` was already gone, and that was verified rather than credited.** Step 4 calls for
removing a dead `zinc` pill tone; it disappeared as a side effect of step 2's semantic-role
rewrite. Reported as already-resolved, not as work done here.

**One guardrail bug was caught only by negative-testing it.** The new rule banning text below
the legibility minimum was first written as `text-\[[0-8]px\]`, which does not match 9px — the
exact size the review had flagged on the `RO` badge. Injecting `text-[9px]` produced zero
failures, which is what exposed it. Corrected to `[0-9]px`. All four honesty rules are now
negative-tested.

## Changes Made
Frontend (`pixel-perfect-replication`, **uncommitted** — Lovable-synced, no commit requested):
- `src/routes/index.tsx` — toggle, `passed` state and 13 prop sites removed; score → unscored;
  banner → neutral "Reference incident"; fake partial-pass, fake-pass metrics and clean-DB-diff
  branches removed; `ro` flag and 9px `RO` badge removed; status bar → "read-only";
  `PASS_ROWS`/`PASS_LOGS` deleted; `FAIL_*` → `SEEDED_*`; orphaned `Repeat2`, `Check`,
  `VERDICT_SURFACE` imports dropped. 1018 → 870 lines.
- `src/components/arch/collision-timeline.tsx` — `passed` prop removed.
- `scripts/verify-semantics.ts` — honesty contract added (6 rules), wired into `npm run verify`.

This repo:
- New `Frontend_and_UI/ARCHCODE-2026-09-26-fabricated-verdicts-and-editable-overclaim.md`
- This report
- Corrections to two pushed documents that mislabelled step 4 as the execution engine.

## Verification
```bash
npm run verify    # 88 assertions (timeline + semantics + shortcuts) then tsc --noEmit
npx eslint src/routes/index.tsx src/components/arch/ src/lib/ scripts/
npx vite build    # built in ~2.8s, no errors
```
- `tsc --noEmit` clean; eslint clean on all touched files; build clean.
- Honesty rules negative-tested: injected a hardcoded score, an `editable` claim, a `9px`
  size, and a verdict status — each produced a `FAIL` and exit 1; restored → exit 0.
- Confirmed by grep that no `text-[9px]`, `Toggle Pass`, `1874`/`1840`, or `>editable<`
  remains in the product surface.

**Not verified:** anything requiring a browser. The reframed banner, the `—` score, and the
read-only status bar have not been seen rendered.

## Follow-ups / Deferred
1. **Run/Submit are still bound but inert.** Step 4 removed the *fake* result but did not
   create a real one, so a primary shortcut still does nothing visible. A dead primary
   shortcut remains worse than none; the honest options are to withhold the bindings until the
   runner exists, or to disable the buttons. Unchanged from the keyboard step and still open.
2. **`schema.sql` / `solution.py` editable** — step 5, and the reason the `ro` flag was removed
   rather than left dormant.
3. **Scenario selector, Plan/Trace, pane resizing** — step 5.
4. **45 unused vendored shadcn components** — separate Low finding, unaudited.
5. **`npm run verify` in CI** so the honesty rules actually gate merges.
6. **Native menu commands** — blocked on the Tauri/Electron-vs-web decision.
7. **PRD §5.2 "Run never touches the score"** still only in a tooltip; now more visibly
   pressing, because the score slot itself is empty and the copy explaining *why* is not on
   screen.

## References
- `ARCHCODE-DESIGN-REVIEW.md` — sequencing step 4
- `ARCHCODE-PRD.md` §5.2 — score granted by Submit; Run never touches the score
- `ARCHCODE-2026-09-26-fabricated-verdicts-and-editable-overclaim.md` — defect entry
- `reports/ARCHCODE-2026-09-25-semantic-colour-roles.md` — the colour contract the fabricated
  verdict was feeding

---

**Completed By:** Claude (Anthropic)
**Duration:** ~1 session

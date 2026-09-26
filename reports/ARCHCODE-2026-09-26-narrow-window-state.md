# Deliberate narrow-window state instead of a degraded cockpit (HIG review, finding 6)

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Type:** Refactor / Accessibility Decision
**Status:** Completed

## Summary
Folded the review's finding 6 into the end of step 4, ahead of step 5. The cockpit's
responsive fallback was not a degradation but a disappearance: below 1024px a one-column grid
with implicit `auto` rows let the spec pane consume the height, and the root's
`overflow-hidden` clipped the editor, the telemetry pane, and the collision timeline out of the
viewport. The cockpit is now gated behind a container query and replaced below the threshold by
a deliberate state that states the constraint and renders the problem brief inline — the one
part of the product that genuinely reflows.

## Context / Trigger
Step 4's report and the availability work both added content to the 48px header, which made the
already-unverified narrow layout more fragile right before step 5 would add panes to it. The
user chose to fold finding 6 in first. The sequencing rationale is sound: step 5 adds surface
area to a layout whose failure mode is silent clipping, so establishing the gate first means
the new work is constrained by a mechanism that fails visibly instead.

## Scope
**Included:** container query replacing the viewport breakpoint; removal of the `grid-cols-1`
fallback; new `NarrowNotice`; brief hoisted to shared constants; layout contract in
`verify-semantics.ts` (11 rules).

**Deliberately excluded:**
- **A brief route.** The review suggested linking to the read-only problem brief. No such route
  exists, and inventing one is step 5's product surface. The brief is rendered inline instead.
- **`matchMedia`/`ResizeObserver` to gate JS behaviour on width.** The `?` shortcut sheet still
  opens in a narrow window. Judged not worth a JS width listener for a milestone gap.
- **Any other responsive work.** Below 1024px there is now exactly one designed state, not a
  family of breakpoints.

## Method
Read finding 6 rather than the summary of it, then traced the failure to the interaction of
three specific declarations (`grid-cols-1`, `min-h-0`+`fr` siblings, root `overflow-hidden`)
rather than treating "responsive" as a tuning problem. Because the failure is silent — a
clipped pane throws nothing — the fix was verified two ways that do not need a browser: by
asserting the absence of the specific fallback, and by inspecting the built stylesheet to
confirm the container-query rules actually win the cascade.

## Decisions & Findings

**The fix was replacement, not repair.** The review was explicit that below the breakpoint "the
honest answer is a message, not a squeeze", and that holds up: the panes have genuinely
different height requirements, and under `auto` rows plus `overflow-hidden` there is no
breakpoint value that makes both legible. Tuning `min-h-*` values would have produced a layout
that technically renders and practically cannot be used.

**Container query over media query, per the review's second instruction.** `layout.md › Size
classes` asks for available space rather than device type, and a viewport `lg:` query counts
scrollbars and browser chrome the cockpit never had. The root is now `@container` and the gate
is `@min-[1024px]`. This is the difference between "this display is 900px" and "this cockpit has
900px", which matters as soon as the app can be docked, split, or embedded.

**The suggested link would have been a dead affordance.** The review's fix says to give the
narrow state "a link to the read-only problem brief, which does reflow". There is no brief route
in this scaffold, so following the advice literally produces a link to nowhere — precisely the
defect class the previous two entries removed. Rendering the brief inline is both honest and
strictly more useful, and it is recorded as a deliberate deviation rather than a silent one.

**The brief is now a shared constant.** It was about to exist in two places. Two copies of
product copy is a drift generator, and a brief that reads differently in the cockpit and the
fallback undermines both. `BRIEF_TITLE` / `BRIEF_BODY` are defined once and asserted to be
defined once.

**The cascade order was verified, not assumed.** `hidden` plus `@min-[1024px]:flex` only works
if the container-query utility sorts after the base utility in the emitted stylesheet. That is a
Tailwind-internals detail, not a documented guarantee, so the built CSS was inspected directly:
base `.hidden` at offset 10244, `@min-[1024px]:flex` at 64604, `@min-[1024px]:hidden` at 64641,
both under `@container (width>=1024px)`. Correct today; the verifier asserts the pairing so a
Tailwind upgrade that reorders it fails the build rather than silently collapsing the layout.

**Two guardrail weaknesses were found by testing the guardrail.** The layout rules initially
matched their own explanatory comments — the comments quote `grid-cols-1 lg:grid-cols-...`
verbatim while explaining its removal — so a naive whole-file match failed on correct code.
Comments are now stripped before the layout rules run. Separately, asserting only that
`@min-[1024px]` was *present* was toothless: moving the cockpit's own gate to 900px still
passed, because the narrow-state rule retained 1024px. The rules now name the two exact
utilities (`:flex` and `:hidden`), which makes the threshold load-bearing. Both defects were
invisible to reading the rule and only surfaced by injecting faults.

**Unverified, and worth saying plainly.** The review flagged that it could not confirm this
failure visually. Neither could this work — no browser is available. The bug's *absence* is
argued from the grid definitions plus a source-order check of the built CSS. That is weaker than
seeing the layout at 900px, and the entry says so rather than claiming the finding is closed
with confidence.

## Changes Made
Frontend (`pixel-perfect-replication`, **uncommitted** — Lovable-synced, no commit requested):
- `src/routes/index.tsx` — root is `@container`; cockpit wrapped in
  `hidden … @min-[1024px]:flex`; `grid-cols-1` fallback deleted; new `NarrowNotice`; brief
  hoisted to `BRIEF_TITLE` / `BRIEF_BODY` and shared with `SpecPane`
- `scripts/verify-semantics.ts` — layout contract (11 rules), comment-stripped source

This repo:
- New `Frontend_and_UI/ARCHCODE-2026-09-26-cockpit-clipped-below-1024px.md`
- This report

## Verification
```bash
npm run verify    # 90 assertions (timeline + semantics + shortcuts) then tsc --noEmit
npx eslint src/ scripts/
npx vite build    # built in ~2.5s, no errors
```
- `tsc --noEmit` clean; eslint clean on all touched files; build clean; Prettier clean.
- All 11 layout rules negative-tested: 1-column fallback reintroduced, viewport `lg:`
  breakpoint, container query removed, cockpit gate at the wrong threshold, narrow-state gate at
  the wrong threshold, narrow state removed, 1024px requirement unstated, dead `/brief` link,
  duplicated brief body, and a second case confirming comments alone do not trip the rules.
  Each produced a `FAIL`; restored → exit 0.
- Built CSS inspected: `container-type: inline-size` emitted on the root, both
  `@container (width>=1024px)` gates emitted and both sorting after base `.hidden`.

**Not verified:** rendering at any width. No browser in this environment, so the 900px check the
review recommended remains outstanding.

## Follow-ups / Deferred
1. **Visual check at 900px** — the one thing that would actually confirm this. Needs a browser.
2. **`?` opens the shortcut sheet in narrow windows**, listing pane bindings for panes that are
   not rendered. Harmless; would need a JS width listener to gate.
3. **Step 5 panes** now land against a container-query gate, so a future third column degrades
   to the narrow state rather than clipping silently.
4. **Native menu commands** should gate on `isAvailable`/width rather than duplicating either
   check.
5. **`npm run verify` in CI.**
6. **Header density** — the availability work added a line to a 48px header whose narrow-width
   behaviour is still unconfirmed.

## References
- `ARCHCODE-DESIGN-REVIEW.md` finding 6 — original analysis
- `layout.md › Size classes` — gate on available space, not device type
- `layout.md › Adaptability`; `split-views.md › Phone (iOS)`
- `ARCHCODE-PRD.md` §13 — collision timeline is desktop-only media
- `ARCHCODE-2026-09-26-cockpit-clipped-below-1024px.md` — defect entry

---

**Completed By:** Claude (Anthropic)
**Duration:** ~1 session

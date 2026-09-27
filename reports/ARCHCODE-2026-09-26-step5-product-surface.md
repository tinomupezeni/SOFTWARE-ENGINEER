# ArchCode step 5: the product surface — real editor, real scenario, real telemetry, real splits

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Type:** Implementation + Scope Decision
**Status:** Completed (visual sign-off outstanding)

## Summary
Step 5 turned the cockpit from a static mock into a working surface: a CodeMirror 6 editor
with independent per-file buffers and reset, a keyboard-navigable scenario radiogroup that
drives a derived read-only `sandbox.yml`, seeded Plan and Trace views inside the telemetry
pane, and a real resizable-pane layout with a 280px spec floor, individually collapsible
panes, and named keyboard-operable handles. The verification is behavioural rather than
visual — 75 CDP-driven interaction assertions, 12 focus assertions, 9 width measurements, and
a 19-case mutation suite proving the new guardrails can actually fail. Four defects were
found and fixed during the work, and one process failure was found in my own verification:
I reported a visual review that had not happened.

## Context / Trigger
The design review (`ARCHCODE-DESIGN-REVIEW.md`) sequenced the build in numbered steps. Step 5
exists because the earlier steps produced a layout with a spec pane, an editor, and a
telemetry pane that were all presentational — no file was editable, the "problem" control was
a dead button, there was no way to see a plan or a trace, and the pane proportions were
hardcoded in a CSS grid. Findings 1–6 from the review pointed at exactly this: an IDE-shaped
product with none of the IDE's substance. Step 6 (real runner/backing service) is explicitly
out of scope and blocked.

## Scope
Included:
- Editable `solution.py` and `schema.sql`; read-only, scenario-derived `sandbox.yml`.
- Per-file buffer isolation, dirty indication, and reset-to-pristine.
- Four-scenario APG radiogroup with roving focus and full keyboard support.
- Seeded `Plan` and `Trace` telemetry tabs.
- `react-resizable-panels@4` horizontal and vertical splits, 280px spec floor, per-pane
  collapse, accessible handles, double-click reset.
- Verification guardrails for all of the above, proven by mutation testing.

Explicitly excluded, with reasons:
- **Execution, grading, verdicts, scores.** `CAPABILITIES.execution` stays `false`. Run and
  Submit remain `aria-disabled` and refuse activation. Implementing a fake grader is exactly
  the "fabricated verdicts" defect already logged for this project
  (`ARCHCODE-2026-09-26-fabricated-verdicts-and-editable-overclaim.md`).
- **Plan and Trace content generation.** These are recorded Thundering Herd fixtures. They are
  labelled as reference incidents, not as output derived from the selected scenario, because
  the PRD defines no algorithm that could produce them.
- **Layout persistence.** Deliberately no `autoSaveId`. A saved split that outlives a redesign
  is harder to recover from than no memory at all.
- **Native menu-bar command registration.** Blocked on the Tauri/Electron-versus-web decision.
- **Shortcuts beyond the tab/spec bindings.** The PRD defines none, so the shortcut surface is
  still without formal sign-off.

## Method
- Read the PRD §§5, 5.1, 8, 9 and the pressure test for the Plan requirement before designing
  anything, and checked the review's own sequence rather than inventing a scope.
- Preferred the platform over a dependency where the dependency was dead weight: the
  CodeMirror packages are imported directly instead of through a wrapper.
- Verified by driving the real app. Built a zero-dependency Chrome DevTools Protocol harness on
  Node 22's built-in `WebSocket`, so verifying the UI adds no test-runner dependency
  (now tracked as `scripts/capture.mjs`). It includes a hydration wait: early interaction
  attempts failed because `Input.dispatchKeyEvent` was landing on a server-rendered DOM React
  had not hydrated yet, and dispatching into a not-yet-hydrated tree is silently dropped,
  which is indistinguishable from a broken interaction.
- Cross-checked every claim against the DOM or a measured number: widths, focus movement, ARIA
  state, drag results, computed styles. No assertion rests on a screenshot.
- **Mutation-tested the guardrails.** This was the decisive methodological step. A check that
  has never failed is not known to work, so each product-surface invariant was broken
  deliberately and the suite was required to go red. The first run caught 15 of 19; triaging
  the four escapes produced the most valuable findings in this report. The suite now lives in
  the repo as `scripts/verify-guardrails.ts` and runs as part of `verify`, and it enforces two
  rules on itself: every mutation must be **verified to have applied** (a `sed` that matches
  nothing exits 0 and looks exactly like a pass), and the baseline must be re-verified green
  after every probe so a crashed run cannot leave the tree mutated.
- **Moved the harnesses out of `/tmp`.** The first versions lived there and were lost to a tmp
  cleanup, taking four review screenshots with them. `scripts/capture.mjs` (dependency-free
  CDP) and `scripts/verify-guardrails.ts` are now tracked files.
- **Re-verified on a bun-installed tree.** See "Second pass" below: switching package managers
  surfaced three further defects that the npm run had masked.

## Decisions & Findings
**Editing model.** Buffers are `Record<ProblemFileId, string>` rather than
`Record<string, string>`. Under `noUncheckedIndexedAccess` the latter widens every lookup to
`string | undefined`, and a silently empty editor pane is exactly the kind of quiet wrongness
this product must not ship. The typed key makes a missing buffer a type error.

**`sandbox.yml` is derived, not editable.** The PRD treats it as scenario output. It is
regenerated whenever the scenario changes and rendered read-only, so a user cannot hand-edit
a fixture into a state the system would never produce.

**Scenario picker is a radiogroup, not a listbox.** Four mutually exclusive values, so
`role="radiogroup"` with `role="radio"` children and roving `tabindex`. The mutation suite
established that the container role alone proves nothing: `role="option"` children over a
`radiogroup` is a listbox, and the original guardrail stayed green through that change.

**Plan/Trace membership had to be parsed, not grepped.** The original check tested for the
string `"Trace"` anywhere in the file, which is satisfied by `tab === "Trace" && <TraceView />`
and by the shortcut table. Deleting the tab from `TELEMETRY_TABS` left it green. The check now
extracts the array from its declaration and asserts membership and `length === 6`.

**Comments can satisfy a source assertion.** The 280px floor check regexed raw source for
`minSize={280}`, and my own comment explaining the floor contained that literal text. The
assertion was satisfied by documentation of the feature instead of the feature. All
source-inspection assertions now run against a comment-stripped copy via a shared
`stripComments` helper.

**Two assertions could not fail at all.** One ended in `|| true`; one used a ternary whose
false branch was the passing state (`cond ? mustHold : true`), so it passed whenever its
condition was false. Both read like real checks in review. This is the most important finding
of the session: the suite reported `all assertions passed` continuously while the features it
was meant to protect were being deleted.

**Hit area without a visible thick divider.** The handle is a 1px line with a 9px hit area
grown via a pseudo-element and an `aria-hidden` span on the cross axis. Sizing the element
itself at 9px would have shown a 9px divider. Measured at 9px effective.

**Pane collapse is a feature, not a bug.** Collapsing telemetry to exactly zero is how the
user maximises the spec and editor for a large file. It is a labelled, focusable control, so it
stays reachable.

**The 280px floor is a real floor, not a suggestion.** Previously encoded as
`grid-cols-[minmax(280px,30%)_1fr]`. Now `minSize={280}`, verified by dragging far past the
limit and reading the resulting width: it stops at exactly 280px.

**Switching package managers was the most productive bug hunt of the session.** `bun install`
resolved `react-resizable-panels` to 4.12.2 where npm had chosen 4.13.3, so the re-run was
not a formality. The first clean `bun run verify` then exposed three latent defects: the
honesty-failure reporter crashed on its first finding instead of reporting it; a generated
OpenAPI declaration was scanned as hand-written UI; and the step-5 refactor had silently
dropped the narrow state's 1024px explanation, which the guardrail for it had failed to catch
because it was coupled to a component name that no longer existed. All three are logged
separately. None of them could have been found while the suite was green.

**The brief was never lost, only mis-grepped.** `CompactWorkspace` renders the brief by
reusing `SpecPane`, so `BRIEF_BODY` is declared once and appears in both surfaces — exactly
what the hoisting was for. A literal grep for `{BRIEF_BODY}` inside the old component name
could not follow the indirection and reported it as missing. Two of the three narrow-state
failures were artefacts of checking *how* the code is written rather than *what* the user
sees.

**My verification overclaimed.** I reported the layout as visually verified on the basis of
headless screenshots that I cannot view. Logged as its own entry and reclassified as an open
item. The structural evidence is genuine but is evidence of geometry, not of appearance.

**Two of my own mutations were no-ops.** `sed 's/"Trace",//'` (no trailing comma on the last
array element) and `sed 's/collapsible$//'` (token is mid-line) changed nothing, so they
"passed" trivially. A mutation suite needs its mutations verified to have applied — otherwise
it manufactures false confidence in the same way the original guardrails did.

## Changes Made
New, uncommitted in `pixel-perfect-replication`:
- `src/lib/problem.ts` — file ids, pristine buffers, `SCENARIOS`, `sandboxYaml()`.
- `src/components/arch/code-editor.tsx` — CodeMirror 6, per-file `EditorState` and compartments.
- `src/components/arch/scenario-picker.tsx` — APG radiogroup, roving focus.
- `src/components/arch/plan-view.tsx`, `trace-view.tsx` — seeded reference views.
- `src/components/arch/split.tsx` — `react-resizable-panels@4` used directly; px-or-percent
  sizes; orientation-aware handles; required `label`; double-click reset.
- `src/components/arch/shortcut-help.tsx` — **focus trap added** (see entry).
- `scripts/verify-semantics.ts` — step-5 product-surface block rewritten; generated sources
  excluded (visibly) from source-text checks; narrow-state guards made rename-proof; the
  honesty reporter's undeclared counter removed.
- `scripts/verify-guardrails.ts` *(new)* — 25-case mutation suite; wired into `verify` as
  `test:guardrails`.
- `scripts/capture.mjs` *(new)* — dependency-free CDP screenshot + structure capture; wired in
  as `capture`.

Modified:
- `src/routes/index.tsx` (+736/−552; +589/−405 ignoring whitespace) — editor, picker, Plan/Trace
  tabs, split layout, removal of the dead problem button. The diff is larger than the feature
  because prettier reformatted pre-existing lines; the whitespace-insensitive figure is the
  honest measure of the change.
- `src/styles.css` (+58/−3) — **dead `--color-border-strong` token mapped** (see entry).
- `package.json` — eight direct CodeMirror dependencies; `test:guardrails` and `capture`
  scripts; `verify` now includes the mutation suite.
- `bun.lock` — regenerated by `bun install` under the repo's 24h release-age guard.

Deliberately not modified: `src/components/ui/resizable.tsx` (generated code; avoided instead
of patched, see entry), and the remaining `bun.lock`.

Per `AGENTS.md`, none of this is committed — the frontend tree is left dirty for review.

## Verification
- `bun run verify` — rc 0, **101 assertions passed**, including the mutation suite
  (semantics + timeline + shortcuts + guardrails + tsc).
- Mutation suite — **25 caught, 0 escaped, 0 wrong-reason, 0 no-op**, baseline restored green.
  (Was 15/19 before the gaps were closed; 25 after adding the narrow-state cases.)
- `npx vite build` — rc 0.
- ESLint on `src/routes/index.tsx`, `src/components/arch/`, `scripts/` — clean. The 8
  remaining Prettier warnings are all in untouched pre-existing files
  (`src/integrations/supabase/*`, `src/routes/README.md`); none are in files this step touched.
- CDP interaction suite — **75 passed, 0 failed**, no runtime errors: file tabs with hit-test
  diagnostics, editing and reset, per-file buffer isolation with no bleed, picker roving
  focus, derived `sandbox.yml`, Plan/Trace bodies and the reference-incident banner, handle hit
  area / ARIA / keyboard resize / drag, the 280px floor, telemetry collapse to zero and reopen,
  the shortcut dialog, `aria-disabled` execution controls, and reload discarding edits.
- Focus suite — **12 passed, 0 failed** (the focus leak fix).
- Viewport measurements at 1440, 1280, 1100, 1024, 1023, 1000, 900, 800, 700px — cockpit
  rendered at ≥1024px, deliberate narrow state below it, **zero horizontal and vertical
  document overflow at every width**, no runtime errors.
- Confirmed every `@codemirror/*` package imported by the editor is declared in
  `package.json` (no undeclared transitive reliance).
- `node scripts/capture.mjs` — **ALL PASS** at 1440x900, 1280x800, 1024x768 and 900x800:
  cockpit rendered at >=1024px, compact workspace below it, **zero horizontal and vertical
  overflow at every width**, no console errors or exceptions.
- Screenshots regenerated and stored **outside /tmp** at
  `Club Zero/review-shots/shot-{1440x900,1280x800,1024x768,900x800}.png`, verified as valid
  PNGs at the stated dimensions.
- A throwaway `__probe.html` in the repo was removed.

## Follow-ups / Deferred
- **Visual review of four screenshots is outstanding** and is the reason this report's status
  is not "signed off". The user elected to review them personally; they are at
  `Club Zero/review-shots/`.
- **Move `tsc --noEmit` to the front of the `verify` chain** and give `scripts/` its own
  tsconfig. The undeclared-variable bug in the honesty reporter was a type error that the
  typechecker could have caught, but the typechecker ran after the script that crashed.
- Add a `package.json` ↔ `bun.lock` drift check, and a check that rejects a foreign lockfile.
- Audit the remaining guardrails for symbol-name coupling, which is what let the narrow-state
  regression through.
- Mechanically reject the `|| true` / inverted-ternary shapes in assertions.
- Add "every `aria-modal` traps focus" to `pre_deploy_verification.md`, plus the rule against
  perceptual language for structural checks.
- Formal sign-off still missing for the shortcut surface, pending a PRD that specifies one.
- Dead `.dark` block in `src/styles.css`; header density; 45 unaudited shadcn components; no
  CI integration — all pre-existing follow-ups, untouched.
- `drizzle/schema.ts` and `src/routes/__root.tsx` are also dirty from earlier steps; the working
  tree spans steps 2–5, not step 5 alone.

## References
Bug entries raised by this work:
- `Frontend_and_UI/ARCHCODE-2026-09-26-guardrails-that-could-not-fail.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-modal-dialog-without-focus-trap.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-border-strong-token-never-mapped.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-stale-shadcn-resizable-wrapper-v4-api.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-dead-problem-selector-affordance.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-screenshot-visual-verification-claim.md`
- `DevOps_and_Infrastructure/ARCHCODE-2026-09-26-bun-lock-stale-missing-step5-dependencies.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-honesty-reporter-crashed-on-first-failure.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-generated-types-scanned-as-hand-written-ui.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-narrow-state-lost-1024px-explanation.md`

Earlier ArchCode entries: `reports/ARCHCODE-2026-09-26-narrow-window-state.md`,
`reports/ARCHCODE-2026-09-26-execution-availability.md`,
`reports/ARCHCODE-2026-09-26-keyboard-shortcut-system.md`.

Source: `ARCHCODE-PRD.md` §§5, 5.1, 8, 9; `ARCHCODE-DESIGN-REVIEW.md` finding 6 and the step
sequence; `ARCHCODE-pressure-test.md` (Plan view);
`src/routes/index.tsx`; `src/lib/problem.ts`; `src/components/arch/*`;
`scripts/verify-semantics.ts`; `scripts/verify-guardrails.ts`; `scripts/capture.mjs`;
`Club Zero/review-shots/*.png`.

---

**Completed By:** Claude (Anthropic), on behalf of the user
**Duration:** ~1 working session

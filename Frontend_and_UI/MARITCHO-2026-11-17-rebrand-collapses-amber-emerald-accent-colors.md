# Rebrand collapses the amber and emerald accent colors to near-identical cyans

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Medium
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
The teardrop-palette rebrand in `frontend/src/styles/tokens.css` changed `--amber` from `#f59e0b`
(orange, buyer/primary accent) and `--emerald` from `#10b981` (green, worker accent / verified-success
color) to `#00abe3` and `#00ace8` respectively — two cyan tones differing by only 1 unit in the green
channel and 5 units in blue, visually indistinguishable to users. `--amber-ink`/`--emerald-ink` also
both became `#ffffff` (previously distinct `#1c1917`/`#052e1f`), erasing another differentiator. These
two token families are used throughout the app to distinguish genuinely different semantic states —
e.g. `.tag--verified` (emerald, a trust/verified badge) vs. `.chip[aria-pressed="true"]` (amber, a
selected/primary-action chip), and `icon-tile--amber` vs. `icon-tile--emerald` distinguishing featured
vs. regular job cards on the same screen — all of which now render in essentially the same color.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- A "verified/Checked by Maritcho" badge and a "selected" chip, or a "featured" vs. "regular" job
  card icon tile, now render in nearly identical color, losing the at-a-glance visual distinction
  users previously had between these states.

## Environment Details
- **Server/Host:** N/A (Next.js frontend styling)
- **Services Affected:** All screens using amber/emerald-coded UI (job cards, worker directory,
  account screens, verified badges, selected chips)
- **Related Components:** `frontend/src/styles/tokens.css`, `frontend/src/styles/components.css`
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding (independently surfaced by three separate review angles) claimed the rebrand's hex
value sampling accidentally collapsed two previously-distinct accent colors into near-identical
values, with real UI consequences beyond cosmetic duplication.

### 2. Root Cause Analysis
- `git diff main...pr-12 -- frontend/src/styles/tokens.css`: `--amber: #f59e0b` → `#00abe3`;
  `--emerald: #10b981` → `#00ace8`. The pre-PR colors (orange vs. green) were clearly distinct; the
  post-PR colors differ by 1 unit in G and 5 in B — visually indistinguishable cyan tones.
- `--amber-ink`/`--emerald-ink` also both became `#ffffff` (previously `#1c1917`/`#052e1f`), removing a
  second differentiator used for text-on-accent contrast.
- Confirmed genuinely distinct semantic usage, not coincidental co-presence:
  - `components.css:607-610`: `.tag--verified` uses emerald-tint/edge/pale for a verified/trust badge.
  - `components.css:520-537`: `.chip[aria-pressed="true"]`/`.chip--soft[aria-pressed="true"]` use
    amber for a selected/pressed chip state; `.chip--emerald[aria-pressed="true"]` is a separate
    emerald-styled pressed variant — now near-identical to the amber one.
  - `frontend/src/features/worker/OpenJobCard.tsx:38`: `isFeatured ? "icon-tile--amber" : "icon-tile--emerald"`
    distinguishes featured vs. regular job cards in the same list — now nearly the same color.
  - `frontend/src/features/employer/WorkerPublicProfileScreen.tsx` (lines 80-96, 122-125): uses
    `text-emerald`/`tag--verified` for a "Checked by Maritcho" verified badge, and `text-amber` for an
    unrelated "on time %" stat highlight on the same screen — different meanings, now rendered nearly
    identically.
  - Broader grep confirms `icon-tile--amber/emerald`, `badge--amber/emerald`, `chip--emerald`, and
    `text-amber/text-emerald` pairs are used throughout employer- and worker-facing screens
    (`EmployerJobCard.tsx`, `PostJobScreen.tsx`, `CandidateCard.tsx`, etc.) for role- or status-coded
    visual distinction.

### 3. Key Findings
- This is a real, already-shipped (on `pr-12`) visual regression, not a hypothetical: the rebrand's
  color sampling appears to have picked near-identical values for two tokens meant to be visually
  distinct, likely because both were sampled from a similar region of the new brand palette without
  checking contrast against each other.

## Root Cause
The rebrand updated `--amber`/`--emerald` independently to fit the new teardrop brand palette, without
checking that the two new values remained visually distinguishable from each other — a cross-token
contrast check that the old (orange vs. green) values passed implicitly but the new (cyan vs. cyan)
values do not.

## Prevention / Rule
**Guardrail:** Add a simple color-distance check (e.g. a small script computing perceptual/Delta-E
distance between every pair of semantically-distinct accent token families — amber vs. emerald, and
any future pairs) run in CI or as a pre-commit check on `tokens.css`, failing if two tokens meant to
be visually distinct fall below a minimum distance threshold.

This directly targets the Root Cause: the regression is a measurable, mechanical property (color
distance between two specific tokens) rather than a subjective design judgment, so an automated check
would have caught it before merge.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed visual regression found during review of PR #12; it
has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Re-pick `--amber` and/or `--emerald` (and their derived tint/pale/edge/ink variants) from the new
  brand palette such that they remain clearly distinguishable, preserving the semantic
  buyer/primary-action vs. worker/verified-success distinction the rest of the app's CSS and
  components rely on.
- Add the color-distance guardrail above to prevent recurrence for future palette tweaks.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [ ] Documentation to update — none
- [x] Code changes required — re-pick distinguishable amber/emerald values in `tokens.css` (not yet
      implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced this rebrand.
- Independently corroborated by three separate review angles (cleanup/simplification, removed-behavior
  audit, and root-cause/altitude audit) during the same review pass, all converging on the same hex
  values and the same conclusion.

## References
- `frontend/src/styles/tokens.css` (`--amber`, `--emerald`, and derived tint/pale/edge/ink variants)
- `frontend/src/styles/components.css:520-537,607-610` (`.chip`, `.tag--verified`)
- `frontend/src/features/worker/OpenJobCard.tsx:38`
- `frontend/src/features/employer/WorkerPublicProfileScreen.tsx:80-96,122-125`
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)

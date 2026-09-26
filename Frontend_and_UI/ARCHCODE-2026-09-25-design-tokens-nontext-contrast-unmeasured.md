# Design system verified foreground contrast and skipped everything else

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

ArchCode's token system was tuned to make text readable and nothing else. Every text colour
cleared WCAG AA comfortably — 4.71:1 to 10.14:1 across all surfaces — which created the
impression of an accessible palette. No non-text element had ever been measured. Pane
dividers, card boundaries, table rules and the timeline's data bars all sat between 1.14:1
and 2.87:1, below the 3:1 that WCAG 1.4.11 requires for anything needed to identify a
control, a state or a graphical object.

## Symptoms

- No visual defect was reportable by a user. This was found by measurement, not complaint.
- The app's entire structural hierarchy — which pane is separate from which, where a card
  ends, what separates two log lines — lived in a 1.30:1 border.
- Timeline bars, the only dataset in that view, were 1.78:1 against their own track, and
  their only distinguishing channel was hue.
- De-emphasised text (line numbers, log timestamps, comments) used `text-muted-foreground/60`
  and `/70`, measuring 2.86:1 and 3.50:1 against a 4.5:1 requirement.

## Environment Details

- **Server/Host:** Local development
- **Services Affected:** All views; severity highest in the telemetry pane
- **Related Components:** `src/styles.css` token block, timeline bars, log line numbers
- **Time First Observed:** 2026-09-25, during the HIG design review

## Investigation Steps

### 1. Initial Diagnosis

Listed the tokens in `src/styles.css` and the alpha modifiers actually used in
`src/routes/index.tsx`, then measured them.

### 2. Root Cause Analysis

Built an oklch → sRGB → WCAG relative-luminance converter and ran every
foreground/background pair used in the source, including alpha-composited surfaces such as
`bg-primary/10` over `bg-surface` and bars at `/40`, `/50`, `/60`. A hand-written oklch
approximation is not reliable at these lightness levels, so the numbers had to be computed
rather than estimated.

```bash
python3 -c "
import math
def oklch(L,C,H):
    h=math.radians(H); a,b=C*math.cos(h),C*math.sin(h)
    l_=L+0.3963377774*a+0.2158037573*b; m_=L-0.1055613458*a-0.0638541728*b; s_=L-0.0894841775*a-1.2914855480*b
    l,m,s=l_**3,m_**3,s_**3
    r= 4.0767416621*l-3.3077115913*m+0.2309699292*s
    g=-1.2684380046*l+2.6097574011*m-0.3413193965*s
    b=-0.0041960863*l-0.7034186147*m+1.7076147010*s
    return tuple(max(0,min(1,v)) for v in (r,g,b))
"
```

### 3. Key Findings

| Pair | Measured | Required | Result |
| --- | --- | --- | --- |
| `--muted-foreground` | 5.66–6.11:1 | 4.5:1 | pass |
| `--primary` | 8.05–8.69:1 | 4.5:1 | pass |
| `--destructive` | 4.71–5.08:1 | 4.5:1 | pass |
| `--warning` | 9.39–10.14:1 | 4.5:1 | pass |
| Submit button | 8.48:1 | 4.5:1 | pass |
| `text-muted-foreground/60` | 2.86:1 | 4.5:1 | **fail** |
| `text-muted-foreground/70` | 3.50:1 | 4.5:1 | **fail** |
| `--border` on `--card` | 1.30:1 | 3:1 | **fail** |
| timeline bars vs track | 1.78–2.87:1 | 3:1 | **fail** |
| `.dark --accent` on `.dark --card` | 1.22:1 | 4.5:1 | **fail** (dead code) |

- The timeline bars needed no new colours. At full opacity `--primary` measures 8.05:1 and
  `--destructive` 4.71:1. The failure was entirely the `/40` and `/60` alpha modifiers,
  which were used to soften bars and in the process destroyed the distinction.
- Softening a mark by transparency is a legitimate technique, but it must be paired with a
  second channel. Here it was the only channel.

## Root Cause

The palette was validated on one axis. Every value in the token block is a foreground value,
and text is what a designer checks first because text failure is visible. Borders and data
marks have no failure signal: nothing looks wrong, they simply stop being perceivable, so
nothing prompts a measurement. The alpha modifiers compounded it, since lowering opacity
looks like a design decision rather than a contrast regression.

## Prevention / Rule

**Guardrail:** Treat `oklch` tokens as unverified until measured, and require a check that
asserts every non-text token against the surface it sits on clears 3:1 — run as part of the
build, not on demand, with the alpha modifiers under test included.

This closes the gap because the failure mode is silent by construction: a designer reviewing
a screenshot cannot detect a 1.3:1 border, and a token diff cannot either, since a changed
lightness is just a number. Only an assertion comparing the token to its actual background
catches it, and asserting the *composited* value is what catches the alpha case, which is
where every real failure in this codebase was.

## Solution

### Immediate Fix

- Added `--border-strong: oklch(0.52 0.006 286)`, which measures 3.32:1 on `--card`, 3.44:1
  on `--surface` and 3.59:1 on `--background` — clears 3:1 on every surface with margin.
  Applied to data-bearing tracks, pane dividers and conflict-region boundaries.
- Raised `--border` from `oklch(0.29)` to `oklch(0.32)` for card definition only. Kept
  deliberately below 3:1: it marks decorative edges, and 1.4.11 applies to elements needed
  to *identify* a control or state, not to decoration. One token doing both jobs is what
  forced the original compromise.
- Removed all alpha modifiers from timeline marks. Reads became outlined rather than filled
  (`border-strong` outline on `--card`, 3.32:1), which both clears the requirement and puts
  the visual emphasis on writes, which is what a reader is looking for.
- Replaced `text-muted-foreground/60` and `/70` with the full token. **Correction:** when this
  entry was first written that claim was premature — it was true only inside the new timeline
  component, and four instances remained in `src/routes/index.tsx` (line-number gutter, `RO`
  badge, log timestamps, the syntax `C` constant) still measuring 2.86:1 and 3.50:1. Those were
  fixed in the follow-up semantics pass; see
  `ARCHCODE-2026-09-25-colour-roles-not-hues.md`. The gap was that the fix was scoped to the
  file being rewritten rather than to the token, so "replaced the alpha modifiers" was verified
  by reading the diff of one component instead of grepping the tree.
- Added `color-scheme: dark`, so the OS renders native controls (scrollbars, form widgets,
  the caret) dark without a `.dark` class needing to be applied.
- **Correction (2026-09-25):** an earlier version of this entry also claimed the dead `.dark`
  block had been removed. It had not — it is still at `src/styles.css:122`, and the removal was
  never made. `.dark` is unreferenced because nothing toggles that class, which is a real risk:
  adding a theme toggle later would activate a block whose `--accent` measures 1.22:1 against
  `--card`. The claim was wrong because the same diff-scoped verification mistake this entry
  documents was repeated while writing the entry itself.

### Long-term Fix

- Promote the contrast converter into the repo and run it over the token set in CI, so a
  token edit that breaks a surface fails the build.
- The oklch → sRGB → WCAG converter is a prerequisite for that check and does not currently
  exist anywhere in the repository.

## Prevention

- [x] `--border-strong` token for structural and data-bearing edges
- [x] Alpha modifiers removed from all data marks
- [x] `color-scheme: dark` declared
- [ ] Delete the dead `.dark` block (`src/styles.css:122`) — still present despite an earlier
      claim here that it was removed
- [ ] Add the converter to `scripts/` and wire a token contrast check into the build
- [ ] Audit the 45 unused shadcn components for the same modifier pattern before any are
      adopted

## Related Issues

- `ARCHCODE-2026-09-25-collision-timeline-rendered-no-collision.md` — the same view, same
  session; the bars in this entry were that component's marks
- Design review Critical 2

## References

- `ARCHCODE-DESIGN-REVIEW.md` — Critical 2 and the contrast table
- `src/styles.css` — `--border`, `--border-strong`, `--collision-fill`, `--protected-fill`
- WCAG 2.2 SC 1.4.11 (Non-text Contrast), SC 1.4.3 (Contrast Minimum)

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~1 hour

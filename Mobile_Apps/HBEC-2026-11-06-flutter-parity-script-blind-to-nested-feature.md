# Parity script reports a built Flutter feature as "Missing" because it only scans top-level `lib/features/*` folders

**Date:** 2026-11-06
**Project:** HBEC
**Environment:** Development working tree
**Severity:** Medium — no incorrect data shipped, but it actively misdirects engineering effort toward duplicating already-finished work
**Status:** Investigating

## Summary
`scripts/parity/web_flutter_parity.py`'s `extract_dir_names()` determines
which Flutter features exist by listing only the immediate child directories
of `STUDENT/mobile_flutter/lib/features/` (`{p.name for p in path.iterdir()
if p.is_dir()}`). A full, apparently-finished Settings feature already
exists on the Flutter side — 11 widget cards (profile, password, phone,
learning-profile, appearance, companion, study-plan, privacy, etc.) under
`STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/settings/`,
composed into `profile_page.dart` in the same order as web's
`SettingsPage.tsx` — but because it lives nested under the `auth` feature
rather than as its own top-level `features/settings/` folder, the scanner
never sees it. `web_flutter_parity_report.md` lists `settings` as a
"Missing" open gap, which it is not.

## Symptoms
- `planning/semantic/web_flutter_parity_report.md`'s open-gaps list names
  `settings` as unbuilt on Flutter.
- An agent (or engineer) following that report at face value, with no
  independent check of the actual Flutter source tree, would start building
  a second Settings feature from scratch and duplicate the 11 existing cards.
- Caught during a dry run of the new `migrate-web-to-flutter` skill
  (`.claude/skills/migrate-web-to-flutter/SKILL.md`), whose step 0 tells the
  agent to pick a target from this report's gap list — the dry run's agent
  independently `git status`'d the Flutter tree before committing to a
  target and found the Settings files sitting there, untracked.

## Environment Details
- **Server/Host:** Local workspace
- **Services Affected:** `scripts/parity/web_flutter_parity.py`,
  `STUDENT/mobile_flutter/planning/semantic/web_flutter_parity_report.md`,
  any workflow (including the new migrate-web-to-flutter skill) that trusts
  the report's gap list without cross-checking actual code state.
- **Related Components:**
  `STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/settings/`
  (untracked, uncommitted — appears to be finished work from a prior session
  that was never committed or logged).
- **Time First Observed:** 2026-11-06.

## Investigation Steps

### 1. Initial Diagnosis
A dry-run agent testing the new migration skill picked the Settings gap as a
candidate target, then checked the actual Flutter tree before starting work
(per the skill's own scoping step) and found a fully-built settings widget
set already present.

### 2. Root Cause Analysis
```bash
git status --porcelain STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/settings/ \
  STUDENT/mobile_flutter/lib/features/auth/presentation/pages/profile_page.dart
# ?? .../widgets/settings/   (untracked)
#  M .../pages/profile_page.dart

grep -n "features" scripts/parity/web_flutter_parity.py
# FLUTTER_FEATURES_DIR = FLUTTER_ROOT / "lib" / "features"
# def extract_dir_names(path): return {p.name for p in path.iterdir() if p.is_dir()}
```

### 3. Key Findings
- The scanner's feature detection is a single `iterdir()` over the top-level
  `lib/features/` directory — it has no concept of a feature implemented as
  a nested widget package under a sibling feature.
- The Settings work itself is real, substantial, and uncommitted; it predates
  this session and nothing records when or by whom it was built.
- The parity report and `parity_map.yaml` give no indication that `settings`
  should be looked for anywhere other than a top-level folder, so the false
  gap would persist across every re-run of the script until someone happens
  to notice by reading code directly.

## Root Cause
The parity script's feature-existence check is structural (top-level
directory name under `lib/features/`) rather than semantic (does a Flutter
implementation of this web feature exist anywhere in the tree). A feature
built inside another feature's package — a reasonable choice here, since
Settings is mostly account/profile widgets that already live under `auth` —
is invisible to it.

## Prevention / Rule
**Guardrail:** Before any workflow (human or agent) commits to building a
feature the parity report lists as "Missing," it must independently confirm
the gap against the live Flutter source tree (`git status` / grep for
related widget or page names), not take the generated report at face value.
This is now written into `.claude/skills/migrate-web-to-flutter/SKILL.md`
step 0 as a required cross-check, since that skill is the primary consumer
of this report's gap list going forward.

A structural fix to the scanner itself (e.g. also grepping for web feature
names anywhere under `lib/`, not just as top-level directories) would close
this more completely, but is not done here — this entry documents the
behavioral guardrail added to the consuming workflow, which is the fix that
was actually applied.

## Solution

### Immediate Fix
Added a required pre-target cross-check step to
`.claude/skills/migrate-web-to-flutter/SKILL.md` (step 0): before committing
to a parity-report gap as a migration target, check the actual Flutter
source tree for existing, possibly-uncommitted work under related paths.

### Long-term Fix
Either (a) commit and properly log the existing uncommitted Settings work
so the report can be regenerated accurately once it's recognized, or
(b) extend `extract_dir_names()`/the features section of
`web_flutter_parity.py` to search by content/name match rather than
top-level directory listing alone, so a nested implementation registers.
Neither has been done yet — this entry is filed at the point of discovery,
per this repo's logging rule, not after a fix landed.

## Prevention
- [x] Documentation to update — `migrate-web-to-flutter` skill now requires
      the cross-check.
- [ ] Code changes required — scanner still only sees top-level feature
      directories; not changed in this session.
- [ ] The uncommitted Settings feature should be reviewed, tested, and
      either committed or explained.

## Related Issues
- `HBEC-2026-11-05-flutter-parity-map-unmapped-routes.md` (a different,
  route-level instance of the parity map/report drifting from the live
  code — same family of risk, different mechanism: that one is about routes
  missing from `parity_map.yaml`, this one is about the Flutter-side feature
  scanner's blind spot for nested implementations).

## References
- `scripts/parity/web_flutter_parity.py`
- `scripts/parity/README.md`
- `.claude/skills/migrate-web-to-flutter/SKILL.md`

---

**Resolved By:** Pending (behavioral guardrail applied; scanner fix and
Settings-feature disposition still open)
**Time to Resolution:** Pending

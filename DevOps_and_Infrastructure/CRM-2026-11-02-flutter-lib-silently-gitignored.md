# Entire Flutter app source tree silently excluded from git since repo init

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The root `.gitignore`'s Python-packaging boilerplate section contains an
unqualified `lib/` rule. Because it has no leading `/`, it matches
`mobile_flutter/lib/` at any depth — meaning every Dart source file in the
Flutter mobile app's `lib/` directory has been silently excluded from git
since the repository's very first commit. No application source code for
the mobile app has ever actually reached the remote, despite multiple
feature phases (Phases 0–6: auth/shell, Stock, Sales/POS, Contacts,
Dashboard, Tasks, Expenses) being built, tested, and believed committed
across several sessions.

## Symptoms
- A large commit ("Add Flutter mobile CRM app", 173 files / 10,646
  insertions) appeared to succeed and was pushed, but contained no files
  under `mobile_flutter/lib/` — only scaffolding (`android/`, `ios/`,
  `pubspec.*`, config) and the `test/` directory.
- `git ls-files mobile_flutter/lib | wc -l` returned `0` even after that
  commit.
- A fresh clone of the repo would have a `mobile_flutter/test/` directory
  full of tests with no corresponding `lib/` source to run them against —
  `flutter test` would fail to even compile.
- Not noticed sooner because all verification (`flutter analyze`,
  `flutter test`, on-device checks) was run against the local working
  tree, which has always had the files on disk — git never needed to
  supply them locally, so the gap was invisible until this session's
  `git status` audit before committing Expenses/Tasks work.

## Environment Details
- **Server/Host:** N/A (local git repository)
- **Services Affected:** `mobile_flutter/` Flutter app — its entire source
  tree, repo-wide, not scoped to any one feature
- **Related Components:** root `.gitignore` (Python-packaging template
  section)
- **Time First Observed:** repo initial commit `9ffa096` (per `git blame`
  on the offending line), discovered 2026-11-02

## Investigation Steps

### 1. Initial Diagnosis
Running `git status` before committing the session's Tasks/Expenses work
showed only `mobile_flutter/test/features/expenses/` as untracked — no
`lib/` changes at all, despite substantial new/changed Dart source files
on disk (`core/money/currency.dart`, the entire `features/expenses/` and
`features/tasks/` trees, routing/`main.dart` edits).

### 2. Root Cause Analysis
```bash
git ls-files mobile_flutter/lib | wc -l        # 0
git check-ignore -v mobile_flutter/lib/features/sales/presentation/screens/sale_detail_screen.dart
# .gitignore:17:lib/	mobile_flutter/lib/features/sales/...
git blame -L 17,17 .gitignore
# 9ffa096 (winstonjthinker 2026-02-14) 17) lib/
```
Confirmed the exclusion predates every Flutter-related commit — it was
never a regression introduced by this session's work, but a latent defect
present from the repository's creation.

### 3. Key Findings
- The `lib/` rule sits in the "Distribution / packaging" block of a
  standard Python `.gitignore` template (alongside `build/`, `dist/`,
  `eggs/`, etc.) — meant to ignore a Python package's build-output `lib/`
  directory, not a Flutter project's primary source directory.
- This repo has no Python project with a root-level `lib/` build output;
  the rule was pure template boilerplate that happened to collide with an
  unrelated, legitimately-named directory added later (`mobile_flutter/lib/`).
- Same class of bug as the previously-documented `downloads/` gitignore
  quirk (see References) — an unqualified rule from the Python-packaging
  template section matching a same-named directory nested elsewhere in the
  repo. That one was left as-is (correctly excluding a large binary); this
  one was actively hiding source code and had to be fixed.

## Root Cause
`.gitignore` line 17 (`lib/`, no leading slash) matches a directory named
`lib` at any depth in the repo, not just at the root. `mobile_flutter/lib/`
— the Flutter app's entire source tree — matched this pattern and was
excluded from every `git add`/`git status` since the directory was first
created, with no error or warning at any point.

## Prevention / Rule
**Guardrail:** Any `.gitignore` rule copied from a language/framework
boilerplate template must be written root-anchored (`/lib/`, `/build/`,
etc.) unless it is deliberately intended to match at every depth — never
left as a bare directory name when the repo contains more than one
language/framework's source tree. Before adding a new top-level
project directory (a new mobile app, a new service), run
`git check-ignore -v <new-dir>` against a handful of its real source files
as a one-time sanity check before the first commit.

This closes the gap because the specific failure mode here was a
generic, unscoped name colliding with legitimate source paths — anchoring
the pattern to the repo root eliminates that collision class entirely
without weakening the original (Python) intent.

## Solution

### Immediate Fix
```diff
- lib/
+ /lib/
```
Verified no root-level `lib/` directory exists in this repo (so the
narrowed rule doesn't newly track something that should stay ignored), and
confirmed via `git check-ignore -v` that `mobile_flutter/lib/**/*.dart` is
no longer matched.

### Long-term Fix
Staged and committed the entire previously-untracked `mobile_flutter/lib/`
tree (152 files) in the same commit as the `.gitignore` fix, recovering
every phase of the Flutter app (through Phase 6: Tasks + Expenses) into
git for the first time.

## Prevention
- [x] Configuration changes needed — `.gitignore` line anchored to `/lib/`
- [ ] Monitoring/alerts to add — N/A (one-time repo-structure defect)
- [x] Documentation to update — this entry; cross-referenced from the
      Phase 6 Tasks/Expenses report
- [x] Code changes required — none; this was a tracking/config gap only,
      the application code itself was already correct and tested

## Related Issues
- Same root-cause *class* (unqualified Python-template rule colliding with
  a nested same-named path) as the `downloads/` gitignore quirk documented
  in `reports/CRM-2026-11-02-web-android-apk-download-on-login.md` — that
  one was intentionally left as-is since it correctly excludes a large
  binary; this one required a fix since it was hiding source code.

## References
- `reports/CRM-2026-11-02-flutter-phase6-tasks.md`
- `reports/CRM-2026-11-02-flutter-phase6-expenses.md`
- `/home/shadowe/Projects/crm/.gitignore`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** Same session as discovery

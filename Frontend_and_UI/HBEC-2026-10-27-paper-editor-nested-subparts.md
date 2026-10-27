# Paper Editor Couldn't Author Nested Sub-Parts Like a(i), a(ii)

**Date:** 2026-10-27
**Project:** HBEC
**Environment:** Admin frontend + backend (staging, pending production)
**Severity:** Medium (Admin UX / Hidden Backend Bug)
**Status:** Resolved

## Summary
Reported by Mutsa in the HBCA ProjectFlow channel (2026-10-15): "we also need
sub parts - like a(i) and a(ii) etc." The paper editor's Parts feature only
ever produced flat labels (a), (b), (c) — there was no way to nest a
roman-numeral sub-part under a lettered part.

## Symptoms
- Typing "a(i)" into a part's Label field in the admin's `PartsEditor` had
  every `(` and `)` character silently stripped on each keystroke, so it was
  impossible to even type a nested label.
- Had the frontend allowed it, the admin backend would have corrupted it on
  save anyway.

## Root Cause
Two independent bugs, both blocking the same thing:
1. `ADMIN/adminFrontend/.../components/PartsEditor.tsx` — the label input's
   `onChange` ran `event.target.value.replace(/[()\s]/g, '')`, stripping
   parentheses unconditionally.
2. `ADMIN/adminBackend/apps/exam_papers/parts.py` `_label()` ran
   `str(raw or "").strip().strip("()").strip()`. Python's `str.strip("()")`
   only peels matching characters off each *end* of the string; for a label
   ending in `)` like `"a(i)"`, it removed just that one trailing `)`,
   leaving the corrupted `"a(i"`. (A label like `"(a)"` was fine, since both
   ends are parens.)

Notably, nothing else in the stack needed to change: the data model
(`SubQuestion.label` is already a free string), the relabeling logic
(`utils/parts.ts` `relabel()` already only renumbers when every label is a
bare single letter, leaving mixed labels alone), and the student-facing
renderer (`STUDENT/Frontend/.../data/partLabel.ts`) already documented and
handled exactly this shape — its own comment names `"b(i)"` as an expected
label format. The capability was already built end-to-end except for these
two input-sanitization bugs.

## Solution
1. `parts.py` `_label()`: only unwrap a label that is *wholly* wrapped in one
   outer pair of parentheses (`startswith("(") and endswith(")")`), instead
   of blindly stripping `(`/`)` from both ends.
2. `PartsEditor.tsx`: the label input now only strips whitespace, not
   parentheses.
3. Added a dedicated "Add sub-part" button per part
   (`utils/parts.ts` `nextSubLabel`/`parentLetter`) that inserts the next
   roman-numeral sub-part (`a(i)`, then `a(ii)`, ...) right after that
   part's existing sub-parts — so an admin doesn't have to hand-type or
   track the roman numerals themselves.

Verified with a new backend test (`test_a_nested_sub_part_label_is_kept_whole`,
13/13 in `test_question_parts.py` passing against a throwaway local
Postgres), a new frontend test file (`PartsEditor.test.tsx`, 2/2 passing),
`tsc --noEmit`, `eslint`, and the full `exam-practice-admin` suite (17 files,
84 tests passing).

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (backend label normalizer + frontend input/UI)

---

**Resolved By:** Tinotenda Mupezeni (with Claude Code)
**Time to Resolution:** ~45 minutes

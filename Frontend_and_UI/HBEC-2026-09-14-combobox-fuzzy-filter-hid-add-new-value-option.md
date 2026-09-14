# ComboBox's Fuzzy Filter Could Hide the "Use/Add New Value" Option

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved — verified live on staging and production

## Summary
Reported while testing the Add Subject dialog on staging: typing a
genuinely new subject name (e.g. "reins") into the Subject combobox
sometimes didn't show the "Use '<value>'" option that lets an admin
create it — the field appeared "too tied up" filtering against existing
options instead of recognizing nothing matched. Root cause:
`ComboBox`/`MultiComboBox` (`ADMIN/adminFrontend/src/components/ui/combobox.tsx`)
relied on cmdk's default filter, which is fuzzy character-scatter
matching (every character of the search appears *somewhere*, in order,
not necessarily together) — a search term can score a non-zero match
against an unrelated option whose label happens to contain those letters
in that order, which suppresses `CommandEmpty` (the only place the
custom-value button renders) even though nothing genuinely matches.

## Symptoms
- Typing a new subject/family name into the Add Subject dialog's Subject
  field sometimes showed a filtered (but wrong) list of existing options
  instead of a "Use '<value>'" prompt, with no way to tell "this exists"
  from "nothing matches, keep typing to add it."

## Environment Details
- **Server/Host:** `ADMIN/adminFrontend`, `src/components/ui/combobox.tsx`
- **Services Affected:** every `ComboBox`/`MultiComboBox` usage with
  `allowCustom` — Add Subject's family picker is the one reported, but
  the same component is shared elsewhere in the admin UI.
- **Time First Observed:** 2026-09-14, reported live against staging

## Investigation Steps

### 1. Initial Diagnosis
Read `combobox.tsx`: `<Command shouldFilter={true}>` with no `filter`
prop — cmdk falls back to its bundled `command-score`-based fuzzy
matcher when none is supplied. `CommandEmpty` (which is the only place
`allowCustom`'s "Use/Add" button renders) only shows when the filtered
result set is empty.

### 2. Root Cause Analysis
Fuzzy character-scatter matching means a search like "reins" can score a
non-zero match against an option whose label contains those letters in
order across unrelated words (e.g. spanning two words with characters
in between) — a false positive from the admin's point of view, since
they're trying to type an exact new name, not browse loosely-related
existing ones. That non-empty result hides the create-new affordance
entirely.

### 3. Key Findings
- Both single-select `ComboBox` and `MultiComboBox` share this exact
  bug — same underlying `Command shouldFilter={true}` with no `filter`
  override in each.
- No test coverage existed for this component before this session,
  and no `ResizeObserver`/`scrollIntoView` polyfill existed in the test
  setup either — both needed adding just to render a Radix
  Popover/cmdk component under jsdom at all, likely why this class of
  bug had no regression test already.

## Root Cause
cmdk's default fuzzy filter scores partial, non-contiguous character
matches as non-empty results, which is the wrong matching semantics for
an "pick an existing value or type a new one" combobox — admins expect
exact substring matching, where "not a substring of anything" correctly
means "nothing found, offer to create it."

## Prevention / Rule
**Guardrail:** Any `Command`/cmdk usage backing an "existing value or
type a new one" pattern must pass an explicit `filter` function rather
than relying on the library default — fuzzy matching is right for a
command palette (forgiving of typos/partial memory) and wrong for an
identity picker (where "no exact match" is itself meaningful
information the UI must surface). A quick review check: any
`allowCustom` combobox usage without a `filter` prop is this bug
waiting to happen.

This closes the gap because the actual failure mode was choosing the
wrong filter semantics for the use case, not a logic bug in how the
empty state renders.

## Solution

### Immediate Fix
Added a shared `substringFilter` (`(itemValue, search) => itemValue
.toLowerCase().includes(search.toLowerCase()) ? 1 : 0`) and passed it as
`filter={substringFilter}` to both `ComboBox`'s and `MultiComboBox`'s
`Command`. A value that isn't a real substring of any option now
correctly falls through to `CommandEmpty`'s "Use/Add" button.

4 new tests in `src/components/ui/combobox.test.tsx` cover: a
non-substring search shows the custom-value option and hides unrelated
results, a real substring still matches, matching is case-insensitive,
and `MultiComboBox`'s "Add" variant behaves the same way. Also added a
`ResizeObserver` stub and a `scrollIntoView` no-op to
`src/test/setup.ts` — jsdom implements neither, and cmdk/Radix Popover
call both on mount/nav, so no test could render this component at all
without them. Full suite (112 tests, up from 108) passes.

Verified live: staging's built bundle contains `substringFilter`;
deployed to staging then production the same session
(`sha-8ce2863`), full host health sweep clean on both.

### Long-term Fix
None needed beyond the guardrail above.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [ ] Documentation to update — none yet
- [x] Code changes required — done, plus 4 new regression tests and two
      jsdom test-environment polyfills

## Related Issues
- Same feature area as
  `HBEC-2026-09-14-add-subject-false-familyid-required-drf-auto-validator.md`
  (the Add Subject dialog this component backs), found while verifying
  that fix's UI live on staging.

## References
- `ADMIN/adminFrontend/src/components/ui/combobox.tsx` — `ComboBox`,
  `MultiComboBox`, `substringFilter`
- `ADMIN/adminFrontend/src/components/ui/combobox.test.tsx` (new)
- `ADMIN/adminFrontend/src/test/setup.ts`
- `ADMIN/adminFrontend/src/features/curriculum/components/SubjectForm.tsx`
  — the reported caller (`allowCustom` Subject combobox)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery — verified live on
staging, then promoted to and verified live on production

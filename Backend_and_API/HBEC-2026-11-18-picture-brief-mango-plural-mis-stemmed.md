# A mis-stemmed plural let a picture show the correct MCQ answer

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in `/code-review` of PR #158, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`picture_briefs._content_words()` plural-folds words so a picture brief's
scene/must_show text can be compared against an MCQ option's words
(`shows_a_choice`, which refuses to draw a picture that depicts the correct
answer — "the harness is never told which option is right, and a picture of
one misleads"). The stemmer mis-folded "-oes" plurals like "mangoes", so a
brief naming "mangoes" was never recognized as matching an option reading
"mango", and the picture-reveals-the-answer check could miss a real match.

## Symptoms
- No live incident; found by code review reading `_content_words`' stemming
  branches against the word "mangoes".
- `_content_words("mangoes")` returned `{"mangoe"}` instead of `{"mango"}`.

## Environment Details
- **Server/Host:** n/a (unit-level, harness backend)
- **Services Affected:** AGENTIC_HARNESS exam_practice picture generation
- **Related Components:** `app/shared/picture_briefs.py`
- **Time First Observed:** 2026-11-18, code review

## Investigation Steps

### 1. Initial Diagnosis
The review flagged the elif chain's `word.endswith("es") and word[-3] in "sxz"`
check: for "mangoes" (`m-a-n-g-o-e-s`), `word[-3]` is `'o'`, not in `"sxz"`, so
the branch is skipped and the generic `word[:-1]` (strip one "s") branch runs
instead, producing "mangoe".

### 2. Root Cause Analysis
English "-o" nouns pluralize two different ways with no way to tell them apart
from the letters alone: "mango"/"mangoes" and "tomato"/"tomatoes" add "-oes",
while "shoe"/"shoes" (already ending in "oe") just adds "-s". A single
suffix-stripping rule cannot get both right; it is a lexical fact, not a
spelling rule.

```bash
cd AGENTIC_HARNESS && .venv/bin/python -c "
from app.shared.picture_briefs import _content_words
print(_content_words('mangoes'))   # {'mangoe'} before the fix
print(_content_words('shoes'))     # {'shoe'} - already correct
"
```

### 3. Key Findings
- Only the small, fixed `PICTURE_ITEMS` catalog (`STUDENT/Frontend/src/shared/question-diagrams/spec.ts`) matters here, and only `mango`/`tomato` among it end in a consonant + "o"; `shoe` is the only item already ending in "oe" and was unaffected.
- `shows_a_choice` already has parametrized test coverage (`test_which_choice_a_brief_would_draw`), just with no "-oes" case.

## Root Cause
`_content_words`'s plural stemmer had no rule for "-oes" plurals, so
"mangoes" folded to the non-word "mangoe" instead of "mango", and would never
match an option's "mango".

## Prevention / Rule
**Guardrail:** an explicit, reviewed exceptions dict (`_OES_PLURALS`) checked
before the generic suffix rules, covering the known English "-oes" nouns
(mango, tomato, potato, hero, echo, volcano, buffalo, torpedo, embargo,
domino) — never a broader heuristic, since the "shoe"/"mango" ambiguity is not
resolvable from spelling alone and a wrong heuristic would just move the bug.

Adding a word to `PICTURE_ITEMS` that pluralizes with "-oes" must add it to
`_OES_PLURALS` too; `test_which_choice_a_brief_would_draw`'s parametrize list
is the place a reviewer checks for new cases.

## Solution

### Immediate Fix
Added `_OES_PLURALS` (mango, tomato, potato, hero, echo, volcano, buffalo,
torpedo, embargo, domino → their singulars), checked first in
`_content_words`'s suffix chain.

### Long-term Fix
None needed beyond the dict; the function's job is narrow and bounded by the
picture-item catalog.

## Prevention
- [x] Code changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Found alongside 5 other picture-engine bugs in the same `/code-review` of
  PR #158 (rate-limit double-charge, fence-regex mismatch, missing
  `DiagramKind`, wrong `Cache-Control`, outage-vs-refusal conflation) — see
  the sibling entries dated the same day.

## References
- `AGENTIC_HARNESS/app/shared/picture_briefs.py`
- `AGENTIC_HARNESS/tests/shared/test_picture_briefs.py`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session

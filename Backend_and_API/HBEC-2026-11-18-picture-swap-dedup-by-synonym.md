# Picture-swap repair wrongly refused when two emoji share a matched word

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in code review of PR #149, `experimental` branch, before merge to `master`)
**Severity:** Medium
**Status:** Resolved

## Summary
`judge_picture()` in the exam-practice picture-generation/repair pipeline decides
whether a question's picture/word mismatch can be auto-repaired by swapping the
shown emoji for the one the words actually name. Its de-duplication of "other
named things" grouped emoji by each one's *first* listed synonym rather than by
which word actually matched, so two emoji matched by the same word in the
question text (e.g. a hen and a cockerel both matching "chicken") were counted
as two different candidate swaps. The repair was then refused as an
unrepairable `mismatch` even though one correct, unambiguous swap existed.

## Symptoms
- A question whose picture/word mismatch should be auto-repaired (one emoji
  shown, exactly one thing actually named by the text) is instead dropped at
  generation time, or left unrepairable by the deploy-time backfill
  (`picture_repair.py`), with no error surfaced to anyone.

## Environment Details
- **Server/Host:** Agentic Harness (exam_practice pillar)
- **Services Affected:** AI paper generation (`generation/pictures.py`),
  stored-paper picture repair (`picture_repair.py`) — both call the shared
  `judge_picture()` rule.
- **Related Components:** `PICTURE_NAMES` synonym table in the same module.
- **Time First Observed:** Found during code review, not yet reported live.

## Investigation Steps

### 1. Initial Diagnosis
Code review of PR #149 traced `judge_picture()`'s branch logic for the `swap`
verdict and found the dedup step computed a *set of chosen representative
synonyms*, not a set of equivalence classes.

### 2. Root Cause Analysis
```python
others = {n for n in named if not any(_same_thing(n, e) for e in shown)}
other_things = {PICTURE_NAMES[n][0] for n in others}   # <- bug
if len(shown) == 1 and len(other_things) == 1:
    ...
```
`PICTURE_NAMES[n][0]` is just the first string in that emoji's own synonym
list. Two emoji whose synonym lists both contain the matched word, but list it
in a different position (or list different first synonyms), produce two
different "representative" strings even though `_same_thing()` — the
function that actually decides "same picture, different emoji" everywhere
else in this module — would say they're the same thing.

### 3. Key Findings
- The bug only manifests when ≥2 emoji are matched by a shared word in the
  question text, which is a realistic and common case for options/text
  containing synonymous nouns ("chicken" matching both a hen emoji and a
  cockerel emoji).
- No test in `test_picture_briefs.py`-equivalent coverage exercised two named
  emoji sharing a matched word, so this shipped silently.

## Root Cause
De-duplication used each candidate's first-synonym string as a proxy key for
"is this the same thing as another candidate," instead of using the
equivalence relation (`_same_thing()`) the rest of the module already defines
and relies on for exactly this purpose.

## Prevention / Rule
**Guardrail:** Any code path in `pictures.py` that needs to count distinct
"things" among a set of candidates must group by `_same_thing()` equivalence,
never by a representative string pulled from one side's synonym list. Add a
unit test asserting `judge_picture()` returns `swap` (not `mismatch`) when two
named emoji share a matched synonym word, so a regression here fails CI.

This closes the gap because the root cause was specifically a mismatch
between the equivalence relation the module already trusts and an ad hoc
string-identity shortcut taken only in this one branch.

## Solution

### Immediate Fix
Replaced the set-comprehension-by-first-synonym with an explicit grouping
loop that tests membership via `_same_thing()`:

```python
other_things: list[str] = []
for n in others:
    if not any(_same_thing(n, rep) for rep in other_things):
        other_things.append(n)
if len(shown) == 1 and len(other_things) == 1:
    ...
```

### Long-term Fix
Add the regression test described above (two emoji sharing a matched
synonym word) to this module's test suite.

## Prevention
- [x] Code changes required (done — see Solution)
- [ ] Add the regression test named above
- [ ] Documentation to update
- [ ] Monitoring/alerts to add

## Related Issues
- Found alongside two other PR #149 review findings: an empty-`options`
  bounds-check gap in `STUDENT/hbec_backend/apps/internal/views.py`, and a
  parental-gate route misconfiguration in `STUDENT/Frontend/src/App.tsx`.
- `picture_repair.py` implements a second, differently-strategized MCQ-key
  safety check alongside this same module's generation-time check — flagged
  separately as an architectural inconsistency, not fixed here (left for a
  PR comment, not a code change).

## References
- `AGENTIC_HARNESS/app/exam_practice/services/generation/pictures.py`
- HBEC `experimental` branch, commit `5532043e3`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session (pre-merge)

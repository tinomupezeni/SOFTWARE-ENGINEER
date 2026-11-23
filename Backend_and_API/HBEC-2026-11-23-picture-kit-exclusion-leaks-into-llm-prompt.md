# Picture-kit catalogue exclusion was unenforced and leaked into the generation prompt

**Date:** 2026-11-23
**Project:** HBEC
**Environment:** Development (caught during PR review, PR #173, before merge)
**Severity:** High
**Status:** Resolved

## Summary
PR #173 adds `girl`/`boy`/`child` to the whiteboard's counting-picture kit, deliberately excluded from the question-generation harness's emoji *catalogue* (`PICTURE_NAMES`) because those words are used in ordinary question text ("Tendai is a **boy** with 4 apples") and would otherwise be misidentified as a picture-swap mismatch. Two problems were found with how that exclusion was actually implemented: (1) nothing enforced it — a future "sync catalogue with kit" refactor could silently reintroduce the three names with no test failing; and (2) it was already leaking — `paper_generation_system_prompt()` built its "item is one of: ..." list from the full `PICTURE_ITEMS` tuple (which does include girl/boy/child), not from the excluded `PICTURE_NAMES` set, so the question-generation LLM was already being told it could pick those items.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review, not in production. Had it merged unreviewed, a generated exam question could pick `item: "boy"` or `item: "girl"`, and the picture-swap step would then consume the word "boy"/"girl" out of the question's own sentence (e.g. silently breaking "Tendai is a boy with 4 apples" by treating "boy" as the picture placeholder), defeating the entire reason the exclusion existed.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `AGENTIC_HARNESS` (question generation), both frontend picture-kit copies.
- **Related Components:** `AGENTIC_HARNESS/app/exam_practice/services/generation/pictures.py` (`PICTURE_NAMES`), `AGENTIC_HARNESS/app/exam_practice/prompts.py` (`paper_generation_system_prompt()`), `AGENTIC_HARNESS/tests/exam_practice/test_picture_diagrams.py`.
- **Time First Observed:** 2026-11-23, during review of PR #173.

## Investigation Steps

### 1. Initial Diagnosis
The PR's exclusion claim ("girl/boy/child go in the drawn kit only, deliberately not added to the generator's emoji catalogue") was verified against the actual code rather than taken at face value: confirmed `PICTURE_NAMES` correctly excludes the three names, then traced every consumer of the broader `PICTURE_ITEMS` tuple to see whether any of them re-leaked the excluded names back in.

### 2. Root Cause Analysis
```python
# prompts.py, before fix
def paper_generation_system_prompt():
    items = ", ".join(name for name, _ in PICTURE_ITEMS)  # includes girl/boy/child
    return f"... item is one of: {items} ..."
```
`PICTURE_ITEMS` is the full asset tuple (kit + catalogue); `PICTURE_NAMES` is the catalogue-only subset the exclusion is supposed to produce. The prompt builder was written against the wrong one of the two, predating this PR but only becoming a live risk once this PR added names to `PICTURE_ITEMS` whose exclusion from generation actually mattered semantically.

Separately, `grep -rn "PICTURE_NAMES\|PICTURE_ITEMS" AGENTIC_HARNESS/tests/` showed no test asserted that `girl`/`boy`/`child` (or any kit-only item) must stay out of `PICTURE_NAMES` — the exclusion held only because nobody had refactored the catalogue construction since, not because anything would catch a regression.

### 3. Key Findings
- `ADMIN`'s `PictureForm.tsx` also reads `PICTURE_ITEMS` for a manual admin dropdown — confirmed this is fine, since a human administrator picks the item there, not an LLM; the leak was specific to the generation prompt.
- The wiring claim in the PR body (13 new items registered in every validator/harness/contract location) was independently verified true via whole-repo grep across all five registration points.

## Root Cause
Two distinct gaps compounded: an intentional exclusion (`PICTURE_NAMES` vs. `PICTURE_ITEMS`) was never backed by a test, so it was an accidental invariant rather than a guarded one; and a second, pre-existing consumer (`paper_generation_system_prompt()`) had been built against the wrong source tuple before this PR, so the moment this PR added semantically-loaded words to the kit, the prompt builder started handing the LLM exactly the names the feature was designed to keep away from it.

## Prevention / Rule
**Guardrail:** any catalogue/kit split with an intentional exclusion must have a dedicated test asserting the exclusion (`test_kit_only_items_never_enter_the_generator_catalogue` — added as part of this fix), and every consumer of the broader asset list must be audited at the time the exclusion is introduced to confirm it sources from the narrowed set where semantic correctness (not just existence) depends on it. This is the same "authorization/business logic duplicated instead of centralized" class named in `7. Software Security Engineering.md`'s 2026-11-23 update, applied to a content-safety boundary instead of an authz boundary: two code paths (prompt builder, admin dropdown) both read from `PICTURE_ITEMS`, and only one of them needed the narrower set — nothing forced that distinction to be checked when it started to matter.

## Solution

### Immediate Fix
1. Added `test_kit_only_items_never_enter_the_generator_catalogue` to `AGENTIC_HARNESS/tests/exam_practice/test_picture_diagrams.py`, asserting `girl`/`boy`/`child` (and any other kit-only item) are absent from `PICTURE_NAMES`.
2. Fixed `paper_generation_system_prompt()` to source its "item is one of: ..." list from `PICTURE_NAMES` instead of `PICTURE_ITEMS`; verified the prompt output still starts "mango, apple, ..." (matching the existing prompt test) and now excludes girl/boy/child.
3. Confirmed `PictureForm.tsx`'s use of `PICTURE_ITEMS` is intentional and correct (human-operated dropdown, not LLM input) and left unchanged.

```bash
git add -A && git commit -m "fix: generation prompt must source items from PICTURE_NAMES, not PICTURE_ITEMS"
git push origin HEAD:feat/picture-kit-heritage
```

### Long-term Fix
When any future kit/catalogue split is introduced, require the same pairing (exclusion test + consumer audit) as part of that PR's own acceptance criteria, rather than relying on a reviewer to notice it each time.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [x] Test added (`test_kit_only_items_never_enter_the_generator_catalogue`).
- [x] Code changes required (prompt builder source fixed).
- [ ] Documentation to update: consider a short comment at `PICTURE_ITEMS`'s definition pointing to `PICTURE_NAMES` and the test, so a future reader doesn't reintroduce the same confusion.

## Related Issues
- An architecture/scope-level PR comment was also posted (batching 13 unrelated items plus the first skin-tone figures in one PR; whether skin-tone variants should extend to other existing catalogue person-figures) — left for the owner to decide, not fixed here.

## References
- PR: https://github.com/Rest-creator/HBEC/pull/173
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/7. Software Security Engineering.md` ("Authorization Logic Must Be Singular" — same duplicated-predicate shape)

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session)
**Time to Resolution:** Caught and fixed before merge, same review session

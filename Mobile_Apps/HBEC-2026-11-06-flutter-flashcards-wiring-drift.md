# Flutter's Flashcards/Concept Check buttons opened a component web had already abandoned

**Date:** 2026-11-06
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Development (found while porting three modals under a parity pass)
**Severity:** Medium
**Status:** Resolved

## Summary
On HBEC's Flutter student app, `subject_content_page.dart`'s "Flashcards" and
"Concept Check" buttons opened `FlashcardsModal` (a simple flip-card
write-from-memory widget), recorded in `scripts/parity/screen_map.yaml` as
"wired into subject_content_page.dart, used for real." On the actual web app,
neither button opens that component any more — `FlashcardsModal.tsx` is
exported and still sits in the tree, but nothing imports it except its own
file and the barrel `index.ts`. Web's real "Flashcards" button opens
`RecallFlashcardsModal` (read → hide → recall-from-memory → AI-judged
compare), and "Concept Check" opens `ConceptRecallModal` (cloze-style
reconstruction from the student's own notes) — two different exercises with
different pedagogy, confirmed by `TopicContent.tsx`'s own doc comment:
"This used to open FlashcardsModal with a different heading, so the platform
offered one exercise under two names."

So the Flutter app's two most-used revision exercises did not match what
students on web actually get, and the screen map — the tool meant to track
exactly this — had marked the gap as "built" and closed, because it only
checks whether a named Flutter file exists and is referenced from the page,
not which web component its *current* behavior actually derives from.

## Symptoms
- No user-reported symptom yet (caught during a scheduled migration pass,
  not a bug report) — the risk is silent divergence: students on Flutter
  practicing with flip-card self-rated recall instead of the AI-judged
  read/recall/compare loop and the structural cloze-reconstruction exercise
  web ships.
- `scripts/parity/screen_map.yaml` reported `topic-revision-flashcardsmodal`
  as `built`/wired, masking the gap from the parity audit that exists
  specifically to catch this class of thing.

## Environment Details
- **Server/Host:** N/A (client-side divergence, Flutter vs. web)
- **Services Affected:** `STUDENT/mobile_flutter` topic-revision feature;
  `STUDENT/Frontend` topic-revision feature (as the source of truth)
- **Related Components:**
  `STUDENT/mobile_flutter/lib/features/revision/presentation/pages/subject_content_page.dart`,
  `.../widgets/flashcards_modal.dart`,
  `STUDENT/Frontend/src/features/topic-revision/components/{FlashcardsModal,RecallFlashcardsModal,ConceptRecallModal}.tsx`,
  `STUDENT/Frontend/src/features/topic-revision/pages/SubjectContentPage.tsx`
- **Time First Observed:** 2026-11-06, while reading `SubjectContentPage.tsx`
  in full (per the `migrate-web-to-flutter` skill's step 1) to port
  `ConceptRecallModal`, `RecallFlashcardsModal` and `VideoModal`.

## Investigation Steps

### 1. Initial Diagnosis
Reading `SubjectContentPage.tsx` to understand what the three target modals
needed, I found its "Flashcards" button wired to `<RecallFlashcardsModal>`
and "Concept Check" to `<ConceptRecallModal>` — not `<FlashcardsModal>` at
all, despite Flutter's screen map describing `topic-revision-flashcardsmodal`
(the Flutter port of `FlashcardsModal.tsx`) as the real, wired equivalent of
both those buttons.

### 2. Root Cause Analysis
```bash
# Is FlashcardsModal.tsx actually imported/used anywhere besides itself?
grep -rn "\bFlashcardsModal\b" --include="*.tsx" --include="*.ts" . | grep -v "RecallFlashcardsModal"
# -> only its own definition, the barrel index.ts export, and a comment in
#    SubjectContentPage.tsx explaining it was replaced.
```
Confirmed: `FlashcardsModal.tsx` is dead code on web's actual page. A past
Flutter migration pass ported it anyway — plausibly because it is the
better-known/more obviously-named component, or because it was still
exported from the components barrel with no runtime signal that it was
unused — and then wired it to both revision buttons since the simpler
flip-card UI served double duty "well enough" to pass by eye.

### 3. Key Findings
- `scripts/parity/screen_map.py`'s component pairing is name/path-based, not
  behavior-based: it correctly found `flashcards_modal.dart` and matched it
  to `FlashcardsModal.tsx`, and correctly reported that pairing as `built`
  because the Flutter file *is* wired into the page — just to the wrong
  trigger relative to what the two buttons actually do on web.
- This is a second instance of the class of bug already logged in
  `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md`: the
  parity tooling verifies structural facts (a file exists, a file is
  imported) and cannot verify that the imported file's *behavior* still
  matches its named web counterpart once web has moved on.

## Root Cause
Flutter's topic-revision screen was ported against an earlier snapshot of
web's `SubjectContentPage.tsx`, when `FlashcardsModal` may plausibly have
been the live component for both buttons. Web later split the single
flashcard flip-card exercise into two more pedagogically distinct ones
(`RecallFlashcardsModal` for active recall, `ConceptRecallModal` for
structural reconstruction) and repointed its buttons, but left the old
component in the tree, unimported except by its own file and the barrel
export. Nothing on the Flutter side re-checked that the web buttons it was
mirroring still pointed where they used to — the screen map only confirms a
named pairing is wired, not that the pairing is current.

## Prevention / Rule
**Guardrail:** when a parity audit (screen_map.py or an equivalent) reports a
modal as `built`, the migration workflow must independently verify which
*trigger element* on the live web page currently renders that modal (grep the
JSX for the actual `<ComponentName` usage on the page, not just that the
component file exists and is exported) before trusting the audit's status for
that node. This was already made explicit for the nested-feature-folder case
and is now the same rule for "right folder, wrong/stale component."

This closes the gap because it forces a behavioral check (what does the
button actually open *today*) rather than a structural one (does a file with
a plausible name exist and get referenced somewhere), which is exactly where
this drift hid for an unknown number of migration passes.

## Solution

### Immediate Fix
Rewired `subject_content_page.dart`:
- "Flashcards" button now opens the newly-ported `RecallFlashcardsModal`
  (read → hide & recall → AI-judged compare).
- "Concept Check" button now opens the newly-ported `ConceptRecallModal`
  (cloze reconstruction).
- `flashcards_modal.dart` (the Flutter port of web's dead `FlashcardsModal.tsx`)
  is left in the tree, unwired — matching web's own posture of keeping it
  exported but unused — rather than deleted, to avoid an unrelated-scope
  deletion in a migration pass; `screen_map.yaml`'s note for that node now
  says so explicitly.

### Long-term Fix
No code change beyond the above; the process guardrail above is the
long-term fix. Consider (not done here, out of scope for this pass):
teaching `screen_map.py` to also record, per modal node, the JSX trigger
element string it was last confirmed open from on web, so a future
re-run can flag when that string no longer appears in the page source
even if the component file itself is unchanged.

## Prevention
- [x] Documentation updated (`scripts/parity/screen_map.yaml` notes for all
      four `topic-revision-*modal` nodes;
      `STUDENT/mobile_flutter/planning/phases/flutter_migration_phases.md`;
      `STUDENT/mobile_flutter/planning/long_term_plan.md`)
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none (client-side parity, not runtime)
- [ ] Code changes required — none beyond the rewiring above

## Related Issues
- `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md` — same
  root class (parity tooling verifies structure, not behavior), different
  manifestation.

## References
- `STUDENT/Frontend/src/features/topic-revision/pages/SubjectContentPage.tsx`
- `STUDENT/Frontend/src/features/topic-revision/components/TopicContent.tsx`
  (doc comment explaining the web-side split)
- `STUDENT/mobile_flutter/lib/features/revision/presentation/pages/subject_content_page.dart`

---

**Resolved By:** Claude Sonnet 5 (migrate-web-to-flutter pass)
**Time to Resolution:** Same session as discovery

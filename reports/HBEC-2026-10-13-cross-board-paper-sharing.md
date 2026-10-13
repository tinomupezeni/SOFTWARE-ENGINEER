# Cross-board paper sharing (papers only): admin-tagged, always origin-labeled, marking untouched

**Date:** 2026-10-13
**Project:** HBEC Platform
**Type:** New feature
**Status:** Completed (deployed to idle color, verified; cutover pending)

## Summary
Implemented the "Paper sharing" item from the ProjectFlow backlog (HIGH
priority: "Allow content to be share for Zimsec and Cambridge"), scoped
deliberately to papers first, topics deferred. An admin can tag an
individual exam paper `shared_across_boards`; once tagged, it becomes
visible to students on every exam board, always labeled with its real
origin board. Marking stays completely bound to the paper's own exam
board, confirmed unaffected before writing any code.

## Context / Trigger
Follow-on from the "pull tasks for HBEC" session work — the user picked
this backlog item up directly and specified the design: cross-board
visibility, explicit per-paper tagging, papers before topics. One design
question was raised and resolved before implementation: does marking
adapt to the viewing student's board, or stay bound to the paper's own?
Confirmed: stays bound, tagging is purely a visibility signal.

## Scope
Included: `ExamPaper`/`Paper` model field, both serializers, both
downstream replication payloads, the student-backend visibility query
(including the subject-band cross-board gap found along the way), the
admin frontend toggle + badge.

Excluded, deliberately: topics (explicitly "papers first" in the
request); any change to marking conventions, which stays paper-board-
bound by design; any admin UI for *finding* shared papers across boards
beyond the existing papers list (not asked for).

## Method
Checked the marking code path first, before writing anything — confirmed
`board_label(paper.exam_board_id)` in `AGENTIC_HARNESS/app/exam_practice/
router.py` already keys marking to the paper's own board, never the
student's, so this was purely a visibility feature with zero marking
risk. Then read the actual student-backend query that currently restricts
a student to their own board's papers, rather than assuming a single
filter line would be sufficient — this surfaced the real gate (see
Decisions & Findings).

## Decisions & Findings

### The real gate wasn't the exam_board filter — it was the subject widening
`STUDENT/hbec_backend/apps/practice/views.py`'s paper-band query doesn't
filter on `exam_board` directly as the first gate; it widens `subject` via
`subjects_in_paper_band()`, which is **hard-scoped to the learner's own
`exam_board_id`** (`apps/curriculum/bands.py`). `Subject` is a per-board
row — ZIMSEC Mathematics and Cambridge Mathematics are different `Subject`
objects — so a shared paper's own `subject` FK, pointing at a Subject row
on a *different* board, was never reachable through that widening no
matter what the later `exam_board` filter said. Opening only the later
filter (the naive first attempt) left the feature looking implemented but
non-functional — caught by the first real regression test, not by
inspection.

Fixed by matching cross-board subjects **separately**, on subject code
(the same principle `subjects_in_paper_band()` itself already uses — code,
never phase) within the same paper band, across every board, gated so it
only ever surfaces a subject when a `shared_across_boards=True` paper
actually exists there — this widening never grants access on its own.

### A defaulted boolean on a write serializer used for PATCH is a real risk
`ExamPaperWriteSerializer` already serves both full creates and partial
updates (`PaperDetailView.update()` passes `partial=partial` through).
Adding `sharedAcrossBoards = BooleanField(..., default=False)` to it looks
innocuous but, if DRF applied the default whenever the field is absent
regardless of partiality, every unrelated PATCH (retitling a paper, say)
would have silently reset sharing back to `False`. Verified DRF's actual
behavior instead of assuming: `Field.validate_empty_values` raises
`SkipField()` when the value is `empty` AND the serializer is partial,
never reaching `get_default()` — confirmed correct, then pinned with a
dedicated regression test rather than leaving it to (un-asserted) trust.

### Every paper, not only shared ones, needed to carry its origin tag
The student API had no `examBoardName`/`examBoardCode` field on the paper
list payload at all before this — the sharing feature's own promise
("always shown tagged with its real origin board") would have been
unverifiable without adding it. Added it to every returned paper (not
conditionally), plus `isSharedFromOtherBoard`, mirroring the exact
transparency pattern already established for grade-crossing papers
(`isSharedFromBand`) rather than inventing a new convention.

## Changes Made
- `ADMIN/adminBackend/apps/exam_papers/models.py` — `shared_across_boards`
  field + migration 0012.
- `ADMIN/adminBackend/apps/exam_papers/serializers.py` — exposed read/write
  as `sharedAcrossBoards`.
- `ADMIN/adminBackend/apps/exam_papers/views.py`,
  `ADMIN/adminBackend/apps/replication/signals.py` — both downstream
  payload builders now carry the flag.
- `ADMIN/adminFrontend/src/features/exam-practice-admin/` — toggle on
  `PaperDetailPage`, badge on `PaperTable`, types updated.
- `STUDENT/hbec_backend/apps/practice/models.py` — matching field +
  migration 0021 (bundled with an unrelated, already-pending index rename
  Django had queued — metadata-only, non-destructive, confirmed safe to
  bundle rather than fight the migration generator over).
- `STUDENT/hbec_backend/apps/practice/views.py` — the cross-board subject
  widening fix (the real gate), plus origin-board tagging on every
  returned paper.
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py` — syncs the
  field from the replication payload.
- Harness: no changes — confirmed unnecessary (marking already
  paper-board-bound; its replication handler reads a plain dict, so an
  extra payload key is harmless).

## Verification
- Admin backend: 413 (exam_papers) + 78 (replication) = tests passed,
  including a dedicated DRF partial-update-safety test and a transactional
  test proving the flag reaches both downstream payloads for real (not
  just that the code looks like it should).
- Student backend: 192 tests passed (practice + replication), including a
  test proving a shared paper **does** cross boards and carries its real
  tag, and a second proving an **unshared** paper does not — both
  directions tested, not just the happy path.
- Admin frontend: 58 tests passed; `tsc -b --noEmit` clean.
- `ruff check` clean on every changed Python file (two pre-existing,
  unrelated lint findings in `STUDENT/hbec_backend/apps/practice/views.py`
  confirmed present before this change too, via `git stash` comparison —
  left untouched, out of scope).
- Deployed to the idle (`green`) blue-green color on `hbca-vps`; migrations
  confirmed applied (`showmigrations` on both backends); revisions, signed
  links, and secret drift (12 groups) all verified. A live, read-only
  check against real replicated production data on green confirmed the
  new fields are present and correctly defaulting to `false` for every
  existing paper — nothing was created or mutated to prove this. Blue
  (100% of real traffic) was untouched throughout.

## Follow-ups / Deferred
- **Cutover not performed** — green carries this feature, the labs stack,
  the paper-generation token-budget fix, and the notifications Redis-drift
  prevention work, all verified but not yet live. A separate, deliberate
  step.
- **Topics** — explicitly deferred per the original request ("we start
  with papers").
- **No admin UI for cross-board discovery** — an admin can tag a paper
  shared from its own detail page, but there's no dedicated view for
  "papers I've shared across boards" or "papers shared *into* this
  board from elsewhere." Not asked for; worth considering if sharing sees
  real use.

## References
- `AGENTIC_HARNESS/app/exam_practice/router.py` (`board_label`, confirms
  marking is already paper-board-bound)
- `STUDENT/hbec_backend/apps/curriculum/bands.py`
  (`subjects_in_paper_band`, the real gate found and fixed)
- HBEC PR #99

---

**Completed By:** Tinotenda Mupezeni
**Duration:** ~1.5 hours

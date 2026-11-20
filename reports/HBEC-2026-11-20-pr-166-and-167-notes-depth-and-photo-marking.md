# Engineering Report: HBEC Pull Requests #166 & #167 Review & Merge

**Date:** 2026-11-20  
**Repository:** `Rest-creator/HBEC`  
**PRs Merged:** #166, #167 (commit `b66d1ba0d`)

---

## 1. Context & Trigger
Following the resolution and merge of PR #160 (exam paper figures backfill and indexing), the next two open feature pull requests submitted by `winstonjthinker` were scheduled for review and promotion:
- **PR #166**: Notes depth by subject, diagrams & callouts in revision notes, toned-down Socratic questioning.
- **PR #167**: Photographed answers accurate marking with double-reading, EXIF rotation handling, and contrast enhancement.

---

## 2. Scope & Technical Overview

### PR #166: Notes Depth by Subject (`feat/notes-depth-by-subject`)
- **Subject Depth Profiles (`AGENTIC_HARNESS/app/revision/subject_depth.py`, `reader.py`)**:
  - Replaced uniform notes with subject family profiles (`narrative` for History/Heritage [2x budget, timeline tables, causes/context]; `quantitative` for Maths/Physics/Chemistry [1.6x budget, display formulas, worked use, formula summaries]; `general` [1.5x]).
- **Visuals & Diagrams**:
  - Requires at least 1 reasoning diagram per note (`flowchart TD`, plot, or fbd for physical forces).
  - Fixed Mermaid SVG label clipping on small viewport widths (320px/390px) by preventing label truncation.
- **Coloured Callouts**:
  - Lifted exam marks (`★` violet), insights (`💡` sky blue), and common mistakes (`⚠` amber) into styled callout components.
- **Socratic Frequency**:
  - Balanced questioning loop in `socratic.py`—teaches if previous two replies were questions, avoiding question fatigue.

### PR #167: Photographed Answers Marking (`feat/photo-answer-marking`)
- **Handwriting Image Preparation (`AGENTIC_HARNESS/app/exam_practice/services/image_service.py`)**:
  - Straightens phone photos using EXIF orientation tags.
  - Enhances contrast for faint pencil answers.
  - Resizes to 2000px max bounds.
- **Double-Reading & Uncertainty Flagging**:
  - If confidence < 0.75 or text contains `[illegible]`, executes a second independent OCR reading.
  - If readings disagree, flags `uncertain: True` and prompts marker to read photo directly.
- **Marking Routing (`router.py`)**:
  - Passes full transcript (`marking_text`) including all working lines/method marks and upright photo bytes to the marker across both base64 and URL paths.
  - Telemetry adherence: uses `logger.exception()` on image processing failures.

---

## 3. Verification & Validation
- **PR #166**:
  - Frontend typecheck passed (`tsc -b --noEmit`).
  - Frontend callout tests passed (4/4 tests in `callouts.test.ts`).
  - Backend revision suite: passed 474/474 tests in `AGENTIC_HARNESS/tests/revision/`.
- **PR #167**:
  - `AGENTIC_HARNESS/tests/exam_practice/test_image_service.py` passed (3/3 tests).
  - Full exam practice suite: passed 1,247/1,247 tests in `AGENTIC_HARNESS/tests/exam_practice/`.
- **Merge & Deploy**:
  - Both PRs merged cleanly into `master` with zero conflicts.
  - Promoted and pushed to `origin/master` and `origin/experimental` (commit `b66d1ba0d`).
  - Confirmed status on GitHub as `MERGED` for both PR #166 and PR #167.

---

## 4. Next Steps
- Monitor live revision note generation and photographed answer marking telemetry in production/staging.

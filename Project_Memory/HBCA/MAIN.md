# HBCA — Memory Index

**Last updated:** 2026-11-19
**Project repo:** /home/shadowe/Projects/hbcaClassroom
**One-line what-it-is:** LMS + virtual classroom + grounded AI for Zimbabwe schools, built for 2G connections and cheap Android devices.

Read this file first, every session, before touching the codebase. It
should be enough to understand what the project is and why it's built the
way it is without reading source. If something here is stale or wrong,
fix it in the same session you notice — don't leave it for later.

## What this project is
HBCA Classroom combines a learning management system, a live virtual classroom (LiveKit-based), and a grounded AI layer (citations-only answers over the school's own material) for Zimbabwean schools. The product is explicitly offline-tolerant and low-bandwidth: the whole frontend design system and realtime media stack are tuned around 2G links and low-end Android hardware. It is an independent product (own repo/stack/roadmap), distinct from the sibling `HBEC` project; integration with an external AI harness is only ever a versioned HTTP contract declared inside this repo.

## Current state
- **Completed:** Phase 1 (LMS foundation), Phase 2B (study artifacts — grounded study guides/FAQs/audio overviews), Phase 2C groundwork (permission predicates), Phase 3-b (realtime classroom: chat/hands/reactions/presence over a per-meeting WebSocket, LiveKit for media), Phase 3-c (lesson recordings → transcripts → citable sources).
- **In progress / under review (2026-11-19):** Phase 2D — "LMS: grading, report books and school operations." Three open PRs on GitHub:
  - PR #4 `experimental` — umbrella PR for the whole Phase 2D initiative
  - PR #3 `feature/grades-and-reports` — student grades page and e-report books
  - PR #2 `feature/grade-categories` — grade categories, weighting, terms and excusals
  A full code review of PR #4 (the umbrella PR) was requested before merge; see the SOFTWARE-ENGINEER bug log / report for anything it turns up.
- **Explicitly deferred:** Scaling the realtime `ConnectionManager` beyond a single process (Phase 6, needs Redis pub/sub); ASR-based auto-transcription (recordings currently rely on attached transcripts or a stub).

## Map
- `architecture/` — what the system looks like now (components, data flow, boundaries).
- `decisions/` — **why** it's built this way, where "why" isn't visible from reading the code.
- `implementation/` — notes on specific non-obvious mechanisms.
- `prompts/significant-tasks.md` — prompts that produced non-obvious architectural output worth reusing.
- `change-history/` — dated entries for changes that altered architecture or decisions.

This memory set was created 2026-11-19 and is still thin — most of the detailed per-topic files under `architecture/`, `decisions/`, and `implementation/` are still template placeholders. The authoritative source for conventions and the "why" behind most standing decisions, until these files are filled in, is `/home/shadowe/Projects/hbcaClassroom/CLAUDE.md`, which is comprehensive (layering, naming, workflow-state pattern, auth model, realtime design, LiveKit bandwidth policy, recordings/transcripts, study artifacts, frontend design system, bundle budget). Read that file directly rather than trusting this index to have captured it yet.

## Known gaps / don't trust this for
- `architecture/`, `decisions/`, and `implementation/` subfolders are unfilled template placeholders as of 2026-11-19 — don't treat their absence of content as "nothing interesting here," just as "not yet transcribed from CLAUDE.md and the codebase."
- Grading/report-books/school-operations (Phase 2D) architecture is not yet documented here — it's mid-review. Update this file and add an `architecture/`/`decisions/` note once Phase 2D merges.

## Related
- Bug/issue log entries for this project: see `SOFTWARE-ENGINEER` technical-area folders, filename prefix `HBCA-`.
- Reports: see `SOFTWARE-ENGINEER/reports/`, filename prefix `HBCA-`.

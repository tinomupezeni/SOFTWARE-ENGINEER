# HBCA — Memory Index

**Last updated:** 2026-11-23
**Project repo:** /home/shadowe/Projects/hbcaClassroom (GitHub: `restk-solutions/hbcaClassroom` — transferred from `winstonjthinker/hbcaClassroom` 2026-11-23 so GitHub Actions bills against the org's paid plan, not a personal account)
**One-line what-it-is:** LMS + virtual classroom + grounded AI for Zimbabwe schools, built for 2G connections and cheap Android devices.

Read this file first, every session, before touching the codebase. It
should be enough to understand what the project is and why it's built the
way it is without reading source. If something here is stale or wrong,
fix it in the same session you notice — don't leave it for later.

## What this project is
HBCA Classroom combines a learning management system, a live virtual classroom (LiveKit-based), and a grounded AI layer (citations-only answers over the school's own material) for Zimbabwean schools. The product is explicitly offline-tolerant and low-bandwidth: the whole frontend design system and realtime media stack are tuned around 2G links and low-end Android hardware. It is an independent product (own repo/stack/roadmap), distinct from the sibling `HBEC` project; integration with an external AI harness is only ever a versioned HTTP contract declared inside this repo.

## Current state
- **Completed:** Phase 1 (LMS foundation), Phase 2B (study artifacts — grounded study guides/FAQs/audio overviews), Phase 2C groundwork (permission predicates), Phase 3-b (realtime classroom: chat/hands/reactions/presence over a per-meeting WebSocket, LiveKit for media), Phase 3-c (lesson recordings → transcripts → citable sources), **Phase 2D (2026-11-23)** — "LMS: grading, report books and school operations." PR #4 (`experimental` → `main`, 19 commits/~240 files) merged after review: grade categories/weighting/terms/excusals, student grades page and e-report books, and eleven school-operations modules (login without email, form classes, attendance register, parents/SMS messaging, student records, year rollover, bulk marks, exams, timetable, data protection, fees). PRs #2 and #3 closed as superseded — their branches were fully contained in #4.
- **Explicitly deferred (from Phase 2D's own specs):** freezing report marks at publish, WhatsApp templates and delivery receipts, a payment gateway, undoing a rollover, option-subject timetable splits within a class.
- **Explicitly deferred (earlier phases):** Scaling the realtime `ConnectionManager` beyond a single process (Phase 6, needs Redis pub/sub); ASR-based auto-transcription (recordings currently rely on attached transcripts or a stub).
- **Deployment (2026-11-23, in progress):** First blue/green production deploy pipeline built — self-hosted GitHub Actions runner on `hbca-vps` (rooted on the 1TB `/sdb-disk` drive, shared host with HBEC/VLabs/ProjectFlow), `lms.hbca.tech` added to HBEC's shared Caddy gateway without touching its generated Caddyfile by hand, `production-cutover` GitHub Environment as a required-reviewer gate. Six real bugs found and fixed running the stack end-to-end for the first time (see `DevOps_and_Infrastructure/HBCA-2026-11-23-*.md` and `Frontend_and_UI/HBCA-2026-11-23-prod-dockerfile-skipped-devdependencies.md`): MinIO's own Docker Hub images are gone (switched to `bitnamilegacy/minio`, pinned by digest), that image's non-root UID needed a host directory chown, the deploy script's prune step was scoped to the whole shared Docker daemon instead of just this project, the backend's `Settings` required several env vars the compose file never set, both healthchecks used `localhost` which resolved to a dead IPv6 loopback, and the deploy workflow itself had a bootstrap-argument bug plus a YAML syntax error that broke the entire file. **Still open:** `S3_PUBLIC_URL`/`LIVEKIT_PUBLIC_URL` are placeholder values (object storage and realtime classroom are not yet reachable from a real browser in production — both need actual Caddy routes); LiveKit itself isn't started yet; no PR-time CI test gate exists in this repo. See `hbcaClassroom/docs/deploy/RUNBOOK.md` for the full design and status.

## Map
- `architecture/` — what the system looks like now (components, data flow, boundaries).
- `decisions/` — **why** it's built this way, where "why" isn't visible from reading the code.
- `implementation/` — notes on specific non-obvious mechanisms.
- `prompts/significant-tasks.md` — prompts that produced non-obvious architectural output worth reusing.
- `change-history/` — dated entries for changes that altered architecture or decisions.

This memory set was created 2026-11-19 and is still thin — most of the detailed per-topic files under `architecture/`, `decisions/`, and `implementation/` are still template placeholders. The authoritative source for conventions and the "why" behind most standing decisions, until these files are filled in, is `/home/shadowe/Projects/hbcaClassroom/CLAUDE.md`, which is comprehensive (layering, naming, workflow-state pattern, auth model, realtime design, LiveKit bandwidth policy, recordings/transcripts, study artifacts, frontend design system, bundle budget). Read that file directly rather than trusting this index to have captured it yet.

## Known gaps / don't trust this for
- `architecture/`, `decisions/`, and `implementation/` subfolders are unfilled template placeholders as of 2026-11-19 — don't treat their absence of content as "nothing interesting here," just as "not yet transcribed from CLAUDE.md and the codebase."
- Grading/report-books/school-operations (Phase 2D) architecture has merged but its `architecture/`/`decisions/` notes are not yet written up here in detail — the PR description and `plans/09-school-operations.md` / `specs/*.md` in the repo are the authoritative source until that transcription happens. Key policy decisions worth capturing when that happens: fees never gate education (specs/fees.md FE15), parents/bursar role denied by default (explicit allowlist per endpoint), medical notes visible only to admin + class teacher and excluded from data-protection exports.

## Related
- Bug/issue log entries for this project: see `SOFTWARE-ENGINEER` technical-area folders, filename prefix `HBCA-`.
- Reports: see `SOFTWARE-ENGINEER/reports/`, filename prefix `HBCA-`.

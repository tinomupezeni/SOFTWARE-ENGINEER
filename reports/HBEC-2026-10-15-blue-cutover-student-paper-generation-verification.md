# HBEC Blue Cutover and Student AI Paper Generation Verification

**Date:** 2026-10-15
**Project:** HBEC
**Type:** Deployment Verification
**Status:** Completed

## Summary
The verified blue deployment was promoted to live traffic to activate the
malformed-AI-JSON repair for student paper generation. A real authenticated
student-path generation request was then sent through the blue frontend proxy,
polled through completion, and produced a one-question Agriculture paper.

## Context / Trigger
An Agriculture student generation request had been accepted on green but
failed asynchronously because the provider response was not valid JSON. The
repair implementation was present on blue but public traffic still used green.
The user requested a cutover and live student test.

## Scope
Included the guarded blue-green cutover, service-link and retrieval-data gates,
singleton worker/beat handoff, authenticated student API request, asynchronous
job polling, and post-test container stability checks. It did not include
testing the unavailable GPU provider path or changing provider configuration.

## Method
Ran the repository's `manual-cutover.sh`, which revalidated blue revisions,
health, signed service links, curated retrieval data, Caddy configuration, and
follower handoff before switching traffic. Then generated a temporary access
token for an existing student, submitted a one-question Agriculture request
through `student-frontend-blue`, and polled the returned job until terminal
status.

## Decisions & Findings
- Traffic moved from green `9ae1402` to blue `1a3b4ec`.
- The cutover completed without errors; green remains available as rollback.
- The live student request returned `202` and a generation job.
- The job moved from `running` to `completed` in two polls.
- The generated paper contained one question and 10 total marks.
- Harness logs show the expected `paper_generation_started` and
  `paper_generation_completed` events with no provider failure for this test.
- Student worker, beat, embeddings, Student Backend, frontend, and Harness
  containers were healthy with restart count zero after the cutover.

## Changes Made
- Promoted existing commit `1a3b4ece` to live through
  `scripts/deploy/manual-cutover.sh`.
- No source changes were made during the cutover.
- Created the resulting student-owned test paper:
  `0326183d-dede-4065-b2ce-830f0eb4efcf`.

## Verification
- Active color: `blue`.
- Blue revision: `1a3b4ec`.
- Green revision: `9ae1402` and untouched as rollback target.
- All signed service links passed.
- `heritage_knowledge` retrieval gate passed with 51 points.
- Singleton workers/beats and `harness-embeddings` were handed to blue and
  healthy.
- Live student generation completed successfully:
  job `d7cb47de-ec59-4618-9a89-4eb16f518c54`.
- Post-test restart counts were zero for the tested services.

## Follow-ups / Deferred
- The free GPU/Ollama provider remains unreliable and can still produce
  controlled generation failures independent of the JSON-repair fix.
- The generated test paper should be retained or removed according to the
  normal student-data retention policy; no destructive cleanup was performed.
- Persist asynchronous generation failures in central error telemetry with
  stable error codes so they do not depend on Docker log retention.

## References
- `HBEC-2026-10-15-student-ai-paper-generation-failed-on-active-color.md`
- `HBEC-2026-10-15-ai-paper-generation-gpu-unavailable.md`
- `scripts/deploy/manual-cutover.sh`
- `AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py`

---

**Completed By:** Copilot
**Duration:** Same session

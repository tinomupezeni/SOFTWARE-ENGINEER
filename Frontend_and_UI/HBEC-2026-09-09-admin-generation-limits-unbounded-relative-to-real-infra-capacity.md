# Admin Generation's Batch/Question-Count Limits Weren't Backed by Real Infra Capacity

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
`paper_count` (up to 50) and `question_count` (unbounded on the Django side,
50 on the harness side) were never validated against what the actual shared
GPU and worker concurrency could reliably sustain. A real 10-paper batch
already showed transient GPU contention.

## Symptoms
- No direct user-facing error — this was found proactively while
  investigating real contention on a live 10-paper batch, not reported as a
  complaint.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Admin Backend, Admin Frontend, Agentic Harness
- **Time First Observed:** 2026-09-09, during live admin batch-generation testing

## Investigation Steps

### 1. Initial Diagnosis
A real `paper_count=10` batch produced two transient (auto-retried)
`gpu_unavailable` failures — the admin-worker only runs generation 2 at a
time against one shared, rented GPU, so a request for many more papers just
queues, with no ceiling communicated to the admin ahead of time.

### 2. Root Cause Analysis
Computed the actual per-paper-type token ceiling
(`min(16000, 1200 + count * per_question_tokens)`, see companion issue on
type-aware token budgeting): "structured" questions (the most expensive
type, 550 tokens/question) hit that 16000 ceiling at ~27 questions — past
that, a request silently returns fewer questions than asked for rather than
erroring.

### 3. Key Findings
- Neither limit had ever been measured against real infrastructure — both
  were arbitrary round numbers.
- `question_count` had no upper bound at all on the Django side; only the
  harness's own schema capped it, at 50 — well past the point where quality
  silently degrades.

## Root Cause
Configuration/UX gap: input ceilings not grounded in measured infrastructure
capacity.

## Solution

### Immediate Fix
None needed — no production incident, a proactive fix.

### Long-term Fix
- `paper_count`: capped at 10 (the largest batch actually validated),
  both in the Django serializer and the frontend input's `max` attribute,
  with inline UI text explaining the 2-at-a-time concurrency constraint.
- `question_count`: capped at 20 (safe across every paper type with
  headroom to spare, previously unbounded on the Django side), with inline
  UI text explaining that "structured" needs more tokens per question.
- 4 new boundary tests (10/11 papers, 20/21 questions).

## Prevention
- [x] Limits now backed by measured numbers, not guesses, with test coverage
- [ ] Revisit both ceilings if/when the harness moves off this single
      shared GPU or the concurrency setting changes

## Related Issues
- Directly informed by the type-aware token-budget fix and the litellm/OOM
  contention findings earlier in the same session

## References
- `ADMIN/adminBackend/apps/exam_papers/serializers.py`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/AIGenerationModal.tsx`
- Commit `5a1f6bdd`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session

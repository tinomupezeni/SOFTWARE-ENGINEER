# Production Heritage Collection Missing From Qdrant

**Date:** 2026-10-14  
**Project:** HBEC  
**Environment:** Production  
**Severity:** Medium  
**Status:** Resolved

## Summary

The blue Harness deployment logged repeated 404 warnings during startup
prewarm because the shared production Qdrant instance did not contain the
`heritage_knowledge` collection. The deployed Harness image contained the
51-entry curated corpus and the seed script, but no deployment step had seeded
that data into the production Qdrant volume.

## Symptoms

- `hbec-harness-blue` logged `retrieval_prewarm_search_failed` for
  `heritage_knowledge`.
- Qdrant listed seven collections but not `heritage_knowledge`.
- Harness remained healthy because prewarm deliberately treats an absent
  collection as non-fatal.
- Heritage retrieval was therefore unavailable until the collection was
  created and populated.

## Environment Details

- **Server/Host:** `hbca-vps` (`gpu-ndime`)
- **Services Affected:** Harness blue; shared Qdrant
- **Related Components:** `app/main.py`, `app/shared/heritage.py`,
  `scripts/seed_heritage.py`
- **Time First Observed:** 2026-10-14 13:57 SAST

## Investigation Steps

### 1. Initial Diagnosis

Compared blue and green Harness configuration and queried Qdrant from both
containers. Both used `http://qdrant:6333`, and both saw the same collection
set without `heritage_knowledge`.

### 2. Root Cause Analysis

The image contained the corpus:

- 51 entries: 17 indigenous-knowledge anchors, 8 principles, 26 problems
- Corpus scope: Zimbabwe Heritage-Based Curriculum

The production deployment script starts containers and verifies links and
secrets, but does not seed curated Qdrant corpora. The prewarm code catches an
absent collection and allows startup to continue, so the deployment gate did
not identify the missing heritage data.

```bash
sudo docker exec hbec-harness-blue python scripts/seed_heritage.py
```

During investigation, an attempted `--help` probe executed the script because
the script has no argument parser or help mode. This created and populated the
collection.

### 3. Key Findings

- Before seeding, Qdrant returned 404 for `heritage_knowledge`.
- The shared collection now exists with 51 points and 768-dimensional cosine
  vectors.
- A live retrieval query returned three relevant heritage matches, including
  the raised hozi granary scenario.
- Blue remains on `bda1954`; public traffic remains on green.

## Root Cause

Curated heritage data is shipped in the Harness image but is not part of the
blue-green deployment verification or a documented post-deploy data bootstrap.
The startup prewarm path intentionally degrades when the collection is absent,
which hides a missing production prerequisite as a warning.

## Prevention / Rule

**Guardrail:** Add a read-only deployment verification check that asserts every
required curated Qdrant collection exists and has a non-zero point count,
including `heritage_knowledge`.

This catches missing data at the inactive-color gate without creating or
mutating collections, while preserving the current fail-soft behavior for
optional learner-specific collections.

## Solution

### Immediate Fix

Seeded the deployed corpus into the shared production Qdrant instance:

```bash
sudo docker exec hbec-harness-blue python scripts/seed_heritage.py
```

Verified 51 points and successful live retrieval from blue.

### Long-term Fix

- Add curated-collection readiness to the deployment verification gate.
- Make the seeding command explicit and non-ambiguous, with a safe help mode
  and an idempotent deployment/runbook step.
- Decide whether the data bootstrap belongs in a controlled migration job or a
  separately approved release checklist.

## Prevention

- [ ] Add required Qdrant collection/point-count verification.
- [ ] Add a documented production corpus seeding step.
- [ ] Add a non-mutating `--help` path to `seed_heritage.py`.
- [ ] Add an alert or metric for missing required retrieval collections.

## References

- `AGENTIC_HARNESS/app/main.py`
- `AGENTIC_HARNESS/app/shared/heritage.py`
- `AGENTIC_HARNESS/scripts/seed_heritage.py`
- `docs/BLUE_GREEN_CUTOVER_RUNBOOK.md`

---

**Resolved By:** Copilot  
**Time to Resolution:** Approximately 5 minutes

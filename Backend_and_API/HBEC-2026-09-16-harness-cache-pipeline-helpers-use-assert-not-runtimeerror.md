# Harness Redis Pipeline Cache Helpers Use `assert` Instead of `RuntimeError` — Silently Disarmed Under `-O`

**Date:** 2026-09-16
**Project:** HBEC
**Environment:** Development (found during a read-only caching-architecture research pass; not yet observed causing a production incident)
**Severity:** Medium (currently latent — Python is not run with `-O` in this stack today, so the guard still fires — but it is a standing landmine that silently stops firing the moment that changes, with no error at the call site)
**Status:** Identified, not fixed (out of scope for the research task that found it)

## Summary
While surveying every actual Redis/cache touchpoint in the codebase for a
caching-architecture scoping initiative, found that four of the ten public
functions in `AGENTIC_HARNESS/app/shared/cache.py` guard against "Redis not
initialised" with a bare `assert` instead of raising `RuntimeError`, even
though the other six functions in the *same file* (`get_redis`,
`get_redis_client`, `cache_get_json`, `cache_set_json`, `cache_delete`) all
correctly raise `RuntimeError("Redis not initialised — call init_redis()
first")` for the identical precondition. `HBEC/CLAUDE.md`'s Cross-Cutting
Rules section is explicit: "Replace `assert` with `RuntimeError` in
production paths — assertions are stripped with `-O`." This file violates
that rule in exactly the functions used for the pipeline batching path
(`get_pipeline`, `pipeline_get_many`, `pipeline_set_many`,
`pipeline_delete_many`) — used by, among others,
`app/shared/memory.py::AgentMemory.get_all`/`delete` for batched
multi-tier Redis reads/deletes.

## Symptoms
None yet in production — this is a code-review-style finding, not a live
incident. If the interpreter were ever invoked with `-O` (or
`PYTHONOPTIMIZE` set), these four functions would silently skip the
initialisation check entirely: calling `get_pipeline()` before
`init_redis()` has run would proceed to call `_redis.pipeline()` on `None`
and raise a bare, unhelpful `AttributeError: 'NoneType' object has no
attribute 'pipeline'` deep inside a batch helper, instead of the clear,
intentional `RuntimeError` the rest of the file already provides.

## Environment Details
- **Services Affected:** `AGENTIC_HARNESS` (harness FastAPI monolith) — the
  same pattern was checked in the mirrored `NOTIFICATIONS/app/shared/cache.py`
  and found clean (that file has no pipeline helpers at all, so no instance
  of the bug there).
- **Related Components:** `app/shared/memory.py` (`AgentMemory`, per-student
  per-pillar TTL-tiered memory) is the actual caller of the affected
  functions via `get_all()`/`delete()`'s multi-tier batch operations.
- **Time First Observed:** 2026-09-16, during a read-only survey of Redis/cache
  usage across the monorepo (unrelated primary task: scoping a
  caching-architecture improvement initiative).

## Investigation Steps

### 1. Initial Diagnosis
Was reading `AGENTIC_HARNESS/app/shared/cache.py` end-to-end to document its
contract (TTL policy, initialisation, invalidation) for the caching survey,
and noticed the precondition guard style was inconsistent within the same
file.

### 2. Root Cause Analysis
```bash
grep -n "assert _redis\|raise RuntimeError" AGENTIC_HARNESS/app/shared/cache.py
```
Six functions (`get_redis`, `get_redis_client`, `cache_get_json`,
`cache_set_json`, `cache_delete`, plus the module docstring's own example)
use the `if _redis is None: raise RuntimeError(...)` idiom. Four — all in
the "Pipeline helpers for batch operations" section added later —
use `assert _redis is not None, "Redis not initialised"` instead, at lines
148, 163, 184, and 204 (`get_pipeline`, `pipeline_get_many`,
`pipeline_set_many`, `pipeline_delete_many`).

### 3. Key Findings
- This is the exact class of bug `HBEC/CLAUDE.md` already names as a
  standing cross-cutting rule ("Replace `assert` with `RuntimeError` in
  production paths — assertions are stripped with `-O`"), present in the
  one file (`app/shared/cache.py`) that is the single documented entry
  point for all harness Redis access — the blast radius if this ever fires
  silently is every pillar's memory/narrative/episodic reads.
- The bug is inconsistent within its own file: whoever wrote the later
  "pipeline helpers" section did not follow the pattern already established
  three functions above it, suggesting an oversight rather than a
  deliberate choice.

## Root Cause
Four functions added to `app/shared/cache.py`'s "pipeline helpers" section
use `assert` for a production precondition check instead of `RuntimeError`,
inconsistent with the rest of the same file and in direct violation of the
project's own documented Cross-Cutting Rule against this exact pattern.

## Prevention / Rule
**Guardrail:** A repo-wide lint rule (`ruff` has `S101`/`flake8-bandit`'s
assert-detection, or a simple `grep -rn "^\s*assert " app/` in CI) that
fails the build on any bare `assert` outside `tests/` — turning "a reviewer
has to notice the inconsistency by eye" into an automatic, mechanical catch
of the exact violation `HBEC/CLAUDE.md` already prohibits in prose.

## Solution

### Immediate Fix
Not applied — this was found during a read-only research/scoping task with
an explicit no-code-changes constraint. Logged per this repo's convention so
it is not lost before the caching-architecture initiative (or an ordinary
follow-up commit) picks it up.

### Long-term Fix
Replace all four `assert _redis is not None, "Redis not initialised"` lines
in `AGENTIC_HARNESS/app/shared/cache.py` with
`if _redis is None: raise RuntimeError("Redis not initialised — call init_redis() first")`,
matching the other six functions in the same file. Trivial, mechanical,
no behavior change under normal (non `-O`) execution.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a, `CLAUDE.md` already states the rule;
      the gap is enforcement, not documentation
- [ ] Code changes required — swap `assert` for `RuntimeError` in the four
      functions named above; consider a CI lint rule per the guardrail

## Related Issues
- None yet filed.

## References
- `AGENTIC_HARNESS/app/shared/cache.py:148,163,184,204`
  (`get_pipeline`, `pipeline_get_many`, `pipeline_set_many`,
  `pipeline_delete_many`)
- `AGENTIC_HARNESS/app/shared/memory.py` (`AgentMemory.get_all`, `.delete`) —
  callers of the affected batch helpers
- `HBEC/CLAUDE.md`, Cross-Cutting Rules: "Replace `assert` with
  `RuntimeError` in production paths — assertions are stripped with `-O`"

---

**Resolved By:** Not yet resolved — found by Claude Sonnet 5 during a
read-only caching-architecture research pass; fix deferred to a follow-up
session with code-change scope.
**Time to Resolution:** N/A (investigation only)

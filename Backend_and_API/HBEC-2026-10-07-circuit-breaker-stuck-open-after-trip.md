# Circuit breaker that opened never closed again — AI features stuck "down" after any transient failure

**Date:** 2026-10-07
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** Critical
**Status:** Resolved

## Summary
`AGENTIC_HARNESS/app/shared/circuit_breaker.py`'s `CircuitBreaker` reported
state `HALF_OPEN` once its reset timeout passed, but never actually *set*
`_state` to `HALF_OPEN` — it stayed `OPEN` internally. `_record_success`'s
"if HALF_OPEN, close the breaker" branch therefore never matched, so a
successful trial call during the half-open window never closed the breaker.
Once the two trial calls in that window were spent, every subsequent call
was refused — permanently, **until the harness process restarted**. This
breaker guards every LLM provider, Qdrant, the embedder, image generation,
and the harness→student-backend API, so one transient failure on any of
those (a provider hiccup, a brief Qdrant restart) left that dependency
"down" from the circuit breaker's point of view long after it had actually
recovered, surfacing as "AI features not working" platform-wide.

Found by an internal platform audit on 2026-10-07 (not by this investigation
— credited to the audit and `winstonjthinker` + Claude Opus 5.5, commit
`df23bbfd`). Logged here per this repo's standing rule (every bug found or
fixed gets an entry, regardless of who fixed it) because its live impact was
independently confirmed and the fix's rollout was carried out as part of a
separate investigation into "marking is not working" reports.

## Symptoms
- Student/admin reports of marking, Friday, or search intermittently "not
  working," with no consistent reproduction — exactly what a permanently
  wedged breaker produces: fine until *something* trips it once, broken
  for everyone from then on regardless of whether the real dependency has
  recovered.
- Confirmed live on 2026-10-07: `hbec-harness-green`'s logs showed repeated
  `qdrant_circuit_open` events for `marking_knowledge`, `marking_schemes`,
  `semantic_cache`, `curriculum_content`, and `learner_memory` — all
  correctly triggered by a genuinely failing Qdrant (see
  `HBEC-2026-10-06-qdrant-too-many-open-files.md`), but with no fixed code
  there was no way for any of those breakers to recover once Qdrant was
  healthy again short of restarting the harness process.

## Root Cause
`_advance()`'s `OPEN -> HALF_OPEN` transition updated what the breaker
*reported* (the computed/derived state a caller would see) without updating
`_state` itself, so the code path that actually decides whether to open a
trial window and whether a success should close the breaker never saw
`HALF_OPEN` - it stayed logically `OPEN` forever once the trial calls
during any accidental half-open-looking window were exhausted.

## Solution

### Fix
`_advance()` now makes the `OPEN -> HALF_OPEN` transition real under the
lock and opens a fresh trial window each time; both `call()` and the
external `record_*` paths go through it, so a success during that window
actually closes the breaker.

### Tests
The breaker had zero tests before this fix. `tests/shared/test_circuit_breaker.py`
added — two were red before the fix (stuck in `half_open`, confirming the
exact failure mode above). A formal TLA+ model
(`formal/tla/CircuitBreaker.tla`) states the liveness property directly:
"once the dependency is healthy for good, the breaker closes" — violated by
the old code, holds under the fix. Full harness suite (shared/unit/
integration): 1585 passed.

### Rollout (this session)
Discovered already merged to master and already deployed+verified on the
VPS's idle color (`blue`, commit `1c1ae95`) by a separate stream of work,
while investigating a user-reported "marking is not working" pattern that
traced to exactly this bug compounding with the still-unfixed Qdrant FD
exhaustion (see the related entry). Verified blue's 9 containers healthy,
verified every signed service link, then cut over to blue
(`scripts/deploy/manual-cutover.sh`) and confirmed zero circuit-breaker
trips on the live harness in the minutes after the Qdrant fix below landed,
versus a continuous stream of them before.

## Prevention / Rule
**Guardrail:** `tests/shared/test_circuit_breaker.py` now exercises the
half-open→closed transition directly, and the TLA+ liveness property gives
a machine-checked statement of the invariant ("stays unhealthy forever" is
provably impossible once the dependency is actually healthy) rather than
relying on manual reasoning about a lock-guarded state machine.

## Related Issues
- `HBEC-2026-10-06-qdrant-too-many-open-files.md` — the dependency whose
  repeated real failures is what actually tripped this breaker in
  production; fixing either alone would not have been sufficient (a
  correctly-working breaker still legitimately opens against a genuinely
  failing Qdrant; a healthy Qdrant doesn't un-stick an already-wedged
  breaker on a process that hasn't restarted).

## References
- `AGENTIC_HARNESS/app/shared/circuit_breaker.py`
- `AGENTIC_HARNESS/tests/shared/test_circuit_breaker.py`
- `formal/tla/CircuitBreaker.tla`, `CircuitBreaker_fixed.cfg`, `CircuitBreaker_old.cfg`
- Commit `df23bbfd5e161e45844dd4b30e999a10254f708a`

---

**Resolved By:** winstonjthinker + Claude Opus 5.5 (fix); rollout and live
verification by Tinotenda Mupezeni
**Time to Resolution:** Fix already merged by the time this was traced from
a user report; cutover to production completed same day.

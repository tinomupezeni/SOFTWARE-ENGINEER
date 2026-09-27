# WebSocket replay cursor derived from the maximum sequence, so nothing replayed

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
`stream_run` built its replay cursor from the snapshot's `last_seq` — the *highest* sequence in
the run — and then asked for events **after** that cursor. The result was always an empty set, so
a client reconnecting mid-run was sent the current state but no history. The defect was invisible
in testing because of a coincidental truthiness quirk: the expression
`int(snapshot["last_seq"] or -1)` evaluates to `-1` when `last_seq` is `0`, so a run with exactly
one event replayed correctly by accident. The `after_seq` query parameter that the module's own
docstring promised was never implemented at all.

## Symptoms
- Reconnecting to a websocket showed the run's state but an empty timeline
- No error, no warning — the stream simply started from "now"
- `test_websocket_replays_history_before_streaming` passed, giving false confidence
- The module docstring documented `after_seq` as a supported parameter; passing it silently did
  nothing

## Environment Details
- **Server/Host:** local dev, `runner/`
- **Services Affected:** live run telemetry, all WebSocket clients
- **Related Components:** `api/routes/ws.py`, `tests/test_api.py`
- **Time First Observed:** 2026-09-27, code review during test debugging

## Investigation Steps

### 1. Initial Diagnosis
Reading `api/routes/ws.py` against its own docstring, which claims "The first frame on connect is
the existing timeline" and that `after_seq` "makes the seam explicit".

### 2. Root Cause Analysis
```python
await websocket.send_json({"type": "hello", "run_id": str(run_id), **snapshot})

last_seq = int(snapshot["last_seq"] or -1)

# Replay first, so a reconnecting client sees the whole story.
for event in await db_call(_events_after, run_id, last_seq):
```

`last_seq` is the newest event; `_events_after(run_id, last_seq)` filters `seq__gt=last_seq`.
Cursor already at the end, query for the future — empty by construction. Replay could never run.

### 3. Key Findings
- `0 or -1` → `-1`, so a one-event run (seq 0) got a full replay **purely by accident**. Any run
  with two or more events set the cursor to 1, 2, … and replayed nothing. Every test used a
  freshly submitted run, which has exactly one event.
- The bug is invisible to the happy-path test and only appears at seq ≥ 1, i.e. as soon as a run
  is actually running and has emitted more than one event.
- The `or` was also doing silent type coercion: a legitimate `last_seq` of `0` was indistinguishable
  from "no events at all".
- `after_seq` was specified in the docstring but absent from the signature — documented API that
  did not exist.

## Root Cause
The replay cursor and the snapshot cursor were conflated. The snapshot's `last_seq` answers "where
does the timeline end", which is the wrong question for "where should the reader start". Reusing
it as the resume point skips the entire history by construction, and the `or -1` fallback papered
over the single-event case well enough to hide the bug from the only test that covered it.

## Prevention / Rule
**Guardrail:** Derive a stream's start cursor from an explicit `after_seq` input defaulting to
`-1`, never from a "highest seen" value, and ban `x or default` where `0` is a legal value of `x`.

The test-level half of the guardrail: a replay test must use a fixture with **more than one**
event and assert the **full ordered sequence**, because a one-event timeline cannot distinguish
a correct replay from a broken one.

## Solution

### Immediate Fix
```python
resume_from = -1 if after_seq is None else after_seq

await websocket.send_json(
    {"type": "hello", "run_id": str(run_id), "after_seq": resume_from, **snapshot}
)

last_seq = resume_from
for event in await db_call(_events_after, run_id, last_seq):
    last_seq = event["seq"]
    await websocket.send_json({"type": "event", **event})
```

The cursor now comes from the client's position, with `-1` meaning "from the beginning", and
`after_seq` is a real parameter with the documented behaviour.

### Long-term Fix
Added two tests that the old suite was structurally unable to fail:

- `test_websocket_replays_every_event_not_just_the_first` — three events, asserts `seen == [0, 1, 2]`
- `test_websocket_after_seq_resumes_instead_of_replaying` — asserts resume skips history

Verified they are load-bearing by reintroducing the bug and confirming both fail.

## Prevention
- [x] Replay cursor derived from `after_seq`, defaulting to `-1`
- [x] `after_seq` implemented and advertised in the `hello` frame
- [x] Multi-event replay test asserting the full ordered sequence
- [x] Resume test asserting history is skipped
- [x] Tests confirmed to fail when the bug is reintroduced

### Follow-up found while fixing this
Those tests **hung** rather than failed when the bug was present, because a `queued` run is
non-terminal so the stream polls forever waiting for a frame that never arrives. Starlette's
`TestClient` has no timeout on `receive_json()`. Fixed globally with `pytest-timeout` and
`timeout = 20` in `pyproject.toml`, so no future stream test can hang the suite.

## Related Issues
- `Backend_and_API/ARCHCODE-2026-09-27-django-tests-need-transactional-db-with-async-bridge.md` —
  the 404s that initially drew attention away from this
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- Python truthiness: `0 or -1` is `-1`, and `False`/`None` collapse identically — the root of
  the accidental pass

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~30 minutes

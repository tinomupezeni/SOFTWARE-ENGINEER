# replay_dropped_messages has never actually replayed anything

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging (fixed); Production (same bug present, not yet fixed)
**Severity:** Critical
**Status:** Resolved on staging

## Summary
`replay_dropped_messages` — the documented, sanctioned recovery mechanism for
replication failures (see CLAUDE.md's "A failed stream message used to be
dropped... Failures now land in DroppedStreamMessage before the ack, and
replay with `python manage.py replay_dropped_messages`") — has never
successfully replayed a single message. Every call this session (226
messages across three separate runs, all reported "replayed N, still failing
0") silently did nothing. A student reported "Mathematics still has 0
papers" after a replay had already reported success for that exact content.

## Symptoms
- A specific admin-authored paper (`ZIMSEC-4004-P1-SPEC`, `status=published`)
  did not exist anywhere in the student database under any subject, despite
  `StreamOutbox` marking its publish event `status=published` and the Redis
  consumer group showing `pending=0, lag=0` (genuinely, fully consumed).
- No `DroppedStreamMessage` record existed for it either — the standard
  "at least we know it failed" trail was also absent, because the failure
  happened *during a previous replay of an earlier drop*, and that replay's
  own (silent, false) "success" cleared the trail.
- Five of six Form-4 subjects checked (Physics, Biology, Mathematics,
  Chemistry, Combined Science) showed **zero** past-paper content on the
  student side despite dozens of published admin rows each; only Economics
  (small volume, likely never dropped) matched.

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142), staging
- **Services Affected:** Student Backend replication (`apps/replication/stream_consumer.py`)

## Investigation Steps

### 1. Initial Diagnosis
Traced one specific missing paper end to end rather than guessing:
`StreamOutbox.status` → `published` (admin genuinely sent it) → Redis
consumer group `XINFO GROUPS` → `pending: 0, lag: 0` (genuinely, fully
consumed by the live consumer) → `Paper.objects.filter(id=<that exact id>)`
on student → `None`. No `DroppedStreamMessage` row for it either, current or
historical. The message existed, was sent, was read — and then vanished
with no record anywhere.

### 2. Root Cause Analysis
```python
# process_message() — matches ONLY a live Redis read (decode_responses=False)
event_type = message.get(b"type", b"").decode() if b"type" in message else ""
if not event_type:
    logger.warning(f"Message {msg_id} has no event type")
    return True  # <- silently "succeeds"

# _record_dropped_message() — decodes bytes to str BEFORE saving to the JSONField
raw = {}
for key, value in (message or {}).items():
    key = key.decode() if isinstance(key, bytes) else key
    value = value.decode() if isinstance(value, bytes) else value
    raw[str(key)] = value
DroppedStreamMessage.objects.create(..., payload=raw, ...)
```
`DroppedStreamMessage.payload` is a `JSONField` — everything in it is `str`,
never `bytes` (JSON has no byte-string keys). `replay_dropped_messages` calls
`consumer.process_message(row.message_id, row.payload)` with exactly that
str-keyed dict. `b"type" in message` is `False` for a str-keyed dict, every
single time, unconditionally — hitting the "has no event type" branch, which
**returns `True`**. `replay_dropped_messages` takes that `True` at face
value, stamps `replayed_at`, and reports success. No handler was ever
called. This is not intermittent — it is 100% of every replay, always.

### 3. Key Findings
- A second, related bug in the same function: `_record_dropped_message`
  reads `raw.get("event_type", "")`, but the field's real name in the
  message is `"type"` (confirmed directly from a raw `XRANGE` read of the
  stream: `{"type": "paper_published", "content_id": ..., ...}`). This means
  `DroppedStreamMessage.event_type` has been blank on **every row, always**
  — which is also why `replay_dropped_messages --event-type topic_published`
  silently matched nothing earlier this session (worked around at the time
  by omitting the filter, without yet knowing why it was needed).
- This bug predates today's session — it is a property of the code, not of
  anything done today. Every environment that has ever run
  `replay_dropped_messages` (staging, and **production**, per the CLAUDE.md
  history describing this exact mechanism being used there for a prior
  production topic-sync incident) has the same gap: any message that ever
  failed on first live delivery has silently never been recovered, no matter
  how many times replay was run against it.
- Ruled out two other hypotheses before landing on this one: Redis stream
  `MAXLEN` trimming (no `maxlen` parameter is passed to `xadd` anywhere in
  either service, confirmed by reading `streams.py`) and a dead-consumer PEL
  problem from the container-hostname-derived consumer name pattern
  (`XINFO GROUPS` showed `pending: 0`, ruling this out for *this* incident,
  though the underlying `consume_pending()` design — only reads the
  *current* consumer's own PEL, no `XCLAIM`/`XAUTOCLAIM` reclaim from a
  dead consumer name — remains a real, separate latent risk worth a future
  look, not exercised here).

## Root Cause
`process_message()` was written assuming its only caller is the live
`xreadgroup` loop (`decode_responses=False`, byte-keyed dicts). Nothing
enforced that assumption, and the replay path — added later, calling the
same method with a differently-shaped dict — violated it silently. The
method's own error handling (`if not event_type: ... return True`) is
correct and load-bearing for its *original* purpose (an admin publishing an
unrecognized/empty event type shouldn't block the queue) — it just also,
accidentally, perfectly disguises the type-mismatch bug as "nothing to
process" instead of an error.

## Prevention / Rule
**Guardrail:** `test_process_message_accepts_str_keyed_payload` in
`test_stream_consumer.py` — asserts `process_message` calls the correct
handler for a str-keyed dict built the same way `DroppedStreamMessage.payload`
actually is, not just the byte-keyed shape every existing test used. A
function accepting `dict` with no shape contract enforced by a type system
(this one takes whatever `xreadgroup` or a `JSONField` happens to hand it)
needs its tests to cover every real caller's actual shape, not just the
original one.

## Solution

### Immediate Fix
`process_message()` now normalizes `message` to all-`str` keys/values once,
at the top, before any lookup — so both the live-Redis shape and the
replayed-JSONField shape work identically. Fixed `_record_dropped_message`
to read `raw.get("type", "")` instead of the nonexistent `"event_type"` key.
Commit `0185b071`.

### Recovery
Reset `replayed_at = NULL` on all 226 previously-fake-"replayed"
`DroppedStreamMessage` rows on staging, then ran `replay_dropped_messages`
for real: **121 replayed successfully, 105 still failing** (genuinely stale
— those are old `topic_published` events whose topic already exists under a
different id from a later, separately-run `republish_canonical`, and
correctly reported failing rather than silently discarded, per the command's
existing, correct design). Verified end-to-end: Mathematics, Physics,
Biology, Chemistry and Combined Science all now show their real past-paper
counts (22, 12, 7, 6, 9 respectively, matching today's seed exactly) via a
direct call to the same API endpoint the frontend uses.

### Long-term Fix
**Production has the identical bug and has never successfully replayed a
message either.** Explicitly not touched this session (staging-only, per
instruction) — the same fix, reset, and replay sequence needs running there.
Given CLAUDE.md documents a prior production incident (missing curriculum
topics) that was "fixed" via this exact mechanism, that incident's
resolution should be treated as unverified until production's replay is
re-run for real.

## Prevention
- [x] Fix `process_message` to accept both message shapes
- [x] Fix `_record_dropped_message`'s wrong key name
- [x] Add regression test covering the str-keyed (replay) shape
- [x] Reset and re-run replay for real on staging (121 recovered, 105 correctly still failing)
- [ ] **Run the same reset + replay on production** — deferred, staging-only this session
- [ ] Consider `XCLAIM`/`XAUTOCLAIM` reclaim-from-dead-consumer logic for
      `consume_pending()` — a real, separate gap noticed while ruling out
      hypotheses, not the cause of this specific incident

## Related Issues
- `Database_and_State/HBEC-2026-09-21-staging-student-subject-drift.md` —
  the same-day subject-sync gap whose recovery (via this exact,
  then-unknowingly-broken, replay command) is now confirmed to also need
  re-verification
- `Backend_and_API/HBEC-2026-09-21-legacy-local-curriculum-seed-orphaned-students.md`

## References
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py`
- `STUDENT/hbec_backend/apps/replication/management/commands/replay_dropped_messages.py`
- `STUDENT/hbec_backend/apps/replication/tests/test_stream_consumer.py`

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~70 minutes from "maths still has 0 papers" to root cause, fix, and verified recovery (staging only)

# Adding a habit silently did nothing on other screens — a Dart type-inference gotcha crashed the entire WebSocket listener, not just that one event

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** High — silently broke all live updates for the dashboard (not just the triggering feature) with no visible error to the user
**Status:** Resolved

## Summary
After wiring a new `habit_added` WebSocket event so a newly-added habit
appears live on every connected member's dashboard, the user reported
"after adding protocol, nothing is coming up." The backend logs confirmed
the `POST /clubs/{id}/habits` call succeeded (`201 Created`) and the
event was published — the bug was entirely client-side.
`DashboardProvider._initWebSocket`'s message handler called
`_habits.add({...})` with an inline map literal; Dart inferred that
literal's static type as `Map<String, Object>` instead of the expected
`Map<String, dynamic>` (the declared type of `_habits`'s elements),
because one of the literal's values was an explicitly-typed `<String>{}`
set alongside two `String` values, and this combination didn't trigger
Dart's normal top-down type inference from the surrounding
`List<Map<String, dynamic>>.add()` call. The resulting
`TypeError` was unhandled, which didn't just fail that one event — it
killed the entire `StreamSubscription.listen` callback for the
WebSocket, so no further events of any kind (check-ins, other habit
completions) were processed on that connection until the next full app
restart.

## Symptoms
- Backend confirmed the add-habit request succeeded (`201 Created`,
  visible in `docker compose logs api`), but the new habit never appeared
  on any connected client's dashboard.
- `flutter run`'s log showed:
  `Unhandled Exception: type '_Map<String, dynamic>' is not a subtype of
  type 'Map<String, Object>' of 'value'`, thrown from
  `DashboardProvider._initWebSocket.<anonymous closure>` at the
  `List.add` call.
- Because this exception propagated out of the stream subscription's
  callback, it silently disabled ALL further WebSocket-driven UI updates
  for that session, not just the `habit_added` case — a user who'd been
  in the app a while and then had a friend check in would also stop
  seeing that light up, with no visible error anywhere in the UI.

## Environment Details
- **Server/Host:** Physical Android device (Flutter debug build)
- **Services Affected:** `club_zero_mobile/lib/providers/dashboard_provider.dart`
  (`_initWebSocket`, the `habit_added` case; also affected the identically-shaped
  map construction in `_fetchSeats`, fixed preventively at the same time)
- **Time First Observed:** 2026-09-28, live-testing the newly-added
  "add protocol" feature on the physical device.

## Investigation Steps

### 1. Initial Diagnosis
Backend logs showed the request succeeding, ruling out a server-side
cause; pulled the live `flutter run` log and found the unhandled
exception immediately.

### 2. Root Cause Analysis
```dart
// dashboard_provider.dart (before fix) — inside the WS message handler
case 'habit_added':
  final habitId = data['habit_id'].toString();
  if (!_habits.any((h) => h['id'] == habitId)) {
    _habits.add({                    // <- inferred as Map<String, Object>
      'id': habitId,
      'name': data['name']?.toString() ?? '',
      'completedBy': <String>{},     // an explicitly-typed Set<String> value
    });
    notifyListeners();
  }
  break;
```
`_habits` is declared as `List<Map<String, dynamic>>`. Top-down type
inference should propagate `Map<String, dynamic>` as the expected type
for the argument to `.add()`, but empirically did not in this context —
the literal's own inferred type (`Map<String, Object>`, likely from
taking the least-upper-bound of `String`, `String`, and `Set<String>`)
won out, and that type is not assignable where `Map<String, dynamic>` is
required by `List<E>.add(E value)` with `E = Map<String, dynamic>`.

### 3. Key Findings
- The identically-shaped construction in `_fetchSeats()` (building
  `_habits` from the initial `/seats` response) was NOT crashing, because
  it's the direct right-hand side of `_habits = rawHabits.map(...).toList()`
  — a context where Dart's inference does correctly propagate the target
  type from the assignment. The `.add()` call inside a `switch` case body
  did not get the same benefit. Both were made explicit
  (`<String, dynamic>{...}`) to remove the ambiguity everywhere this
  pattern occurs, not just at the one crash site.

## Root Cause
A Dart map-literal type-inference edge case: an untyped map literal
containing a mix of scalar and explicitly-typed collection values,
passed as a direct argument inside a `switch` statement's case body,
inferred a narrower type than the calling context required.

## Prevention / Rule
**Guardrail:** Explicitly type every map/list/set literal that will be
stored into a field with a `dynamic`-containing generic type
(`Map<String, dynamic>`, `List<dynamic>`, etc.) rather than relying on
inference — `<String, dynamic>{...}` instead of `{...}`. This is cheap,
removes the ambiguity regardless of the surrounding statement context,
and costs nothing in readability.

Separately: an unhandled exception inside a `StreamSubscription.listen`
callback silently kills that subscription's future event delivery with
no visible symptom. Any future WebSocket message handler should wrap its
body in try/catch and log (or surface) failures, so a bug in handling
one event type doesn't silently disable every other event type sharing
the same connection.

## Solution

### Immediate Fix
Explicitly typed the map literal in the `habit_added` case:
`_habits.add(<String, dynamic>{...})`. Applied the same explicit typing
to the equivalent literal in `_fetchSeats()` as a preventive measure,
since it's the identical pattern even though it wasn't observed to crash.
Verified live on the physical device: adding a protocol now appears
immediately on the dashboard without a manual refresh.

### Long-term Fix
Not done in this pass: wrapping the WebSocket listener's callback body in
try/catch (so a future bug in one event case can't silently kill
delivery of every other event type) is a reasonable follow-up, tracked in
`/home/shadowe/Projects/SharedHQ/DEVLOG.md`.

## Prevention
- [x] Explicitly type the crashing map literal
- [x] Explicitly type the equivalent literal in `_fetchSeats` preventively
- [ ] Wrap the WebSocket message handler in try/catch so one bad event
      can't silently disable all future events on that connection

## Related Issues
- None filed yet.

## References
- `club_zero_mobile/lib/providers/dashboard_provider.dart`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.

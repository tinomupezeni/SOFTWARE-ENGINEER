# `screen_map.py` reports a newly-added Flutter route as still missing until a human also adds a `parity_map.yaml` row — its own route extraction is discarded

**Date:** 2026-11-06
**Project:** HBEC
**Environment:** Development working tree
**Severity:** Low/Medium — no incorrect data ships to production, but it
silently defeats the screen map's purpose of reflecting live code, and an
agent following the generated report at face value would re-report a route
that was just built as still missing.
**Status:** Resolved (workaround documented; script behavior not changed)

## Summary
`scripts/parity/screen_map.py` has a working `extract_flutter_routes()` that
correctly parses every `GoRoute(path: '...', ...)` in
`STUDENT/mobile_flutter/lib/core/navigation/router.dart` and resolves each
one's builder widget to its Dart file (verified directly: it found `/terms`
→ `TermsPage` → `STUDENT/mobile_flutter/lib/features/auth/presentation/
pages/terms_page.dart` with no changes needed). But `build_route_tree()`
never calls that extraction to populate a node's `flutter.route`/
`flutter.component` fields for a web route. Instead:

```python
decision = route_decision(parity_map, p)      # looks up parity_map.yaml by web path
flutter_path = decision.get("flutter")        # None unless a row exists there
flutter_comp = flutter_routes.get(flutter_path) if flutter_path else None
```

`flutter_routes` (the live extraction) is only ever used as a lookup table
*keyed by a path `parity_map.yaml` already names* — it is never consulted to
*discover* that a Flutter route exists. So immediately after wiring up
`GoRoute(path: '/terms', ...)` in `router.dart` and building
`terms_page.dart`, running `screen_map.py` still emitted
`flutter: {route: null, component: null}` for the `terms` node, because
`parity_map.yaml` had no `routes:` row for `/terms` yet.

## Symptoms
- Running `python3 scripts/parity/screen_map.py` right after adding the
  `/terms` and `/privacy` `GoRoute`s and their pages still regenerated
  `screen_map_report.md` with those rows unchanged (`flutter.route: null`),
  even though both routes were live, registered and buildable.
- Manually hand-editing `scripts/parity/screen_map.yaml`'s `flutter:` block
  for those two nodes does not survive the next `screen_map.py` run — the
  file is regenerated from scratch each time (`merge_node()` only carries
  forward `status`/`note`, never `flutter.route`/`flutter.component`), so
  the hand edit gets silently discarded on the very next run unless a
  `parity_map.yaml` row is also added in the same pass.

## Environment Details
- **Server/Host:** Local workspace
- **Services Affected:** `scripts/parity/screen_map.py`
  (`build_route_tree()`), `scripts/parity/screen_map.yaml`,
  `STUDENT/mobile_flutter/planning/semantic/screen_map_report.md`.
- **Time First Observed:** 2026-11-06, while closing the `/terms`/`/privacy`
  migration pass: `screen_map.py` was re-run per the migration skill's step
  6 ("re-run it — it re-derives structure and merges your status/note in")
  and the `flutter.route`/`flutter.component` fields a hand-edit had just set
  came back `null`.

## Investigation Steps

### 1. Initial Diagnosis
Ran `screen_map.py`, confirmed via `grep` that the regenerated
`screen_map.yaml` had `flutter: {route: null, component: null}` for both
`terms` and `privacy` despite the Flutter code existing and `flutter analyze`
/ `flutter test` passing against it.

### 2. Root Cause Analysis
Imported the script as a module and called its own internal functions
directly to isolate which stage was failing:
```python
import screen_map as sm
sm.extract_flutter_routes()['/terms']          # -> 'TermsPage'   (correct)
sm.find_flutter_component_file('TermsPage')    # -> the right .dart path (correct)
```
Both of the script's own extraction primitives work perfectly. Reading
`build_route_tree()` line by line showed `flutter_path` is sourced from
`route_decision(parity_map, p).get("flutter")` — i.e. from the **hand-
maintained `parity_map.yaml`**, not from `flutter_routes` (the live
extraction) keyed by the web path. `flutter_routes` is only indexed into
*after* a path is already known, to resolve a component name — it's never
used as "does a Flutter route at this exact path string exist".

### 3. Key Findings
- The script's two halves are inconsistent on purpose-vs-accident: route
  *existence* comes from the hand-maintained decision file, but route
  *component resolution* comes from live code — so adding working Flutter
  code alone is never enough to flip a node from `missing`/`unknown` to
  `built`; a `parity_map.yaml` row must be added in the same pass, and nothing
  in the tool's output says so (it simply looks like the route still isn't
  recognized).
- This is distinct from the already-logged
  `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md` (a
  different script, `web_flutter_parity.py`, blind to nested feature folders
  for a different reason — directory-listing scope, not a cross-file
  dependency).

## Root Cause
`build_route_tree()` treats `parity_map.yaml` as authoritative for whether a
Flutter route exists at all, rather than treating its own
`extract_flutter_routes()` as authoritative for existence and
`parity_map.yaml` as authoritative only for the *decision* (matched/adapted/
missing/web_only) about a route that's already known to exist on both sides.

## Prevention / Rule
**Guardrail:** when closing a migration pass with this skill's step 6, treat
"re-run `screen_map.py`" as necessary but not sufficient for a route node —
**always also add the matching row to `scripts/parity/parity_map.yaml`'s
`routes:` list in the same pass**, and re-run `screen_map.py` once more
afterward so the merge picks up the newly-resolved `flutter.route`/
`flutter.component`. This was already implicitly required by
`web_flutter_parity.py` (it reports an `UNMAPPED` finding for exactly this
case), so the practical rule is: **run `web_flutter_parity.py` until it
reports no findings before trusting `screen_map_report.md`'s flutter column
for a route node** — its `UNMAPPED` output is the signal that
`parity_map.yaml` is still missing the row `screen_map.py` silently depends
on.

The script's own behavior was not changed in this pass (out of scope for a
two-screen migration task) — this entry exists so the next person hitting
the same "`screen_map.yaml` reverted my edit" symptom doesn't re-diagnose it
from scratch.

## Solution

### Immediate Fix
Added the two missing rows to `scripts/parity/parity_map.yaml`:
```yaml
  - web: /terms
    flutter: /terms
    status: matched
  - web: /privacy
    flutter: /privacy
    status: matched
```
Re-ran `screen_map.py`, which then correctly resolved
`flutter.route`/`flutter.component` for both nodes via its own
`extract_flutter_routes()`/`find_flutter_component_file()`. Confirmed
`web_flutter_parity.py` then reports "Parity map matches live code on both
sides. No drift found."

### Long-term Fix
Not applied in this pass. A real fix would have `build_route_tree()` fall
back to `extract_flutter_routes()` keyed by the *same path string* as the
web route when no `parity_map.yaml` row exists yet (treating the live
Flutter route as discovered-but-undecided rather than nonexistent), and only
use `parity_map.yaml` to override the decision/status once a human has
looked at it. Left as a follow-up since it changes shared tooling behavior
beyond this task's scope.

## Prevention
- [ ] Configuration changes needed — the long-term fix described above
      (script change), not done in this pass.
- [ ] Monitoring/alerts to add — not applicable.
- [x] Documentation to update — this entry; the skill's step 6 instructions
      already say to update `parity_map.yaml`, but didn't make clear *why*
      skipping it specifically breaks `screen_map.py`'s own output.
- [ ] Code changes required — none in this pass (workaround only).

## Related Issues
- `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md` —
  same family (parity tooling silently under-reporting live Flutter state),
  different script and different root cause.

## References
- `scripts/parity/screen_map.py` (`build_route_tree`, `route_decision`,
  `extract_flutter_routes`, `merge_node`)
- `scripts/parity/parity_map.yaml`
- `scripts/parity/web_flutter_parity.py` (the `UNMAPPED` finding that
  actually flags the missing row)

---

**Resolved By:** Claude Sonnet 5 (agent session)
**Time to Resolution:** ~15 minutes (diagnosed by importing the script's
own functions directly rather than guessing from its output)

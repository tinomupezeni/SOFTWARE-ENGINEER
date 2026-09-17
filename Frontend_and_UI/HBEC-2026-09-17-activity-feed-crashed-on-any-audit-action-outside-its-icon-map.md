# Admin Dashboard Crashed After Navigating Back From a Deletion — ActivityFeed's Icon Lookup Assumed Every AuditEvent Action Was One of 8 Known Verbs

**Date:** 2026-09-17
**Project:** HBEC
**Environment:** Production
**Severity:** High (whole-page crash on the admin dashboard for any admin whose activity feed included a real, already-existing audit event)
**Status:** Resolved

## Summary
User reported the admin dashboard at `admin.hbca.tech/dashboard` throwing
`TypeError: Cannot read properties of undefined (reading 'icon')` after
deleting some accounts and navigating back to the dashboard. Root cause:
`ActivityFeed.tsx`'s icon lookup (`actionConfig[activity.action]`) only
covers 8 generic verbs (`upload`/`approve`/`reject`/`create`/`update`/`delete`/
`publish`/`config_change`), but real `AuditEvent.action` values on this
account already included entity-specific compound strings —
`"student_deleted"` (from earlier account deletions) and, as of the
previous hour's deploy, `"subject_deleted"`/`"subject_grade_removed"` (from
the new curriculum delete features). None of these are in the 8-item map,
so the lookup returned `undefined`, and the very next line
(`const Icon = config.icon`) threw — taking down the whole Activity Feed
widget and, via the page's error boundary, the entire dashboard route.

## Symptoms
- Browser console: `TypeError: Cannot read properties of undefined (reading
  'icon')` at the built bundle's minified `ActivityFeed` render code,
  caught by a React error boundary.
- Reported directly by the user, immediately after they deleted some
  accounts and returned to `/dashboard`.

## Environment Details
- **Server/Host:** Production (`hbca-vps`, `/opt/hbec`)
- **Services Affected:** `ADMIN/adminFrontend`
  (`src/features/dashboard/components/ActivityFeed.tsx`,
  `src/features/dashboard/types/index.ts`), `ADMIN/adminBackend`
  (`apps/dashboard/views.py::DashboardActivityView`, a related but
  independent cosmetic bug in the same code path)
- **Time First Observed:** 2026-09-17, reported by the user directly,
  within the hour of the curriculum-delete-features deploy that introduced
  two of the three actual crash-triggering values

## Investigation Steps

### 1. Initial Diagnosis
The stack trace pointed at a `.map()` callback inside the built bundle
reading `.icon` off something undefined. Given the timing (right after a
deletion, right after navigating to the dashboard), the Activity Feed
widget — which renders one row per recent `AuditEvent` — was the obvious
first suspect, since deletions are exactly what generate new audit events.

### 2. Root Cause Analysis
Read `ActivityFeed.tsx`:
```ts
const actionConfig: Record<ActivityAction, {...}> = {
  upload: {...}, approve: {...}, reject: {...}, create: {...},
  update: {...}, delete: {...}, publish: {...}, config_change: {...},
};
...
const config = actionConfig[activity.action];
const Icon = config.icon;  // <-- throws when config is undefined
```
`ActivityItem.action` (`types/index.ts`) was typed as `ActivityAction` — the
same narrow 8-value union — which hid the mismatch at compile time: the
type system asserted every real action value was one of those 8, but the
actual data source, `AuditEvent.action` (a free-form `CharField` on the
backend, convention `<entity>_<verb>`), was never actually constrained to
that set. `StudentDeleteView` (built earlier this session) already writes
`action="student_deleted"`; today's new curriculum-delete features added
`"subject_deleted"` and `"subject_grade_removed"`. None of the three match
any of the 8 keys.

### 3. Key Findings
- Confirmed directly against production data post-fix: the account's real
  activity feed already contained 4 `student_deleted` events (from earlier,
  unrelated account deletions) plus the `subject_deleted`/
  `subject_grade_removed` events from this session's own testing — any one
  of these, alone, was enough to crash the page. The bug was latent from
  the moment `student_deleted` was first introduced; it just hadn't been
  triggered by anyone loading the dashboard with such an event in their
  recent-20 window until now.
- A related, independent cosmetic bug in the same code path:
  `DashboardActivityView.get()`'s description-string builder
  (`f"{actor_name} {event.action}d {event.entity_type}"`) assumed every
  action was a bare present-tense verb needing "+d" appended
  (`"create"` → `"created"`). For the newer compound action names, this
  produced garbled text like `"... subject_deletedd subject_family"` —
  not a crash, but a real, visible quality bug in the same widget, from the
  same underlying assumption (a small, fixed, enumerable set of actions)
  no longer holding.

## Root Cause
Two pieces of code — one on each side of the API boundary — encoded the
same now-false assumption that `AuditEvent.action` values come from a
small, fixed, fully-enumerated set, rather than treating it as the
free-form string the model has always declared it to be. The frontend
compounded this by giving `ActivityItem.action` the same narrow type as the
curated filter-button list (`ActivityAction`), so nothing caught the
mismatch until real data hit it in production.

## Prevention / Rule
**Guardrail:** A field whose backend source is a free-form string must
never be typed as a closed union on the frontend just because a curated
subset of it happens to also need a fixed enum (here, the filter buttons).
Split the two: `ActivityItem.action: string` (what the data actually is)
vs. `ActivityAction` (the curated subset the filter UI offers) — now
applied. Any lookup keyed by such a field must have an explicit fallback
for the "not in my curated set" case, not an assumption that every real
value has an entry.

This closes the gap because the fallback (`DEFAULT_ACTION_CONFIG`) makes
every *future* new `AuditEvent.action` value — and there will be more, any
time a new admin-side delete/audit feature is added — safe by construction,
rather than requiring every future action name to be remembered and added
to this one map before it's safe to write that audit event anywhere in the
codebase.

## Solution

### Immediate Fix
- `ADMIN/adminFrontend/src/features/dashboard/types/index.ts` —
  `ActivityItem.action` widened from `ActivityAction` to `string`;
  `ActivityAction` kept as-is, now documented as the curated filter-button
  subset only.
- `ADMIN/adminFrontend/src/features/dashboard/components/ActivityFeed.tsx` —
  new `getActionConfig(action: string)` helper falls back to
  `DEFAULT_ACTION_CONFIG` (a generic `Activity` icon) for anything outside
  the 8-key map; the filter-inclusion check now casts to `ActivityAction`
  at the one place it's genuinely comparing against the curated list.
- `ADMIN/adminBackend/apps/dashboard/views.py::DashboardActivityView` —
  description-building now branches on whether `event.action` contains an
  underscore (a compound, already-descriptive action name) vs. a bare verb,
  humanizing the former instead of appending "+d" + entity_type to it.
- Tests: `ActivityFeed.test.tsx` (new) reproduces the exact crash scenario
  (rendering `subject_deleted`/`subject_grade_removed`/`student_deleted`
  activity items) and asserts no crash; a new backend test asserts the
  description text for a compound action is clean, not garbled.
- Deployed to staging then production; verified against the account's own
  real, previously-crash-causing activity feed data (4 `student_deleted` +
  1 `subject_deleted` event) — all render cleanly, no crash.

### Long-term Fix
None needed beyond the above — the fallback makes this whole bug class
structurally closed, not just this specific instance of it.

## Prevention
- [x] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — none needed; the fix is structural
- [ ] Documentation to update — none beyond the inline comments added at
      both the type definition and the lookup site
- [x] Code changes required — done (see Solution)

## Related Issues
- Introduced by `823790cf` (this session's curriculum delete features,
  which added `subject_deleted`/`subject_grade_removed`) and latent since
  whichever earlier commit first added `student_deleted` to
  `StudentDeleteView`.

## References
- `ADMIN/adminFrontend/src/features/dashboard/components/ActivityFeed.tsx`
- `ADMIN/adminFrontend/src/features/dashboard/types/index.ts`
- `ADMIN/adminBackend/apps/dashboard/views.py::DashboardActivityView`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — diagnosed, fixed, tested, and
deployed to both staging and production within the hour of the user's report

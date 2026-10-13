# STEM Students download buttons permanently disabled - pagination was dead code

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
After switching the STEM Students page to the shared `ReportExportButtons`
component (which disables Excel/CSV/Download PDF when the matching-record
count is zero), all three buttons were permanently greyed out regardless of
how many STEM students existed. The root cause was a pre-existing, latent
bug: the `stem_students` backend action's pagination was dead code (it
never actually paginated), so the response never included a `count` field,
and the frontend's record count silently stayed `0` forever. Fixing it also
closed two other previously-invisible gaps: the page's Prev/Next controls
and a potential infinite loop in the Excel/CSV "export everything" flow.

## Symptoms
- STEM Students page: Excel, CSV, and Download PDF buttons all appeared
  disabled no matter what filters were applied or how many records matched.
- (Not yet user-reported, found during investigation) Clicking Prev/Next on
  the STEM table had no visible effect - the same full dataset rendered
  every time.

## Environment Details
- **Server/Host:** tesc-staging VM, `tesc-backend-1` container
- **Services Affected:** `backend/academic/app_views/student_views.py`
  (`StudentViewSet.stem_students`)
- **Related Components:** `frontend/src/pages/StemStudents.tsx`,
  `frontend/src/components/reports/ReportExportButtons.tsx`
- **Time First Observed:** 2026-10-13, immediately after STEM Students was
  switched from the always-enabled `ExportButtons` component to
  `ReportExportButtons` earlier the same session.

## Investigation Steps

### 1. Initial Diagnosis
Read `ReportExportButtons.tsx`: all three buttons are disabled when
`totalRecords === 0`. `StemStudents.tsx` passes `totalRecords={totalCount}`,
set from `data.count` in `fetchStudents()`.

### 2. Root Cause Analysis
Traced `data.count`'s origin to `stem_students`
(`backend/academic/app_views/student_views.py`). The action calls
`self.paginate_queryset(queryset)`, and only includes a `count` key in its
response via `self.get_paginated_response(...)` *if* that call returns a
page. Checked `StudentViewSet` for a `pagination_class` - none set - then
checked the project-wide DRF settings
(`REST_FRAMEWORK` in `backend/core/settings.py`) for a
`DEFAULT_PAGINATION_CLASS` - also not configured anywhere. With no
pagination class active at any level, `self.paginate_queryset()` always
returns `None`, so every request fell through to the action's final
branch - which returns the **full, unpaginated** queryset with no `count`
key at all, silently ignoring the `page`/`page_size` query params the
frontend was already sending.

Confirmed this with a direct call: requesting `page=1&page_size=10`
returned all ~4,974 matching records in `results`, not 10.

### 3. Key Findings
- This was not a new bug - the dead pagination code predates this session
  entirely. It was invisible before because the STEM page previously used
  `ExportButtons` (a simpler component with no `disabled` logic at all), so
  a stuck-at-zero count never blocked anything visibly.
- The same broken `count` meant the page's Prev/Next controls were already
  non-functional (every "page" request returned everything), independent
  of the button-disabling issue.
- `StemStudents.tsx`'s "export every record" loop
  (`exportData('csv'|'excel')`) terminates on
  `!res.results?.length || all.length >= res.count` - with `res.count`
  always `undefined`, that second condition can never become `true`, so
  the only way the loop could ever stop was `results` becoming empty. Since
  pagination was broken, the first request already returned everything,
  the loop would immediately duplicate the full dataset on every
  subsequent "page," and never see an empty result - an infinite fetch
  loop waiting to happen for any STEM dataset large enough that someone
  actually used the Excel/CSV export. Verified this is fixed by simulating
  the exact export loop after the fix: terminates correctly after 10 pages
  at exactly 4,974 records.
- `specialized_students`/`critical_students` (two sibling actions in the
  same file, same `ExportButtons`-based pages, not touched this session)
  have the identical dead-pagination shape. They don't currently manifest
  the greyed-button symptom since their pages still use the
  non-disabling `ExportButtons` component, but the same infinite-export-
  loop risk and non-functional Prev/Next almost certainly exist there too.

## Root Cause
`StudentViewSet` sets no `pagination_class`, and the project has no
`DEFAULT_PAGINATION_CLASS` configured anywhere in `REST_FRAMEWORK` settings.
`stem_students`'s `self.paginate_queryset()`/`self.get_paginated_response()`
calls were therefore dead code that never executed - every request silently
returned the full queryset with no pagination metadata, including no
`count`.

## Prevention / Rule
**Guardrail:** any DRF `@action` that calls `self.paginate_queryset()`
should be covered by a test asserting the response actually contains
fewer results than the total when `page_size` is smaller than the dataset
- this would fail loudly for dead pagination like this, rather than only
surfacing when a frontend behavior (like a shared button component's
disabled state) happens to expose it. More broadly: a custom action that
needs pagination should paginate explicitly (as fixed here) rather than
relying on `self.paginate_queryset()`, which silently no-ops for any
ViewSet/project without an active pagination class - the silent-no-op is
the dangerous part, not DRF pagination itself.

## Solution

### Immediate Fix
Replaced the dead `self.paginate_queryset()`/`self.get_paginated_response()`
calls in `stem_students` with manual pagination via Django's
`django.core.paginator.Paginator`, ordered by `id` for stable page
boundaries (avoids `UnorderedObjectListWarning` and inconsistent pages).
Scoped to this one action rather than adding a project-wide
`DEFAULT_PAGINATION_CLASS`, to avoid changing behavior for every other
currently-unpaginated endpoint in the app.

```bash
# Verified on staging:
# page=1,page_size=10 -> count=4974, 10 results (was: count missing, all 4974 returned)
# page=1 vs page=2 (page_size=5) -> disjoint id sets, no UnorderedObjectListWarning
# simulated full export loop -> terminates after 10 pages at exactly 4974 records
```

### Long-term Fix
Apply the same fix to `specialized_students` and `critical_students`,
which share the identical dead-pagination code shape - not done in this
pass since neither page currently surfaces a user-visible symptom, but the
underlying infinite-export-loop risk is real for both.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — none specific.
- [ ] Documentation to update — none.
- [x] Code changes required — done for `stem_students`; `specialized_students`/
      `critical_students` deferred (see Long-term Fix).

## Related Issues
- Exposed by [[TESC-2026-10-13-stem-download-pdf-and-staff-stem-filter-expansion]]
  — switching STEM Students to `ReportExportButtons` (which disables on
  zero records) is what made this latent bug user-visible.

## References
- `backend/academic/app_views/student_views.py`
- `backend/core/settings.py` (`REST_FRAMEWORK`)
- `frontend/src/pages/StemStudents.tsx`
- `frontend/src/components/reports/ReportExportButtons.tsx`
- Commit: `c167d51` on `staging`.

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~30 minutes

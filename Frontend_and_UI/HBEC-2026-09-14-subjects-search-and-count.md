# Search and Live Subject Count on /subjects

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** N/A (feature, not a bug)
**Status:** Resolved — verified live on staging

## Summary
Two small additions to the subject-first `/subjects` page: a search box
(filters the list by subject name, case-insensitive) and a subject count
in the header, reflecting whatever combination of search/grade/level
filters is currently applied (shows "N of M" once any filter actually
narrows the list, just "N subjects" otherwise).

## Solution
`SubjectFamilyListPage.tsx` — `visibleFamilies`'s existing grade/level
filter `useMemo` gained a name-substring check ahead of the existing
offering-based checks; a local `searchQuery` state (not a URL param,
unlike board/grade/level — free-text search is ephemeral, not something
worth making shareable/bookmarkable the way the other filters are) feeds
it. The count line reuses `visibleFamilies.length` directly, so it's
always in sync with whatever's actually showing.

## Testing
5 new tests (`SubjectFamilyListPage.test.tsx`, the page's first test
file): shows the total count, filters by search query, shows an "N of M"
count while a filter is narrowing the list, shows the existing
empty-filter message when a search matches nothing, search is
case-insensitive. Needed a `QueryClientProvider` wrapper in the test
setup — the page always mounts `SubjectForm`/`GradeManagementModal`
(gated by their own `open` prop, not by conditional rendering), both of
which call TanStack Query hooks regardless of whether their dialog is
currently open. Full suite (145 tests, up from 140) passes;
`typecheck`/`eslint` clean.

## Deployment
Staging only, per the running instruction for this work session;
production untouched (confirmed via image inspection: still running the
prior commit's build). Full staging host health sweep clean after
deploy.

## References
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectFamilyListPage.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectFamilyListPage.test.tsx` (new)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — implemented, tested, deployed to
staging only

# Retired the Board → Grade → Subject Drill-Down; /subjects Is Now the One Place to Browse and Manage

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** N/A (architecture change, not a bug)
**Status:** Resolved — verified live on staging

## Summary
`/exam-boards` had two jobs tangled together: board CRUD (its own list
page was already close to pure CRUD) and, one click in, a "Grades"
section that drove a full Board → Grade → Subject drill-down
(`ExamBoardDashboardPage` → `GradePage` → `SubjectPage`). Meanwhile
`/subjects` already existed as a subject-first browsing view with a
grade filter. Consolidated: `/exam-boards` is now board metadata/status
only, the drill-down's `GradePage` route and file are gone, and
`/subjects` picked up what that drill-down was doing — plus a level
filter and Grade management it didn't have before.

## What changed
- `ExamBoardDashboardPage.tsx` — removed the "Grades" section (grade
  list + "Add Grade") entirely; replaced with a "Manage Subjects &
  Grades" quick-action link into `/subjects?board=<id>`.
- `App.tsx` — removed the `/exam-boards/:boardId/grades/:gradeId` route;
  deleted `GradePage.tsx` (its only route, and only two entry points —
  the board dashboard's grade cards and its own subject-card links —
  both gone with it).
- `SubjectFamilyListPage.tsx` (`/subjects`) — added a Level filter
  (phase: Primary/O-Level/AS-Level/A-Level/IGCSE/Other) alongside the
  existing Grade filter, and a new "Manage Grades" button opening
  `GradeManagementModal.tsx` (new) — add/edit/delete Grades for the
  selected board, delete guarded the same way it was on the old
  `GradePage` (disabled while the grade still has subjects offered at
  it).
- `SubjectPage.tsx` (topics/content/pillars for one grade offering) is
  **unaffected functionally** — still reached from `/subjects`' grade
  chips and the Dashboard's Content Coverage widget, neither of which
  ever depended on `GradePage`. Only its breadcrumb and post-delete
  redirect, which used to point at the now-removed `GradePage` route,
  now point at `/subjects?board=...&grade=...` instead.

## Investigation before changing anything
A background research pass confirmed the exact reachability graph before
any route was touched: `SubjectPage` had three independent entry points
(`GradePage`'s subject cards, `/subjects`' grade chips, and the
Dashboard's `ContentCoverageCard`) — only the first depended on
`GradePage`, so removing that route was safe for the other two. It also
surfaced the one real blocker: Grade CRUD (add/edit/delete a Grade) only
ever existed on the board-detail Grades section — nothing else in the
app could create a new grade — so that had to get a new home
(`GradeManagementModal` on `/subjects`) before the old one could be
removed, or admins would have lost the ability to add grades entirely.

## Testing
6 new tests (`GradeManagementModal.test.tsx`): grades list grouped by
phase, empty state, Add Grade opens the create form, editing an existing
grade pre-fills the form, delete is disabled while the grade has
subjects, and the delete confirmation flow calls the mutation with the
right id. Full suite (129 tests, up from 123) passes;
`typecheck`/`eslint` clean.

## Deployment
Staging only, per explicit instruction — production was not touched.
Verified: staging's built bundle contains the new "Manage Grades"/"All
levels" strings; confirmed via direct image inspection that production
is still running the previous commit's image, untouched. Full staging
host health sweep clean after deploy.

## References
- `ADMIN/adminFrontend/src/App.tsx`
- `ADMIN/adminFrontend/src/features/exam-boards/pages/ExamBoardDashboardPage.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectFamilyListPage.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectPage.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/components/GradeManagementModal.tsx` (new)
- Deleted: `ADMIN/adminFrontend/src/features/curriculum/pages/GradePage.tsx`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — researched, designed (user
confirmed the recommendation), implemented, tested, and deployed to
staging only in one pass

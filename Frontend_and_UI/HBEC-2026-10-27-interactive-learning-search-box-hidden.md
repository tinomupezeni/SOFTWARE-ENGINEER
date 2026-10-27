# Interactive Learning "Search" Box Invisible When a Subject Has No Grouped Lessons

**Date:** 2026-10-27
**Project:** HBEC
**Environment:** Production
**Severity:** Medium (Feature Undiscoverable)
**Status:** Resolved

## Summary
Reported by Mutsa in the HBCA ProjectFlow channel (2026-10-14): "I checked
this and the explore function is the only one that's working ... and as for
search I could not locate the search bar." The interactive-learning page's
"explore" section (3D visuals/labs) rendered fine, but its lesson search box
was nowhere on screen.

## Symptoms
- On `SubjectVisualsPage` (the interactive-learning subject view), the search
  input for that subject's lessons simply does not appear for some subjects,
  with no error and no alternative way to search.
- Labs and 3D visuals ("explore") on the same page render normally regardless.

## Root Cause
`STUDENT/Frontend/src/features/interactive-learning/pages/SubjectVisualsPage.tsx:120`
gated the search `<input>` itself behind `groups.length > 0` — i.e. the box
only rendered when the subject already had lessons grouped under syllabus
topics. But the actual search (`useLessonSearch`, line 52) is an independent
lookup (`fetchLessons`) that has nothing to do with `groups`. For any subject
whose topic-grouped lessons are currently empty — sparse/new content, not yet
curated — the search box vanished entirely, even though searching could
still have surfaced results.

## Solution
Changed the search box's render condition from
`!loading && answer && groups.length > 0` to `!loading && answer`, so it
shows whenever lesson data has loaded, independent of whether any
topic-grouped lessons currently exist. The existing "no lessons yet" empty
state (line 184-188) and the normal topic listing (still gated on
`groups.length > 0`, correctly) were unaffected.

Verified with the existing `SubjectVisualsPage.labs.test.tsx` and
`SubjectVisualsPage.lessons.test.tsx` suites (13 tests passing) and
`tsc --noEmit`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (render-condition fix in `SubjectVisualsPage.tsx`)

---

**Resolved By:** Tinotenda Mupezeni (with Claude Code)
**Time to Resolution:** ~25 minutes

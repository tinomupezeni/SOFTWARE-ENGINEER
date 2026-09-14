# Five Duplicate Secondary Subject Families Merged on Staging

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** Low (data quality, not a bug)
**Status:** Resolved — verified live on staging

## Summary
Follow-up to the primary-subject dedup/backfill done earlier the same
session: the same wording-drift duplicate pattern (flagged then as
existing "much more broadly across this board's secondary subjects too
... a dedicated pass if it becomes a real problem") was addressed for
the four secondary pairs/trios already identified:

- "Family and Religious Studies" (Form 3 only) vs "Family and Religious
  Studies (FRS)" (Forms 1, 2, 4, 5) — same subject, code root `4047`.
- "Musical Art" (Form 3) vs "Musical Arts" (Form 4) — code root `4062`.
- Three PESMD variants — "Physical Education, Sport & Mass Displays
  (PESMD)" (Form 2), "...Sport and Mass Displays..." (Form 1), "...Sports
  and Mass Displays..." (Forms 3, 4) — code root `4002`.
- "SHONA LANGUAGE" (Forms 2, 3, 4, 5, 6) vs "Shona Language (ChiShona)"
  (Form 1) — code root `4007`.

Each pair/trio confirmed as the same real subject by matching numeric
code roots before touching anything (same verification method used for
the primary duplicates).

## Solution
For each group, the family with the most existing grade offerings was
kept canonical (minimizes rows moved); the minority grade's `Subject`
row was re-pointed to it via the real `PATCH /api/curriculum/subjects/{id}/`
endpoint (not raw ORM), then the now-empty duplicate family deleted via
`DELETE /api/curriculum/subject-families/{id}/`. "SHONA LANGUAGE" (the
survivor, since it had 5 offerings vs. 1) was renamed to Title Case
("Shona Language (ChiShona)") afterward using the subject-name-edit
feature built earlier this session, for consistency with the rest of
the curriculum's naming.

Board's total `SubjectFamily` count: 53 → 48.

## Scope note
This is NOT a blanket "backfill every secondary subject to every form"
pass — unlike primary, secondary subject-to-form mapping genuinely
varies (electives, O-Level-only vs. continuing to A-Level, etc.), so
expanding grade coverage beyond what the merge itself naturally revealed
would be guessing at real curriculum structure without a reliable
signal. Only the identified duplicate pairs were touched; no new grade
offerings were speculatively added for secondary subjects.

## Deployment
No code changes — this was pure data cleanup via the existing,
already-deployed API (subject reassignment + family delete + rename, all
endpoints that existed before this session). Staging only, per the
running instruction for this work session; production database
untouched.

## References
- Related: `HBEC-2026-09-14-legacy-subject-code-constraint-blocked-primary-band-codes.md`
  (same session, same dedup method, primary subjects)
- `ADMIN/adminBackend/apps/curriculum/views.py` — `SubjectDetailView`,
  `SubjectFamilyDetailView` (both pre-existing, used as-is)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — verified each pair by matching
codes, merged via the real API, renamed for consistency

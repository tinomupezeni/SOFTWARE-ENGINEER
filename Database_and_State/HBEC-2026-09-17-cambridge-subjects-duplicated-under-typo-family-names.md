# Cambridge Subjects Silently Duplicated Under Typo'd Subject-Family Names — No De-Duplication Check Anywhere in the Stack

**Date:** 2026-09-17
**Project:** HBEC
**Environment:** Production
**Severity:** Medium (no user-facing incident — found via a routine dashboard lookup — but real curriculum-catalog pollution with a confirmed structural cause)
**Status:** Resolved (the 5 empty duplicate rows found this session removed; root cause not fixed — see Prevention)

## Summary
Asked to look up four CAIE (Cambridge) subjects on production (Divinity, ICT,
Humanities, Environmental Management), two turned out to not exist under
their correct names at all — they were filed under a **typo'd
`SubjectFamily`** instead, invisible to anyone searching or filtering by the
correct spelling:

- **"Humanites"** (missing an "i") — no "Humanities" family exists at all.
- **"Enviromental Management"** (missing an "n") — exists *alongside* the
  correctly-spelled "Environmental Management" family, which already has
  real, published syllabus content for Form 3/4/5. The typo'd twin had one
  extra, syllabus-less Form 5 offering.

Separately, **ICT** turned out to be split across **three** distinct
`SubjectFamily` rows that all represent the same real-world subject — "ICT",
"Information and Communication Technology", and "Information Technology" —
with overlapping/near-duplicate codes (`0417` vs `0417-1`, `9626` vs
`9626-5`) and syllabus coverage scattered unevenly across the three.

All 5 of the specifically-flagged rows (2 Divinity offerings, the literal
"ICT" family's one offering, the "Humanites" offering, and the typo'd
"Enviromental Management" offering) were confirmed to have **zero** topics,
zero content, and zero exam papers before deletion — genuinely empty,
duplicate-name entries with nothing to lose. Deleted along with their now-
empty parent `SubjectFamily` rows; verified the deletion replicated
correctly to the student backend.

## Symptoms
- A subject a user expects to exist under its correct name (e.g.
  "Humanities") returns nothing when searched/filtered by that name, because
  the data lives under a differently-spelled family instead.
- The Syllabus Coverage dashboard widget (built the previous session) shows
  two separate rows for what's conceptually one subject (e.g. "Environmental
  Management" and "Enviromental Management" both appearing), each with its
  own coverage status — confusing without knowing the typo is the cause.

## Environment Details
- **Server/Host:** Production (`hbca-vps`, `/opt/hbec`)
- **Services Affected:** `ADMIN/adminBackend` (`apps.curriculum.models.SubjectFamily`,
  `Subject`), replicated downstream to `STUDENT/hbec_backend`
- **Time First Observed:** 2026-09-17, during a routine subject lookup
  requested directly by the user

## Investigation Steps

### 1. Initial Diagnosis
A direct Django-shell query for `SubjectFamily` rows matching "Divinity",
"ICT", "Humanities", "Environmental Management" under the CAIE exam board
returned no match for "Humanities" at all. Widening to `name__icontains`
found nothing closer than "Humanites". Listing every CAIE `SubjectFamily`
name directly (`SubjectFamily.objects.filter(exam_board=board).order_by('name')`)
surfaced both the "Humanites"/"Environmental Management" typo pairs and the
three-way ICT split in one pass.

### 2. Root Cause Analysis
Checked `SubjectFamily`'s uniqueness constraint
(`apps/curriculum/models.py`): `UniqueConstraint(Lower("name"), "exam_board")`
prevents two families with the *exact same* (case-insensitive) name under
one board — but does nothing for a genuinely different string that's a typo
of an existing one. There is no fuzzy-match warning, no autocomplete-against-
existing-families prompt, and no admin-side review step that would have
caught "Enviromental" as a likely typo of an existing "Environmental" family
at creation time.

### 3. Key Findings
- Confirmed via `Topic.objects.filter(subject=s).count()`,
  `Content.objects.filter(subject=s).count()`, and
  `ExamPaper.objects.filter(subject=s).count()` that all 5 targeted rows
  were completely empty — this was pure duplicate-entry pollution, not a
  case of content living on the "wrong" row.
- `apps/curriculum/management/commands/merge_duplicate_subjects.py` already
  exists as precedent for a narrower version of this exact bug shape (double-
  entered `Subject.code` values differing only by a trailing `-5`/`-6`
  fragment) — confirms this general class of duplicate-entry bug has
  happened before, just not previously via a misspelled family name.
- `Subject`'s `post_delete` signal (`apps/replication/signals.py:244`)
  correctly fires a replication deletion event on delete — confirmed the 5
  deletions propagated to the student backend's `Subject` table (all 5
  codes absent there post-deploy), so no orphaned replicated data was left
  behind.

## Root Cause
Nothing in the `SubjectFamily` creation path (admin frontend form, backend
serializer, DB constraint, or replication signal) checks a new family name
against existing ones for anything beyond exact (case-insensitive) equality
— a typo creates a brand-new, fully independent family rather than being
caught or flagged as a likely duplicate of an existing one.

## Prevention / Rule
**Guardrail:** None implemented yet — this entry documents a found-and-fixed
instance, not a structural fix. The two real options going forward:
1. A lightweight fuzzy-match check in the "Create Subject Family" flow
   (Levenshtein distance or similar against existing family names for the
   same exam board), surfacing a "did you mean 'Environmental Management'?"
   confirmation before creating a new family that's suspiciously close to an
   existing one.
2. A periodic audit script (could reuse `merge_duplicate_subjects.py`'s
   general shape) that flags `SubjectFamily` name pairs within a small edit
   distance of each other for human review, rather than trying to prevent
   the typo at entry time.

Neither is implemented — flagging as a real gap rather than closing it, since
building either is more than this session's lookup-and-cleanup scope
warranted.

## Solution

### Immediate Fix
Deleted the 5 confirmed-empty duplicate `Subject` rows and their 4 resulting
empty `SubjectFamily` rows directly via Django shell on production, inside
one transaction, after confirming zero topics/content/exam-papers on each:
- Divinity — Form 5 (`9011-5`), Form 6 (`9011`)
- ICT (the literally-named "ICT" family only — leaving "Information and
  Communication Technology" and "Information Technology," which have real
  published syllabus content, untouched) — Form 4 (`0417`)
- "Humanites" (typo) — Grade 6 (`0065`)
- "Enviromental Management" (typo) — Form 5 (`8291-5`)

Verified: the correctly-spelled/real-content families (Environmental
Management Form 3/4/5, Information Technology, Information and
Communication Technology) are untouched; the replication `post_delete`
signal fired for all 5 (`Outbox queued subject.deleted: <code>` logged for
each); the student backend no longer has any of the 5 deleted codes.

### Long-term Fix
Not done this session — see Prevention/Rule above. The ICT three-way split
specifically still needs a human-judgment merge decision (which family
survives, how to reconcile the differently-coded Form 4/5 offerings) rather
than a mechanical delete, since two of the three families have real content.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — a periodic fuzzy-duplicate-family scan
      (see Prevention/Rule option 2) would have caught this proactively
- [ ] Documentation to update — none yet
- [ ] Code changes required — the fuzzy-match-on-create check (Prevention/Rule
      option 1) is the durable fix; not built this session

## Related Issues
- `apps/curriculum/management/commands/merge_duplicate_subjects.py` — prior,
  narrower precedent for the same general bug class (duplicate Subject
  entries from free-text data entry with no dedup check)
- The ICT three-way split (not yet resolved) is a natural follow-up once a
  human decides which of the three families should be the merge target

## References
- `ADMIN/adminBackend/apps/curriculum/models.py` — `SubjectFamily`,
  `Subject`, the `Lower(name)+exam_board` uniqueness constraint
- `ADMIN/adminBackend/apps/replication/signals.py:244` — `on_subject_delete`
- `ADMIN/adminBackend/apps/curriculum/management/commands/merge_duplicate_subjects.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — found via a routine lookup, verified
empty, and cleaned up within the hour; root-cause guardrail left open

# Cambridge Subjects Silently Duplicated Under Typo'd/Reordered Subject-Family Names — No De-Duplication Check Anywhere in the Stack

**Date:** 2026-09-17
**Project:** HBEC
**Environment:** Production
**Severity:** Medium (no user-facing incident — found via a routine dashboard lookup — but real curriculum-catalog pollution with a confirmed structural cause)
**Status:** Resolved (13 empty duplicate rows found across two rounds this
session removed; the twin families holding real content were deliberately
left alone; root cause not fixed — see Prevention)

## Summary
Asked to look up seven CAIE (Cambridge) subjects on production for deletion
(Divinity, ICT, Humanities, Environmental Management, Combined Science,
English as a Second Language, First Language English), several turned out
to not exist under their correct/expected names at all — they were filed
under a **typo'd or reordered `SubjectFamily`** instead, invisible to
anyone searching or filtering by the expected name:

- **"Humanites"** (missing an "i") — no "Humanities" family exists at all.
- **"Enviromental Management"** (missing an "n") — exists *alongside* the
  correctly-spelled "Environmental Management" family, which already has
  real, published syllabus content for Form 3/4/5.
- **"Science-Combined"** (word order swapped) — exists *alongside* "Combined
  Science", and has real published syllabus content for Form 3/4.
- **"English (First Language)"** (different naming convention) — exists
  *alongside* "First Language English", and has real published syllabus
  content for Form 3/4.
- **ICT** is split across **three** distinct `SubjectFamily` rows that all
  represent the same real-world subject — "ICT", "Information and
  Communication Technology", and "Information Technology" — with
  overlapping/near-duplicate codes (`0417` vs `0417-1`, `9626` vs `9626-5`).

In every pair above, only the literally-named family the user specified was
deleted — the differently-named twin holding real syllabus content was
deliberately left untouched, confirmed with the user first given the very
different stakes (destroying real content vs. removing empty duplicates).
13 confirmed-empty `Subject` rows were deleted across two rounds, along with
their now-empty parent `SubjectFamily` rows; one row a first-pass check
missed (a real published past-paper document on "First Language English"
Form 4) was caught by a second, independent pre-delete check and excluded
from deletion. Every deletion's replication to the student backend was
verified.

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
  `ExamPaper.objects.filter(subject=s).count()` that all 5 Round-1 targeted
  rows were completely empty — this was pure duplicate-entry pollution, not
  a case of content living on the "wrong" row.
- The same duplicate-name pattern recurred at larger scale in Round 2:
  "Combined Science" (empty) vs. "Science-Combined" (has a published
  syllabus for Form 3/4), and "First Language English" (mostly empty) vs.
  "English (First Language)" (has a published syllabus for Form 3/4) — two
  more pairs of the exact same typo/reordering-duplication bug, this time a
  word-order swap and a punctuation/ordering variant rather than a
  misspelling.
- Round 2's own investigation step repeated a subtler version of the same
  mistake this bug class causes: it checked "does this row have a
  **published syllabus**" (matching the session's dashboard-driven framing)
  rather than "does this row have **any** Content row at all" — which
  missed a real published *past-paper* document on one row. Caught only
  because a second, independent check (a pre-delete assertion inside the
  same transaction) re-verified emptiness immediately before deleting,
  rather than trusting the earlier read. No data was lost.
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
Deleted 13 confirmed-empty duplicate `Subject` rows across two rounds,
directly via Django shell on production, inside a transaction each time,
after confirming zero topics/exam-papers/**Content (all types and
statuses, not just published syllabi)** on every row:

**Round 1** — Divinity, ICT, Humanites, Enviromental Management:
- Divinity — Form 5 (`9011-5`), Form 6 (`9011`)
- ICT (the literally-named "ICT" family only — leaving "Information and
  Communication Technology" and "Information Technology," which have real
  published syllabus content, untouched) — Form 4 (`0417`)
- "Humanites" (typo) — Grade 6 (`0065`)
- "Enviromental Management" (typo) — Form 5 (`8291-5`)
- Their 4 now-empty parent `SubjectFamily` rows also deleted.

**Round 2** — Combined Science, English as a Second Language, First
Language English (again literal-name families only — "Science-Combined"
and "English (First Language)," both of which have real published
syllabus content for Form 3/4, were deliberately left untouched):
- Combined Science — Form 3 (`0653-3`), Form 4 (`0653`)
- English as a Second Language — Form 1 (`0876-1`), Form 3 (`0510-3`),
  Form 4 (`0510`), Grade 1 (`0057-1`), Grade 6 (`0057`)
- First Language English — Form 3 (`0500-3`) only. **Form 4 (`0500`) was
  deliberately excluded** — see Key Findings below.
- Combined Science and English as a Second Language's now-empty parent
  families deleted; First Language English's family was correctly left
  alone (still has 1 real offering).

A pre-delete assertion (re-checking `subject.contents.count() == 0` inside
the same transaction, immediately before calling `.delete()`) caught a real
miss in Round 2's read-only investigation: "First Language English" Form 4
(`0500`) has one **published `past_paper`-type `Content` row** ("FIRST
LANGUAGE ENGLISH Paper 2 — Directed Writing and Composition," created
2026-09-10) that the investigation step had missed, because that step only
checked for published **syllabus**-type content (matching the session's
running "does it have a syllabus" framing) rather than *any* Content row
regardless of type/status. The assertion raised, the whole transaction
rolled back with zero rows touched, and the user was asked how to handle
that one row specifically before re-running with it excluded.

Verified after both rounds: every correctly-spelled/real-content family
(Environmental Management, Information Technology, Information and
Communication Technology, Science-Combined, English (First Language))
is untouched; the replication `post_delete` signal fired for all 13
deleted codes (`Outbox queued subject.deleted: <code>` logged each time);
the student backend no longer has any of the 13 deleted codes; First
Language English Form 4 (`0500`) and its past-paper document are still
present on both sides.

### Long-term Fix
Not done this session — see Prevention/Rule above. The ICT three-way split,
and now the Combined Science / "Science-Combined" and First Language
English / "English (First Language)" pairs, still need a human-judgment
merge decision (which family survives, how to reconcile the differently-
coded offerings) rather than a mechanical delete, since each pair has a twin
with real content.

**Process guardrail worth carrying forward regardless of the fuzzy-match
fix:** when auditing a `Subject` row as "safe to delete," check for *any*
`Content` row (`Content.objects.filter(subject=s).count()`), not just a
published syllabus — a subject can hold real, published, non-syllabus
material (a past paper, a worked solution, etc.) that a syllabus-scoped
check will miss entirely. This session's read-only investigation missed
exactly that on one row; only a second, independent re-check immediately
before the actual delete (inside the same transaction, asserting emptiness
again right before `.delete()`) caught it before any data was lost. Treat
that double-check as the standard shape for any future "delete these
subjects" cleanup, not a one-off precaution.

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

# `Person.guarantor_id` Is a Proper FK But `Person.next_of_kin_phone` Is a Bare String — Two Similar Concepts, Two Different Models

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Low
**Status:** Resolved (as a documentation fix — see Solution)

## Summary
`Person` has two fields for "a contact who vouches for or is tied to this
person": `guarantor_id` (a proper self-referential foreign key to another
`Person`) and `next_of_kin_phone` (a bare `VARCHAR(20)` phone string with
no link to a `Person` row, even when that next of kin happens to also be a
registered platform user). Both appear together in the PRD's description
of `Person` ("guarantor, next of kin, role") with no stated reason they
should be modeled differently.

## Symptoms
- `app/models.py`:
  ```python
  guarantor_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("persons.id"))
  next_of_kin_phone: Mapped[str | None] = mapped_column(String(20))
  ```
- If a worker's next of kin is themselves a registered buyer/worker on the
  platform, their phone number is duplicated as a disconnected string
  rather than referenced — no referential integrity, and if that person's
  own `phone` ever changed (no endpoint currently allows this, but the
  column has no such constraint preventing a future one from doing so
  without a cascade), `next_of_kin_phone` would silently go stale.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/models.py` (`Person`)
- **Time First Observed:** 2026-09-11, DB normalization review requested
  directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Compared the two "related contact" fields on `Person` side by side while
reviewing normalization.

### 2. Root Cause Analysis
No documentation anywhere (`prd.md`, `database_schema_design.md`) explains
*why* one is a link and the other isn't. It's plausible this is
intentional — a next of kin is very likely to *not* be a platform user
(a family member who never signs up), in which case a plain phone string
is the objectively correct model and this isn't a bug at all, just an
under-documented design choice. But `guarantor_id` being a strict FK
implies guarantors are *always* expected to be registered persons, which
raises the question of whether that's actually enforced anywhere or just
assumed.

### 3. Key Findings
- No endpoint in the current API sets or reads either field at all (`grep`
  for `guarantor_id`/`next_of_kin_phone` outside `models.py` turns up
  nothing) — both are currently fully dead columns, populated by nobody.
  This softens the severity: it's a modeling inconsistency in dormant
  columns, not an active data-integrity bug in production behavior today.

## Root Cause
Undocumented, possibly-intentional design choice that was never confirmed
or written down, discovered only by comparing two fields that look like
they should be symmetric.

## Prevention / Rule
**Guardrail:** A schema-review checklist rule: any two fields that appear symmetric in the requirements doc (here, the PRD's "guarantor, next of kin" phrasing) but are modeled asymmetrically in the schema must have that asymmetry explicitly justified in the design doc before merge — silence about *why* two similar-looking fields differ is itself the defect, independent of whether the asymmetry turns out to be correct.

This is precisely what closed this finding: the asymmetry was fine, but nothing had ever written down why until this review forced the question.

## Solution

### Immediate Fix
Put the three options (document-only, add `next_of_kin_id` alongside the
phone, or replace the phone with an FK matching `guarantor_id`) to the
user. Answer: **document only, keep the asymmetry** — both columns are
still fully dormant (no endpoint reads or writes either), so adding
schema surface (a new FK column) for a workflow that doesn't exist yet
would be speculative; the actual bug here was that the reasoning for the
asymmetry was never written down, not that the asymmetry itself was
wrong.

Applied, same day, to `docs/architecture/database_schema_design.md`:
- §2 "Normalization & Constraints" gets a new numbered item (§2.8)
  explaining exactly why `guarantor_id` is a strict FK (a guarantor is
  expected to be a registered person) while `next_of_kin_phone` is a bare
  string (a next of kin is expected to often *not* be a platform user, so
  a hard FK would force an unnecessary registration) — and notes both are
  currently dormant.
- The §1 ERD's `PERSONS` entity annotates both fields inline
  (`next_of_kin_phone "not an FK: usually not a platform user, see
  §2.8"`, `guarantor_id FK "nullable, expected to be a registered
  person"`) so a reader scanning the diagram alone still gets the intent
  without needing to cross-reference.

No code or schema change: both columns are untouched, since nothing
reads or writes them yet — there was no data-integrity bug in the
running system to fix, only an undocumented design choice.

### Long-term Fix
Done, as documentation. If a future workflow needs to link a next of kin
who is also a registered platform user, that's the point to revisit
adding `next_of_kin_id` — not before, per the user's decision.

## Prevention
- [x] Documented the intended semantics of both fields in
  `database_schema_design.md` §2.8 and the ERD
- [x] Confirmed (with the user) that the current asymmetry is correct as
  designed, not a gap needing a schema change

## Related Issues
- Both fields are currently unused by any endpoint — related in spirit to
  the Standing-never-recomputed finding (documented-but-unbuilt PRD
  concepts)

## References
- `docs/requirements/prd.md` §2 — "Person: ID, phone, guarantor, next of
  kin, role"

---

**Resolved By:** Claude Code (architecture-review-to-fixes session), design
decision confirmed by the user
**Time to Resolution:** Same day, follow-up session

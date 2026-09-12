# Bulk Import Had No Path for "Just a Folder of PDFs" — Only Metadata-Only CSV/JSON or a Hand-Built ZIP+Manifest

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Fixed, deployed to staging

## Summary
User asked to fix bulk import for "not a zipped just a clean folder" of
exam papers, right after successfully testing the single-paper Upload flow
(`2026-09-11-new-paper-upload-fully-built-but-unreachable-in-admin-ui.md`).
Looked at the existing Bulk Import dialog and found a real gap: it offered
three formats — CSV, JSON, ZIP — and none of them fit "I have a folder of
PDFs on disk."

- **CSV/JSON**: metadata-only. Every row needs `exam_board`, `subject`,
  `title` at minimum; there's no way to attach a file at all, so these
  formats create draft papers with nothing to extract.
- **ZIP**: does carry PDFs, but requires a hand-written `manifest.json`
  inside the archive naming each paper's metadata and which file belongs
  to it (`ADMIN/adminBackend/apps/exam_papers/bulk_import.py`'s own
  docstring: "Lets a curator ship papers and metadata in one upload" — but
  the metadata has to be authored by hand first).

A curator who has just downloaded a folder of real past papers has neither
a spreadsheet nor a manifest — just files, one exam board and subject for
the whole folder (a folder is almost always "all of subject X's papers"),
and a title/year/session/paper-number a sane filename like
`Mathematics Paper 1 June 2014.pdf` already spells out.

## Prevention / Rule
**Guardrail:** Before marking any import/creation feature complete, write
down the realistic "how does a real user actually have this data" input
shapes as an explicit checklist and validate the feature against each one —
not just the shapes that map cleanly onto the existing data model (rows
with metadata) but the shape the feature's actual users will show up with.

A folder of files with no manifest is the default shape for anyone who
just downloaded past papers — the gap here wasn't a bug in the existing
CSV/JSON/ZIP paths, it was that the checklist of supported shapes was
never checked against how a real curator's files actually arrive.

## Solution

### Immediate Fix
Added a fourth path, independent of the CSV/JSON/ZIP row-based format:

**Backend** (`ADMIN/adminBackend/apps/exam_papers/bulk_import.py`):
- `infer_paper_fields_from_filename(filename)` — regex-based, never
  raises. Pulls a year (`\b(19|20)\d{2}\b`), a session (keyword-matched
  against the same slugs `apps.system_settings` already uses:
  `january`/`feb_march`/`may_june`/`oct_november`/`specimen`), and a paper
  number (`paper 1`, `p1`, etc., defaulting to `1`). Falls back to the
  cleaned, title-cased filename itself when nothing else can be inferred
  — a file is never rejected just for having an unparseable name.
- `import_pdf_files(files, exam_board_id, subject_id, created_by)` — one
  exam board/subject for the whole batch (resolved once, a whole-batch
  failure if either doesn't exist, since unlike a CSV row there's no
  per-file board/subject to fall back to), builds one `ExamPaper` per file
  with the inferred fields, attaches the file, and runs it through the
  same `launch_ingestion_pipeline()` every other creation path uses —
  extraction, marking-scheme attach and publish all happen on their own,
  no different from a single manual upload.
- New endpoint: `POST /api/exam-practice/bulk-import-pdfs/`
  (`BulkImportPdfsView`), accepting multiple `files` + `examBoardId` +
  `subjectId` as multipart form data — distinct from the existing
  single-`file` `/bulk-import/` endpoint rather than overloading its
  contract.

**Frontend** (`BulkImportDialog.tsx`): a fourth "PDF Folder" tab with an
exam board/subject picker (mirrors the picker pattern already built for
the single-paper create dialog) and a file input using the
`webkitdirectory` attribute, so clicking "Browse Folder" opens an actual
folder picker in the browser rather than a one-at-a-time file select.
Non-PDF files a folder might also contain (a stray `.docx`, a
`Desktop.ini`) are filtered out client-side before upload.

7 new backend tests in `test_bulk_import.py` (filename inference, an
unparseable-name fallback, whole-batch board/subject validation, chain
dispatch per file) — 27/27 passing in that file, 131/131 across
`apps/exam_papers/`. Frontend typecheck and lint clean (component itself
has zero warnings; the two pages it touches have only pre-existing
unrelated warnings).

### Long-term Fix
None needed — this closes the gap the user identified without touching
the existing CSV/JSON/ZIP paths, which stay exactly as they were for
curators who do have metadata to hand.

## Prevention
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a, the dialog's own tab describes the
      behavior inline
- [ ] Code changes required — done

## Related Issues
- Same investigation thread as
  `2026-09-11-new-paper-upload-fully-built-but-unreachable-in-admin-ui.md`
  and `2026-09-11-admin-backend-staging-ran-stale-code-against-migrated-subject-schema.md`
  — all found while making the admin ingestion pipeline actually usable
  end-to-end for a curator, following the PR #42 content-ingestion fix
  verified earlier this session.

## References
- `ADMIN/adminBackend/apps/exam_papers/bulk_import.py`
  (`infer_paper_fields_from_filename`, `import_pdf_files`)
- `ADMIN/adminBackend/apps/exam_papers/views.py::BulkImportPdfsView`
- `ADMIN/adminBackend/apps/exam_papers/urls.py` (`bulk-import-pdfs/`)
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/BulkImportDialog.tsx`
- `ADMIN/adminBackend/apps/exam_papers/tests/test_bulk_import.py`
  (`TestPdfFolderImport`)

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery

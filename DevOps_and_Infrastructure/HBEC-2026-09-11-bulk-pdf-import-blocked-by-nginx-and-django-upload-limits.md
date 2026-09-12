# Real Bulk PDF Batches Hit Two Silent Limits Below the Documented 200-File Cap

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Fixed, deployed to staging

## Summary
Immediately after shipping the "PDF Folder" bulk import feature
(`2026-09-11-bulk-import-had-no-path-for-a-bare-folder-of-pdfs.md`), the
user tried it with a real folder of 18 scanned ZIMSEC O-Level Mathematics
papers and got `413 Upload too large`. The view itself only rejects a
file that individually exceeds 50MB — none of the 18 did — so the 413 was
coming from somewhere the request never reached the new code at all.

## Investigation Steps
1. Traced the request path from the browser: `staging-admin.hbca.tech` →
   `hbec-gateway` (Caddy, no body-size directive, effectively unlimited)
   → `hbec-admin-frontend-staging`'s own nginx → `/api/` proxied to
   `admin-backend`.
2. Found `ADMIN/adminFrontend/nginx.conf`'s `client_max_body_size 50m` —
   a **server-level** directive, so it caps the entire request body
   across every `/api/*` call this nginx proxies, not per file. 18 real
   scanned exam papers bundled into one multipart POST easily exceeds
   50MB combined even though each individual file is under the view's own
   50MB-per-file check.
3. While fixing that, checked whether anything else below the codebase's
   own advertised `MAX_PDF_FILES = 200` would silently break first:
   Django's `DATA_UPLOAD_MAX_NUMBER_FILES` defaults to **100** and was
   never overridden in `config/settings/base.py` — a batch of 101-200
   files would fail with `TooManyFilesSent` inside Django's own multipart
   parser, before `BulkImportPdfsView`/`import_pdf_files` ever ran. Not
   yet hit (18 files), but the 200-file limit documented in the feature's
   own dev-log entry and UI copy was not actually true above 100.

## Root Cause
The nginx body-size limit was sized for the platform's existing largest
single upload (one paper + one mark scheme PDF), never revisited when the
new bulk-PDF-folder feature made "many files in one request" a real,
intended use case. The Django file-count limit was simply never set at
all — its default happened to be smaller than the new feature's own
advertised cap.

## Prevention / Rule
**Guardrail:** Any feature that accepts "many files/a batch in one request"
must ship with an explicit audit of every layer between the browser and the
view — proxy body-size limit, framework file-count limit, per-file size
check — each set to match the feature's own advertised cap, plus a
regression test at one unit past the framework's *default* for whichever
limit isn't being explicitly set (as was added here at 105, just past
Django's default of 100).

The bug here was entirely about limits inherited from a smaller use case
never being revisited for a new one — an explicit per-layer checklist item
is what forces that revisit before a real user hits it.

## Solution

### Immediate Fix
- `ADMIN/adminFrontend/nginx.conf`: `client_max_body_size` raised from
  `50m` to `600m` (whole-request, comfortably covers a real batch of
  scanned papers); `/api/` location's `proxy_send_timeout`/
  `proxy_read_timeout` raised from `60s` to `300s` to match — a large
  multipart body takes longer to transfer and write to disk than an
  ordinary JSON request.
- `ADMIN/adminBackend/config/settings/base.py`: added
  `DATA_UPLOAD_MAX_NUMBER_FILES = 200` to match
  `apps.exam_papers.bulk_import.MAX_PDF_FILES`. Added a regression test
  (105 files — just past Django's old default of 100) that would have
  caught this before it shipped; 28/28 passing in
  `test_bulk_import.py`, ruff clean.

### Long-term Fix
None needed beyond this — both limits are now sized to the feature's own
stated caps rather than inherited defaults nobody had reason to revisit.

## Prevention
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [ ] Code changes required — done; worth remembering going forward that
      a new "accepts many files in one request" feature needs its proxy
      layer's body-size limit checked explicitly, since the existing
      limit was sized for a different, smaller use case and nothing
      would have flagged the mismatch until a real user hit it

## Related Issues
- Immediate follow-up to
  `2026-09-11-bulk-import-had-no-path-for-a-bare-folder-of-pdfs.md` — the
  feature itself was correct, but the infrastructure in front of it
  wasn't sized for real usage until a real batch was tried.

## References
- `ADMIN/adminFrontend/nginx.conf` (`client_max_body_size`, `/api/`
  proxy timeouts)
- `ADMIN/adminBackend/config/settings/base.py`
  (`DATA_UPLOAD_MAX_NUMBER_FILES`)
- `ADMIN/adminBackend/apps/exam_papers/bulk_import.py::MAX_PDF_FILES`
- `ADMIN/adminBackend/apps/exam_papers/tests/test_bulk_import.py::TestPdfFolderImport::test_a_batch_over_djangos_default_100_file_limit_still_imports`

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery, minutes after the
feature's first real-world test

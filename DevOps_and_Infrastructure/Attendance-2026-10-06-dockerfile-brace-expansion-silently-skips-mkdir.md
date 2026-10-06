# Dockerfile `mkdir -p {a,b,c}` Brace Expansion Silently Creates One Wrong Directory Instead of Three

**Date:** 2026-10-06
**Project:** Attendance
**Environment:** Production (first deploy to smepulse-vm)
**Severity:** High
**Status:** Resolved

## Summary
`admin/Dockerfile.production` used `mkdir -p storage/framework/{cache,sessions,views}` to create three Laravel storage subdirectories in one line. `RUN` instructions execute via `/bin/sh -c`, and the image's `/bin/sh` (dash, on `php:8.4-cli`/Debian) does not support bash brace expansion — the string was passed to `mkdir` completely literally, creating one directory literally named `{cache,sessions,views}` and none of the three real ones. The admin dashboard returned HTTP 500 on every request (`InvalidArgumentException: Please provide a valid cache path`) because Blade's view compiler path resolution (`realpath(storage_path('framework/views'))`) returned `false` for a directory that didn't exist.

## Symptoms
- `http://smepulse-vm:8080/login` returned HTTP 500 (`An Error Occurred: Internal Server Error`), discovered only because the smoke test checked the actual title/body of the response instead of trusting that the container was `Up` and the TCP port accepted connections.
- `storage/logs/laravel.log` inside the container: `production.ERROR: Please provide a valid cache path. {"exception":"[object] (InvalidArgumentException(code: 0): Please provide a valid cache path. at .../View/Compilers/Compiler.php:75)`.
- `ls -la storage/framework/` inside the running container showed a single directory literally named `{cache,sessions,views}` instead of `cache/`, `sessions/`, `views/`.

## Environment Details
- **Server/Host:** smepulse-vm, container `attendance-admin-1`
- **Services Affected:** Laravel admin dashboard
- **Related Components:** `admin/Dockerfile.production`
- **Time First Observed:** 2026-10-06, during first production deployment, via smoke test after `docker compose up -d`

## Investigation Steps

### 1. Initial Diagnosis
The container was `Up` and `docker ps` showed it healthy-looking, but `curl http://localhost:8080/login` returned HTTP 500 instead of 200. Per the deployment guide's false-positive-trap guidance, the smoke test checked the actual page title, not just the status of the container or a bare port check.

### 2. Root Cause Analysis
```bash
docker exec attendance-admin-1 tail -n 50 storage/logs/laravel.log
# -> InvalidArgumentException: Please provide a valid cache path.
docker exec attendance-admin-1 ls -la storage/framework/
# -> drwxrwxr-x 2 root root 4096 Oct  6 16:20 {cache,sessions,views}
```
The directory name confirmed the brace expression was never expanded — `sh -c` (dash) does not implement `{a,b,c}` brace expansion; that is a bash/zsh extension, not POSIX `sh`. `storage/framework/views` therefore did not exist, so `realpath()` on it returned `false`, and Laravel's compiled config baked an empty string as the Blade compiled-view cache path.

### 3. Key Findings
- Docker's `RUN` instruction always invokes the shell form (`/bin/sh -c "..."`) unless the exec form (`RUN ["cmd", "arg1", ...]`) is used; which shell `/bin/sh` actually is depends on the base image, and on Debian/Alpine it is dash or busybox ash, neither of which supports brace expansion.
- The failure was completely silent at build time: `mkdir -p {cache,sessions,views}` is valid syntax under dash (it just treats the brace string as one literal path component), so the build produced no error or warning — the directory being created was simply the wrong one.
- This is a common portability trap when copy-pasting bash snippets into a Dockerfile without verifying the base image's actual `/bin/sh` target.

## Root Cause
Bash-only brace expansion syntax (`{cache,sessions,views}`) used inside a Docker `RUN` instruction, which executes under `/bin/sh`, not bash. The shell treated the whole brace expression as a single literal directory name instead of expanding it to three separate `mkdir` targets.

## Prevention / Rule
**Guardrail:** Never rely on bash-specific syntax (brace expansion, `[[ ]]`, arrays, `source`) inside a Dockerfile `RUN` shell-form instruction unless the Dockerfile explicitly starts with `SHELL ["/bin/bash", "-c"]` first. Prefer spelling out each `mkdir -p` target explicitly, or use the exec form with an explicit `bash -c '...'` wrapper if brace expansion is wanted. A `hadolint` CI check (or even a simple `grep -n '{.*,.*}' Dockerfile*` pre-commit check) catches this class of bug before merge.

This closes the gap because the bug produces zero build-time signal — it must be caught by static analysis of the Dockerfile itself, not by watching the build log, since the build "succeeds" either way.

## Solution

### Immediate Fix
Replaced the brace-expansion form with one explicit `mkdir -p` target per directory:
```dockerfile
# before
RUN mkdir -p storage/app storage/framework/{cache,sessions,views} storage/logs bootstrap/cache ...

# after
RUN mkdir -p storage/app storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache ...
```
Rebuilt the `admin` image and recreated the container; `storage/framework/` now shows three correct subdirectories and `/login` returns HTTP 200 with the real signed-in page (verified by title match and confirming the referenced built CSS/JS assets also return 200, not just the page itself).

### Long-term Fix
None needed beyond the fix above and the guardrail above.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Found during the same deployment session as
  `Attendance-2026-10-06-stale-dev-bootstrap-cache-shipped-to-production.md`
  (both in `admin/Dockerfile.production`, both caught by the same
  "don't trust a bare 200/Up status" smoke-test discipline).

## References
- None

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** 15 minutes

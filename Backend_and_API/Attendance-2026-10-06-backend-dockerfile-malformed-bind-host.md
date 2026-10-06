# Backend Dockerfile Binds Uvicorn to Malformed Host `0.0.0`

**Date:** 2026-10-06
**Project:** Attendance
**Environment:** Development (found while preparing a production deployment)
**Severity:** Low
**Status:** Resolved

## Summary
`backend/Dockerfile`'s `CMD` started uvicorn with `--host 0.0.0` instead of
`--host 0.0.0.0`. It happened to work on the `python:3.11-slim` (glibc)
base image because glibc's `getaddrinfo` accepts the legacy BSD
`inet_aton` shorthand and silently resolves the 3-octet form `0.0.0` to
`0.0.0.0`, but this is non-portable and not what the string says.

## Symptoms
- None observed in practice — the container has been binding and serving
  traffic correctly. Found by inspection while auditing the Dockerfile for
  a production deployment to a new VM, not from a reported failure.

## Environment Details
- **Server/Host:** `backend/Dockerfile` (built on `python:3.11-slim`)
- **Services Affected:** FastAPI backend container
- **Related Components:** `backend/Dockerfile` line 18
- **Time First Observed:** 2026-10-06, during pre-deployment review

## Investigation Steps

### 1. Initial Diagnosis
Reviewing `backend/Dockerfile` ahead of a production deployment to
`smepulse-vm`, the `CMD` read:
```
CMD ["uvicorn", "app.main:app", "--host", "0.0.0", "--port", "8000", "--reload"]
```
`0.0.0` is not a valid IPv4 literal (`ipaddress.ip_address("0.0.0")`
raises `ValueError`), yet the container has been running without issue.

### 2. Root Cause Analysis
Checked how the host string actually resolves on this image:
```bash
python3 -c "import socket; print(socket.getaddrinfo('0.0.0', 8000))"
# -> resolves to ('0.0.0.0', 8000) via glibc's inet_aton-style shorthand parsing
```
`python:3.11-slim` is Debian-based (glibc), and glibc's resolver accepts
the historical BSD shorthand where a 3-part dotted address `a.b.c` is
expanded to `a.b.0.c`... in this specific all-zero case it lands on
`0.0.0.0` either way, masking the typo. This behavior is glibc-specific,
not guaranteed by any portable spec, and would not necessarily hold if the
base image were ever switched to a musl-based image (e.g. `python:3.11-alpine`).

### 3. Key Findings
- The three-octet form is an accident of glibc's `getaddrinfo`, not a
  documented/portable uvicorn or Python behavior.
- No functional impact today, but it is a latent risk tied to the base
  image choice and a readability footgun (looks like a typo because it is one).

## Root Cause
Typo in the `--host` argument (`0.0.0` instead of `0.0.0.0`) that happened
to still resolve correctly due to glibc-specific legacy address parsing on
the current Debian-based base image.

## Prevention / Rule
**Guardrail:** Treat bind-address strings in Dockerfiles/compose files as
data worth validating, not free text — a one-line CI check or pre-commit
grep for `--host` / `HOST=` values that aren't one of `0.0.0.0`, `::`, or
an explicit IP (regex-validated as 4 dotted octets) would have caught this
before merge.

This closes the gap because the bug is invisible at runtime (it "just
works" on glibc) and would only surface as a hard failure if the base
image ever changed — a static check is the only thing that catches it
before that happens.

## Solution

### Immediate Fix
Corrected `backend/Dockerfile` to `--host 0.0.0.0`.

```bash
# before
CMD ["uvicorn", "app.main:app", "--host", "0.0.0", "--port", "8000", "--reload"]
# after
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

### Long-term Fix
None needed beyond the fix above; flagged here mainly because it was
caught while preparing a production deployment where a base-image change
(e.g. moving to an alpine image for a smaller footprint) would have turned
this into a real outage.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Found during pre-deployment review for the `smepulse-vm` Docker
  deployment (see forthcoming deployment report).

## References
- None

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** 5 minutes

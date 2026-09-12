# Flutter APK and RN App Download Links Both Silently Broken

**Date:** 2026-08-18
**Project:** HBEC
**Environment:** Staging (and, until checked, Production)
**Severity:** High
**Status:** Resolved

## Summary
After building and publishing the Flutter app's first real signed release APK, the "Download the App" link on the staging student frontend returned the SPA's `index.html` instead of the APK — `Content-Type: text/html` instead of `application/octet-stream` — even though the file existed in the git repo and the deploy had gone out cleanly. A second, pre-existing download link (for the older React Native app) was found broken the same way, pointing at a filename that didn't exist on disk.

## Symptoms
- `curl` against the download URL returned HTML (the SPA fallback route), not binary APK content
- No error in any container log — the request "succeeded," just with the wrong content
- User reported the link on the login page was also broken, separately from the new Flutter link

## Environment Details
- **Server/Host:** VPS
- **Services Affected:** `hbec-student-frontend` (staging)
- **Related Components:** `docker-compose.staging.yml` / `docker-compose.production.yml` bind mounts, `/opt/hbec/downloads`
- **Time First Observed:** 2026-08-18, immediately after the first APK build/deploy

## Investigation Steps

### 1. Initial Diagnosis
```bash
curl -sI https://staging-student.hbca.tech/downloads/hbec-student-flutter-staging.apk
# Content-Type: text/html  <- wrong, should be application/octet-stream
```
The file was confirmed present inside the built Docker image at the expected path, which made the wrong content-type confusing at first.

### 2. Root Cause Analysis
Both `docker-compose.staging.yml` and `docker-compose.production.yml` bind-mount a **host directory** (`/opt/hbec/downloads` and `/opt/hbec/mobile_builds`) over the same paths inside the container where the image would otherwise have served the baked-in files. A bind mount always wins over whatever the image contains at that path — and the host directory was empty, so nginx fell through to the SPA's catch-all route.

### 3. Key Findings
- The APK genuinely was in the image and in git — the deploy was not the problem
- The shadow was invisible from inside the container filesystem inspection unless you specifically knew to check the *host's* mounted directory, not the image
- The React Native app's separate download link (`/mobile/hbca-student.apk`) pointed at the same empty, bind-mounted directory
- The login page had its own, third, independently-broken link to a file (`hbec-student-v6.apk`) that had never actually been built/served — `hbec-student-v4.apk` was the one that existed

## Root Cause
Host-mounted directories in both compose files silently shadow anything baked into the image at those exact paths, and three separate download links across the codebase each pointed at a file that either didn't exist on the host or had never been placed there.

## Prevention / Rule
**Guardrail:** a required, automated post-deploy check that `curl -I`s every advertised static download link and fails the deploy if the response `Content-Type` is `text/html` or the byte size doesn't match the real artifact — turning the file's own listed-but-unchecked prevention item into an enforced CI/deploy gate rather than a to-do.

A request that "succeeds" with the wrong content and no error anywhere is invisible to any check that only looks at HTTP status codes — this is the false-positive trap named in guide 10, applied to static file serving specifically.

## Solution

### Immediate Fix
Placed the real APK files directly on the VPS host at `/opt/hbec/downloads/` (confirmed with the user first, given the production-path ambiguity), then fixed each broken link:
- Dashboard's Flutter beta link and login page's RN link both corrected to point at files confirmed present via `curl -sI` returning `200` with the exact expected byte count.

```bash
curl -sI https://staging-student.hbca.tech/downloads/hbec-student-flutter-staging.apk
# HTTP/2 200, content-length matching the built APK exactly
```

### Long-term Fix
Removed the previously-committed-then-un-served APK from the git repo (it was never actually reachable through the shadowed mount, so committing binary APKs to the repo was pure dead weight) — see `b9e1fef` (`fix(student-fe): stop committing the Flutter APK, it was never actually served`), then `cfe7ffe` and `bef6df2` fixed the two stale download-link references.

## Prevention
- [ ] Document the bind-mount-shadowing behavior directly in `docker-compose.*.yml` as a comment, so the next APK/build swap doesn't rediscover this the hard way
- [ ] A post-deploy smoke check that `curl`s every advertised download link and asserts `Content-Type` is not `text/html`

## References
- `docker-compose.staging.yml`, `docker-compose.production.yml` — `/opt/hbec/downloads`, `/opt/hbec/mobile_builds` bind mounts

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~45 minutes across two related fixes

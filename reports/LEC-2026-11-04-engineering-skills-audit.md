# LEC Virtual Labs — Engineering Skills Audit (security, contracts, config)

**Date:** 2026-11-04
**Project:** LEC Virtual Labs (`/home/shadowe/Projects/Lec_virtual_labs`)
**Type:** Audit
**Status:** Completed

## Summary
Ran a full-repo audit using three installed Claude engineering skills —
`security-boundaries`, `contract-integrity`, `configuration-parity` — against
the LEC Virtual Labs LMS (Django+DRF backend, React/Vite frontend, iframe
sims via a postMessage bridge, JWT auth with an httpOnly refresh cookie).
No exploitable security defects, no functional contract drift, and no unsafe
configuration were found. The system holds up well against its own stated
architectural goal (answers/marking server-side only, client never trusted).
Two minor documentation gaps were identified; no code changes were required.

## Context / Trigger
User asked for an architecture walkthrough, then asked to audit the codebase
"using our engineering-skills" (the skills installed from this repo's
conventions), explicitly as a verification pass rather than a narrative
re-read of the existing ADRs/contracts docs.

## Scope
**In scope:** backend auth (`accounts/`), authorization/tenant scoping
(`classrooms/`, `assignments/`, `attempts/`), the answer-stripping/marking
boundary (`labs/marking.py`), the iframe/postMessage trust boundary
(`lec-bridge.js`, `useLabBridge.ts`), CORS/cookie config, `contracts/api.md`
vs real DRF routes, `contracts/lab-bridge.md` vs the real bridge wire format,
`contracts/lab-manifest.md` vs `marking.py` and real catalog manifests,
`backend/.env.example` vs `settings.py`, and `docker-compose.yml` vs DB
config.

**Excluded:** `backend/accounts/serializers.py` password-validator minimums
and the auth-hardening migration's SQL were not reviewed in depth (flagged
by the security-boundaries fork as out of its sub-scope); individual sim
internals (physics/chemistry/biology/structural logic) were not reviewed —
only the generic bridge contract they all use.

## Method
Three parallel subagent audits, each invoking its named skill first and then
verifying the skill's checklist against actual source files (not just the
project's own `contracts/`/`decisions/` docs, which were treated as claims
to verify rather than ground truth):
1. **security-boundaries** — auth claims vs code, BOLA/IDOR risk across
   classroom/assignment/attempt views, the iframe trust boundary, CORS/cookie
   config.
2. **contract-integrity** — `contracts/api.md` / `lab-bridge.md` /
   `lab-manifest.md` vs the real Django routes, the real bridge JS/TS, the
   real marking engine, and a sample of real catalog manifest JSON files.
3. **configuration-parity** — `.env.example` vs `settings.py`'s actual env
   reads, fail-fast-on-missing-secret discipline (per guide 5b in this repo),
   docker-compose/Postgres parity, and secrets hygiene (`.gitignore`, no
   hardcoded credentials).

## Decisions & Findings

**Security boundaries — no exploitable defects.**
- ADR-003's auth claims (Argon2, timing-equalized unknown-user responses via
  a cached dummy hash, per-(user,IP) and per-user lockout, refresh
  rotation+blacklist with row-locking and reuse detection, Origin+
  `X-LEC-Auth` CSRF guard) all matched the literal code in
  `backend/accounts/security.py` and `views.py`.
- Every classroom/assignment/attempt view filters by ownership/enrollment
  before returning data, and cross-tenant reads return 404 rather than 403
  (avoids resource-existence leaks) — the strongest-scoped area of the
  codebase.
- The postMessage boundary has real defense-in-depth: the frontend validates
  `event.source`/`event.origin` and only forwards declared event names, but
  the server independently re-derives step completion from the manifest's
  `complete_on.where` in `attempts/services.record_event` →
  `marking.evaluate_event` — so a student POSTing events directly to the API
  (bypassing the iframe) still can't exceed what the manifest permits, and no
  answer value is ever reachable this way.
- Soft observation (not a bug): `IsTeacher`/`IsStudent` permission checks are
  role-based only; object-level ownership checks are repeated manually per
  view rather than enforced by the permission class itself. Works today
  because every existing view does it, but it's a convention, not a
  guarantee, for future views.

**Contract integrity — no functional drift, two doc-wording gaps.**
- `contracts/api.md`, `contracts/lab-bridge.md` match the real backend/
  frontend 1:1, including error shapes, wire format, and the 1.5s debounce.
- All 20 real catalog manifests conform to the documented schema (slug =
  filename, correct subject prefixes, no duplicate question ids).
- Gap 1: `lab-bridge.md` doesn't document that `useLabBridge.ts` validates
  `event.origin`/`event.source` before trusting a message — a real,
  security-relevant behavior that exists in code but isn't captured in the
  contract, so a future bridge change could regress it without the contract
  flagging the regression.
- Gap 2: `lab-manifest.md` describes `retry_penalty` as a multiplier "for a
  correct 2nd try," but `marking.py` applies it to any awarded points on a
  2nd try, including partial credit on `short`-type questions. Not a bug —
  the code is internally consistent — but the contract text could mislead a
  future manifest author into assuming partial-credit retries are exempt.

**Configuration parity — clean, one hygiene gap.**
- `settings.py` fails fast (raises at import) if `SECRET_KEY` or
  `TEACHER_INVITE_CODE` are unset while `DEBUG=False` — matches this repo's
  own guide 5b (fail-fast secure configuration) exactly.
- Cookie flags (`HttpOnly`, `SameSite=Strict`, conditional `Secure`),
  CORS allow-list (no wildcard), and docker-compose/`.env.example` Postgres
  values all match across every layer checked.
- `.gitignore` excludes `.env`/`.env.*`; `.env.example` holds only
  placeholders and a throwaway dev DB password — no real secret committed.
- Gap: `LOG_LEVEL`, `DB_CONNECT_TIMEOUT`, `SECURE_HSTS_SECONDS` are read with
  defaults in `settings.py` but aren't listed in `.env.example`, unlike the
  project's other optional vars.

## Changes Made
None — this was a verification-only audit. No bugs were found that met the
bar for an issue-log entry (no incorrect behavior or misconfiguration was
present in running code); the three gaps above are documentation-completeness
items, left for the user to decide whether to fold into `contracts/` and
`.env.example` directly.

## Verification
Each fork read the actual source (not just docs) for every claim it
reported: `backend/accounts/security.py`, `views.py`, `classrooms/views.py`,
`assignments/views.py`, `attempts/views.py`, `labs/marking.py`,
`lec-bridge.js`, `useLabBridge.ts`, `settings.py`, `.env.example`,
`docker-compose.yml`, `.gitignore`, and a sample of real catalog manifest
JSON files, cross-referenced line-by-line against the three contract docs
and ADR-003.

## Follow-ups / Deferred
- Not reviewed: `accounts/serializers.py` password-validator minimums,
  `migrations/0002_auth_hardening.py` SQL detail.
- Optional, low-priority doc fixes (no urgency, no risk if left as-is):
  add origin/source-validation line to `contracts/lab-bridge.md`; clarify
  `retry_penalty` wording in `contracts/lab-manifest.md`; add `LOG_LEVEL` /
  `DB_CONNECT_TIMEOUT` / `SECURE_HSTS_SECONDS` to `backend/.env.example`.
- Consider formalizing the object-level-ownership convention (permission
  boundaries repeated per view) into a shared mixin/decorator if the view
  count grows, so a future view can't forget the check — not urgent given
  100% current compliance.

## References
- `/home/shadowe/Projects/Lec_virtual_labs/intelligent_memory_management/decisions/ADR-001-lab-architecture.md`
- `/home/shadowe/Projects/Lec_virtual_labs/intelligent_memory_management/decisions/ADR-003-strong-authentication.md`
- `/home/shadowe/Projects/Lec_virtual_labs/intelligent_memory_management/contracts/api.md`
- `/home/shadowe/Projects/Lec_virtual_labs/intelligent_memory_management/contracts/lab-bridge.md`
- `/home/shadowe/Projects/Lec_virtual_labs/intelligent_memory_management/contracts/lab-manifest.md`
- This repo's `Principal_Engineer/engineering-guides/5. Secure Application Configuration.md` (fail-fast secrets)

---

**Completed By:** Claude Sonnet 5 (Claude Code session, agent-delegated 3-way parallel audit)
**Duration:** ~60s wall-clock (parallel forks), ~330k subagent tokens total

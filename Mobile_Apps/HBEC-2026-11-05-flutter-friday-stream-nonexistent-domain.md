# Flutter's Friday chat stream hardcoded a harness domain that was never actually configured

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Environment:** Staging (reported live by the user testing against `staging-student.hbca.tech`)
**Severity:** Critical
**Status:** Resolved

## Summary
Friday (the AI chat companion) could not connect at all on the Flutter
app, on any non-local deployment — not just staging. Its SSE stream URL
defaulted to a hardcoded `https://harness.hbca.tech`, a domain that does
not exist anywhere in the actual deploy configuration
(`scripts/deploy/render-caddyfile.sh` has no such entry), so the request
failed DNS resolution outright.

## Symptoms
- User report: Friday "failing to connect to the backend on staging."
- Live log: `DioException [connection error]: Failed host lookup:
  'harness.hbca.tech' (OS Error: No address associated with hostname,
  errno = 7)` on every attempt to send Friday a message.
- Everything upstream of the stream call worked correctly — login,
  `authorize-stream` token mint, even the gamification dashboard call
  (via the correct `staging-student.hbca.tech/harness-stream/...` path) —
  isolating the fault to this one URL-resolution function.

## Environment Details
- **Server/Host:** `staging-student.hbca.tech` (would also affect
  production — see Root Cause)
- **Services Affected:** Friday chat (Flutter only; web's equivalent
  request goes through a relative `/harness-stream/` path on its own
  origin and was never affected)
- **Related Components:**
  `STUDENT/mobile_flutter/lib/shared/services/harness_stream_client.dart`
- **Time First Observed:** 2026-11-05, live wireless-ADB test against
  staging.

## Investigation Steps

### 1. Initial Diagnosis
Tailed the live `flutter run` log for the session that reproduced the
report and grepped for `friday|dioexception|socketexception`.

### 2. Root Cause Analysis
```bash
grep -niE "friday|dioexception|socketexception" <session log>
```
Found the exact failing URL (`https://harness.hbca.tech/api/v1/friday/chat/stream`)
and its `SocketException`. Read `HarnessStreamClient.resolveStreamUrl`:
```dart
static const String harnessStreamBaseUrl = String.fromEnvironment(
  'STREAM_API_BASE_URL',
  defaultValue: 'https://harness.hbca.tech',
);
...
String resolveStreamUrl(String path) {
  final baseUri = Uri.parse(_dio.options.baseUrl);
  if (baseUri.host.contains('192.168') || ... ) {
    return baseUri.replace(port: 7083, path: path).toString();
  }
  return '$harnessStreamBaseUrl$path';   // <- always this hardcoded domain
}
```
Checked whether `harness.hbca.tech` is a real configured domain:
```bash
grep -n "harness.hbca.tech\|harness-stream" scripts/deploy/render-caddyfile.sh
```
**Zero matches.** The domain was never set up anywhere in the Caddy
routing this repo actually deploys. Meanwhile the gamification dashboard
call in the same session succeeded (got a 401, not a DNS failure) against
`https://staging-student.hbca.tech/harness-stream/api/v1/analytics/gamification/dashboard`
— proving the real, working pattern is "same host as the rest of the app,
under `/harness-stream/`" (per `STUDENT/Frontend/nginx.conf.template`'s
`location /harness-stream/`), not a separate harness domain at all.

### 3. Key Findings
- This was not a staging-specific misconfiguration — the hardcoded
  fallback domain was wrong for **every** non-local deployment, including
  production, since that domain is not configured there either. It likely
  "worked" only in whatever environment it was originally written against
  and silently reading success elsewhere.
- The LAN-dev branch (direct port 7083) was correct and untouched — that
  path is for bypassing nginx entirely during local development, a
  genuinely different case from "which domain does staging/production use."

## Root Cause
`resolveStreamUrl`'s non-LAN branch returned a fixed, never-actually-deployed
domain instead of deriving the harness's address from the same API host
every other request already uses correctly.

## Prevention / Rule
**Guardrail:** None added this session. The most direct mechanical guardrail
— a CI check asserting every hardcoded domain literal in
`STUDENT/mobile_flutter/lib/` resolves to an entry in
`scripts/deploy/render-caddyfile.sh` — would have caught this exact bug at
review time, but wiring up cross-repo-shape validation like that is a
larger effort than this fix; flagged as a reasonable follow-up, not built now.

[No automated guardrail added — recommend the CI check above as a
follow-up if this class of bug (a hardcoded domain nothing deploys)
recurs.]

## Solution

### Immediate Fix
Not applicable — no live service was down; this only affected the mobile
client's ability to reach it.

### Long-term Fix
Rewrote `resolveStreamUrl`'s default (non-LAN, non-explicit-override)
branch to derive the harness URL from the same host the rest of the app
already uses (`_dio.options.baseUrl`), under `/harness-stream`, matching
the nginx config and the already-working gamification call exactly. Kept
`STREAM_API_BASE_URL` as an opt-in explicit override for the rare case a
build genuinely needs to bypass the proxy and hit the harness directly.

## Prevention
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A
- [ ] Documentation to update — N/A
- [x] Code changes required — done, see Solution above.

## Related Issues
- None directly, but surfaced in the same session as other Friday-screen
  parity work (see the 2026-11-05 web/Flutter parity-audit-tool report).

## References
- `STUDENT/mobile_flutter/lib/shared/services/harness_stream_client.dart`
- `scripts/deploy/render-caddyfile.sh` (confirms the domain was never configured)
- `STUDENT/Frontend/nginx.conf.template` (`location /harness-stream/` — the
  real, working routing pattern this fix now matches)

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** <30 minutes

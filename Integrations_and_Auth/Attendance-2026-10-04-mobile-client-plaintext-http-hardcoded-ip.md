# Mobile client talks to the backend over plaintext HTTP to a hardcoded LAN IP, contradicting the documented TLS 1.3 + cert-pinning requirement

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development
**Severity:** High
**Status:** Investigating

## Summary
`ARCHITECTURE.md` states the cross-cutting security requirement is "TLS
1.3 strict certificate pinning for API traffic." The actual Flutter
client hardcodes an unencrypted `http://` base URL pointing at a specific
developer's LAN IP address, with no TLS, no certificate pinning, and no
build-time configuration mechanism to swap it for a real endpoint. Every
signed check-in payload (including the ECDSA signature and raw GPS/BSSID
telemetry) is currently sent over plaintext HTTP.

## Symptoms
- No user-visible symptom yet (pre-production); found during a code read, not an incident.
- The app will only function at all when run on the same LAN segment as `192.168.60.227`; any other network, or any deployment target outside that one developer's machine, cannot reach the backend.

## Environment Details
- **Server/Host:** Flutter mobile client
- **Services Affected:** All API traffic from the app (`/check-in/nonce`, `/check-in`, `/admin/devices/pair`, `/records/{employee_code}`)
- **Related Components:** `mobile/lib/services/api_service.dart:5`
- **Time First Observed:** 2026-10-04, during a full codebase read

## Investigation Steps

### 1. Initial Diagnosis
Compared `ARCHITECTURE.md`'s "Cross-cutting concerns → Security / Auth"
section against the actual network client in `mobile/lib/services/api_service.dart`.

### 2. Root Cause Analysis
```dart
class ApiService {
  static const String baseUrl = 'http://192.168.60.227:8000';
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
```
The scheme is `http://`, not `https://`; there is no `HttpClientAdapter`
configuration for certificate pinning anywhere in the file or elsewhere
in `mobile/lib`; and the host is a literal private IP rather than an
environment-configurable value (`--dart-define`, flavor config, etc.).

### 3. Key Findings
- Every request, including the hardware-signed check-in payload, travels unencrypted — a passive network observer can read employee codes, GPS coordinates, nonces, and signatures in transit (the signature itself prevents payload tampering, but not disclosure of PII/location data, and the nonce endpoint response and admin pairing endpoint responses are not signed at all).
- The hardcoded private IP means this is effectively dev-only code checked into the main client, with no separate dev/staging/prod configuration.
- This directly contradicts a cross-cutting requirement the project's own `ARCHITECTURE.md` documents as already in place.

## Root Cause
The client was wired up against a developer's local backend instance
during initial scaffolding (Sprint 1/2 per `docs/backlog.md`) and the
placeholder `http://<lan-ip>:8000` was never replaced with a proper
per-environment, HTTPS-only configuration before other features were
built on top of it.

## Prevention / Rule
**Guardrail:** Add a CI check (e.g. a simple grep/lint rule over
`mobile/lib/**/*.dart`) that fails the build if any string literal
matches `http://` (excluding `https://`) or a private-IP-literal pattern
(`192\.168\.`, `10\.`, `172\.(1[6-9]|2[0-9]|3[0-1])\.`) in a committed
`baseUrl`/network-config file, forcing base URLs through `--dart-define`
or a flavor-specific config file instead of a literal.

This closes the gap because the root cause is exactly a literal dev
value committed where a configured, HTTPS endpoint belongs; a CI grep for
that literal pattern catches it before merge instead of relying on code
review to notice it.

## Solution

### Immediate Fix
Not applied this session (read-only review). Recommended immediate fix:
switch `baseUrl` to `https://` once the backend has a TLS-terminating
endpoint (e.g. behind an ingress/reverse proxy with a real certificate),
and move the value out of source into `--dart-define`/flavor config so
dev/staging/prod don't share a hardcoded literal.

### Long-term Fix
Implement the certificate pinning described in `ARCHITECTURE.md` (e.g.
via `dio`'s `HttpClientAdapter` + a pinned SHA-256 public key hash, or the
`http_certificate_pinning` package), and add the CI guardrail above.

## Prevention
- [x] Configuration changes needed: move `baseUrl` to build-time config, not a literal
- [ ] Monitoring/alerts to add: none
- [x] Documentation to update: none needed if implemented as documented — `ARCHITECTURE.md` already states the target state correctly
- [x] Code changes required: HTTPS + certificate pinning in `api_service.dart`

## Related Issues
- Related to `Attendance-2026-10-04-monotonic-sync-uses-server-clock-not-device.md` (same pattern: a documented security/anti-fraud architecture decision not yet matched by the implementation).

## References
- `ARCHITECTURE.md` ("Cross-cutting concerns → Security / Auth")
- `mobile/lib/services/api_service.dart`

---

**Resolved By:** N/A (flagged, not yet fixed)
**Time to Resolution:** N/A

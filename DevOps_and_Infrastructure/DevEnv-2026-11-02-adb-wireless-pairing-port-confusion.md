# adb wireless debugging pairing fails with "protocol fault" when using the wrong port

**Date:** 2026-11-02
**Project:** DevEnv (cross-project — this machine's Flutter/Android dev setup)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`adb pair <ip>:<port> <code>` repeatedly failed with
`error: protocol fault (couldn't read status message): Success` even after
regenerating a fresh pairing code. The port being used
(`192.168.60.243:44515`) was Android's **Wireless debugging → connect**
port, not the pairing port — the phone's "Pair device with pairing code"
dialog uses a different, separate port that isn't obvious from the main
screen.

## Symptoms
- `adb pair <ip>:44515 <code>` fails instantly (~90ms) with `FAIL` then
  `protocol fault (couldn't read status message): Success`, even with a
  freshly-generated code.
- Plain TCP reachability to that IP:port succeeds (`nc -vz` connects
  fine) — so it looks like a network problem but isn't.
- Restarting the adb server, retrying with a new code, and setting
  `OPENSSL_CONF` to force-enable the legacy provider all made no
  difference (adb bundles its own statically-linked crypto — confirmed via
  `ldd $(which adb)` showing no libssl/libcrypto dependency — so
  OpenSSL-level fixes are a dead end for this specific error).

## Environment Details
- **Server/Host:** Linux dev workstation, `platform-tools` 37.0.1.
- **Services Affected:** `adb pair` / wireless debugging setup for any
  Android device.
- **Related Components:** Android's Developer Options → Wireless
  debugging UI exposes two *different* IP:port pairs on the same screen —
  the top-level "IP address & Port" (the connect port) and the pairing
  dialog's own IP:port (shown only inside "Pair device with pairing
  code"). It's easy to copy the wrong one.
- **Time First Observed:** 2026-11-02, while setting up a CRM Flutter
  mobile app's first real-device test.

## Investigation Steps

### 1. Initial Diagnosis
Assumed an expired pairing code (codes/ports do rotate) and had the user
regenerate it. Same failure with the fresh code — ruled out expiry.

### 2. Root Cause Analysis
Ran `ADB_TRACE=all adb pair ...` and saw the local adb server accept the
request syntax (`OKAY`) but the actual pairing attempt fail in under
100ms — too fast for a real handshake with the phone, meaning the local
daemon was rejecting it before ever properly engaging the device. Checked
what services the phone was actually advertising:

```bash
adb mdns check      # confirms the mdns discovery daemon is running
adb mdns services   # lists every adb service the phone is broadcasting
```

```
List of discovered mdns services
adb-RFCT60WWF2K-462IcO	_adb-tls-pairing._tcp	192.168.60.243:44381
adb-RFCT60WWF2K-462IcO	_adb-tls-connect._tcp	192.168.60.243:44515
```

### 3. Key Findings
- `_adb-tls-pairing._tcp` (44381) and `_adb-tls-connect._tcp` (44515) are
  genuinely different services on different ports. `adb pair` only
  speaks to the pairing service; sending it to the connect port causes an
  immediate protocol-level rejection, which surfaces as the confusing
  "protocol fault ... Success" message rather than a clear "wrong port."
- The port the user had was the connect port (44515, shown prominently at
  the top of the Wireless debugging screen) — the actual pairing port
  (44381) only appears inside the pairing dialog itself and is easy to
  overlook if you grab the first IP:port you see on screen.

## Root Cause
Using the wrong one of two co-advertised adb services (connect port
instead of pairing port) for the `adb pair` command. adb's error message
for this specific mismatch is misleading (`protocol fault`), which sends
you chasing network/crypto causes instead of the actual port mismatch.

## Prevention / Rule
**Guardrail:** Before running `adb pair`, always run `adb mdns services`
first and use the `_adb-tls-pairing._tcp` port it lists — never the port
read off the phone's main Wireless debugging screen (that's the
`_adb-tls-connect._tcp` port, used only for the later `adb connect` step).

This closes the gap because the root cause was port confusion between two
visually-similar IP:port pairs; `adb mdns services` disambiguates them
programmatically instead of relying on correctly reading the phone's UI.

## Solution

### Immediate Fix
```bash
adb mdns services                      # find the real pairing port
adb pair <ip>:<pairing_port> <code>     # e.g. 192.168.60.243:44381 206617
adb connect <ip>:<connect_port>         # e.g. 192.168.60.243:44515
adb devices -l                          # confirm
flutter devices                        # confirm Flutter sees it too
```

### Long-term Fix
None needed beyond the guardrail above — this is a one-time
gotcha per machine/device pairing, not a recurring config issue.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [ ] Code changes required — n/a

## Related Issues
- Enabled the first real-device Flutter test for the CRM mobile rebuild
  (see `reports/CRM-2026-11-02-flutter-mobile-rebuild-phase3-pos-checkout.md`'s
  Follow-ups — device testing was blocked until this was resolved).

## References
- `adb mdns check` / `adb mdns services` — built into platform-tools, no
  extra install needed.

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** Same session, after the second pairing attempt.

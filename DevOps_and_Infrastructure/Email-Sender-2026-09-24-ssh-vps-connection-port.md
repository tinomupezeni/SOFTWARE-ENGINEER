# SSH Connection Hitting Router Instead of VPS

**Date:** 2026-09-24
**Project:** Email-Sender
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
When attempting to set up automated passwordless SSH into the newly provisioned VPS, the SSH connection attempt to the public IP (102.217.49.126) on port 22 landed on the hosting provider's pfSense firewall router instead of the actual VPS instance. This caused authentication failures when attempting to inject the public key using the provided gateway password.

## Symptoms
- Attempting to `ssh root@102.217.49.126` prompted for `Password for root@pfSense.home.arpa:` instead of a standard Ubuntu/Linux password prompt.
- SSH key injection tools (`ssh-copy-id`, `sshpass`) continuously rejected the user's password with Exit Code 5.

## Environment Details
- **Server/Host:** VPS provided by zchpc.movellasystems.com
- **Services Affected:** SSH
- **Related Components:** pfSense, NAT, ssh-copy-id
- **Time First Observed:** 2026-09-24

## Investigation Steps

### 1. Initial Diagnosis
Attempted to run `ssh-copy-id` and automated it using `pexpect` and `sshpass`. It repeatedly failed with an invalid password error.

### 2. Root Cause Analysis
Analyzed the SSH prompt and realized it was `pfSense.home.arpa`. This indicated that port 22 on the public IP was not port-forwarded to the VPS, but rather belonged to the provider's firewall router.
The user later provided the dashboard details revealing the VPS had an internal IP (`192.168.50.245`) and a specific mapped SSH port (`35169`).

```bash
# Investigated by testing the explicit internal IP and assigned port
nc -zv 192.168.50.245 35169
sshpass -p "shwfHEAGiIAFS6JTZYuu" ssh -p 35169 -o StrictHostKeyChecking=no root@192.168.50.245 'echo SUCCESS'
```

### 3. Key Findings
- The hosting provider uses an Apache Guacamole-based Gateway for typical remote access without a VPN.
- Direct SSH was possible from the local terminal because the local machine happens to share the `192.168.x.x` internal routing capable of reaching `192.168.50.245`.
- The actual required SSH parameters were `root@192.168.50.245 -p 35169` with the gateway password.

## Root Cause
The initial IP address provided (102.217.49.126) was the main edge firewall for the network, not the user's VPS. The user's VPS is NAT'd behind the firewall with an internal IP and custom SSH port provided by the dashboard.

## Prevention / Rule
**Guardrail:** Always inspect the actual SSH server banner/prompt or dashboard details when connecting to a new hosting provider, instead of assuming port 22 on the public IP routes to the provisioned VPS instance.

Validating the SSH prompt (`root@pfSense`) ensures we don't accidentally try to authenticate or modify the infrastructure's edge router instead of the intended server.

## Solution

### Immediate Fix
1. Tested the provided internal IP (`192.168.50.245`) and port (`35169`).
2. Used `sshpass` to successfully inject the public key to the correct VPS.

```bash
sshpass -p "shwfHEAGiIAFS6JTZYuu" ssh-copy-id -p 35169 -o StrictHostKeyChecking=no root@192.168.50.245
```

### Long-term Fix
Updated `~/.ssh/config` on the local machine with an alias (`vps`) correctly pointing to the internal IP and port 35169.

## Prevention
- [x] Configuration changes needed (updated `~/.ssh/config`)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes

# Docker Auth Detection Failure & Resolution

**Date:** 2026-05-09
**Project:** CRM
**Environment:** Development / Win32
**Severity:** Medium (UX Blocker)
**Status:** Resolved (Final)

## Summary
The initial fix to bypass the Docker Hub login prompt using docker info failed because modern Docker Desktop versions do not include the username in the standard plaintext output.

## Symptoms
- crm.ps1 continued to prompt for credentials despite the user being authenticated.
- Logs showed the check for "Username: tinotenda762" returning null.

## Root Cause
Cross-version inconsistency in docker info output. Modern Docker environments store authentication state in ~/.docker/config.json but do not necessarily expose it via the basic info command.

## Prevention / Rule
**Guardrail:** a code-review checklist item banning any script-side check that parses a CLI tool's human-readable plaintext output — require reading a structured config file (`~/.docker/config.json`) or a `--format json` flag instead.

Plaintext CLI output is explicitly not a stable interface across tool versions; a JSON/config-file source is. This removes the entire class of "worked on my Docker version, broke on someone else's" bugs, not just this one instance of it.

## Solution

### Immediate Fix
Replaced the docker info check with a direct inspection of the Docker configuration file. The script now reads $env:USERPROFILE\.docker\config.json and verifies the existence of the https://index.docker.io/v1/ key within the uths object.

`powershell
# Reliable auth check
$dockerConfigPath = "$env:USERPROFILE\.docker\config.json"
if (Test-Path $dockerConfigPath) {
    $config = Get-Content $dockerConfigPath -Raw | ConvertFrom-Json
    if ($config.auths -and ($config.auths.'https://index.docker.io/v1/' -or $config.auths.'docker.io')) {
        $isLoggedIn = $true
    }
}
`

## Prevention
- [x] Use configuration files or machine-readable API formats (--format json) for environment checks rather than parsing plaintext CLI output.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 10 minutes

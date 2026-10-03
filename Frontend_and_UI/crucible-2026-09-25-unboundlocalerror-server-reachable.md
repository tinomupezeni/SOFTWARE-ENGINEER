# UnboundLocalError in phase_client.py when race_condition is disabled

**Date:** 2026-09-25
**Project:** crucible
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
When running the Crucible testing suite with a dynamically generated configuration (or any config where the `race_condition` scenario is disabled but `rapid_fire_click` is enabled), the `phase_client.py` module crashes with an `UnboundLocalError: cannot access local variable 'server_reachable' where it is not associated with a value`.

## Symptoms
- The Crucible execution fails during `PHASE 04: FRONTEND & CLIENT-EDGE BREAKER`.
- Error message: `⚠ Playwright execution failed: cannot access local variable 'server_reachable' where it is not associated with a value`
- The entire testing suite blocks and exits with a failed status.

## Environment Details
- **Server/Host:** Localhost (Docker containers)
- **Services Affected:** Crucible `phase_client.py` (Frontend & Client-Edge Breaker)
- **Related Components:** Playwright testing logic
- **Time First Observed:** 2026-09-25T09:04:00+02:00

## Investigation Steps

### 1. Initial Diagnosis
Observed the crash in the `crucible wizard` run output when testing against the TESC frontend and backend containers. The UI Event Storming attack failed before executing.

### 2. Root Cause Analysis
Checked `phase_client.py` logic around `server_reachable`.
```python
            # --- 1. The Stale-State Overwrite (Out-of-Order Response Race) ---
            race_config = scenarios.get("race_condition", {})
            if race_config:
               # ... 
               server_reachable = True # Or False
            
            # --- 2. The Multi-Click Rapid Fire (UI Event Storming) ---
            rapid_config = scenarios.get("rapid_fire_click", {})
            if rapid_config:
                # ...
                if server_reachable: # Throws UnboundLocalError here if race_config was empty
```

### 3. Key Findings
- `server_reachable` is conditionally initialized inside the `if race_config:` block.
- Subsequent scenario blocks (`rapid_fire_click`, `token_corruption`) assume `server_reachable` has been initialized and try to evaluate it.
- If the `race_condition` scenario is skipped (either by removing it from `crucible.yml` or using the auto-generated wizard config), the variable is never defined, causing a crash.

## Root Cause
A Python scoping and initialization error. The `server_reachable` variable is initialized inside an `if` block, but accessed globally within the function by subsequent blocks that run independently of the first `if` block.

## Prevention / Rule
**Guardrail:** Enable a strict linter like `flake8` or `pylint` in the CI pipeline with checks for `undefined-variable` (E0601) and `possibly-used-before-assignment` (W0606).

Running a static analysis tool before merging code would catch conditional initialization issues where a variable might be accessed without being bound to a value.

## Solution

### Immediate Fix
Initialize `server_reachable = True` (or default to checking reachability) at the beginning of the `run` method in `phase_client.py`, outside of any specific scenario blocks.

### Long-term Fix
Refactor `phase_client.py` so that server reachability is checked once globally before any scenario runs, rather than inside the `race_condition` scenario specifically.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (Initialize variable at broader scope)

## Related Issues
- None

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 5m

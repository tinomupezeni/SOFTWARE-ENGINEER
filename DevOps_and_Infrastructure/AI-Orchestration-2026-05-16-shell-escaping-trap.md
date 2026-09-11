# Lesson: The Shell Context & Escaping Trap

**Date:** 2026-05-16
**Incident:** `tese.ps1` failed with `syntax error near unexpected token '('` during a `docker exec` health check.

## The Root Cause: "Multi-Layer Escaping"
When you run a command via a script that talks to another shell, your command passes through multiple "Translators":
1. **PowerShell** (Local)
2. **SSH** (Transport)
3. **Bash** (Remote VPS)
4. **Python** (Inside Docker)

In this incident, the Python code `import urllib.request; ...` contained parentheses and semicolons that were interpreted by **Bash** before they ever reached **Python**. Bash saw the `(` and thought it was a subshell command, leading to the syntax error.

## The Senior Fix: Standardize the Wrapper
Avoid passing complex logic through strings across shell boundaries. 

### Wrong (Too many layers of escaping):
```bash
docker exec my-container python -c "import sys; print('hi')"
```

### Right (Use a dedicated health script or extremely careful quoting):
Wrap the Python command in a single-quoted string that Bash won't touch, or better yet, use a tool like `curl` which is built for the shell environment.

## Lesson Learned
The more "Layers" a command passes through, the more likely it is to break. **Simplify the interface.** 
- If a container needs a deep health check, put a `healthcheck.py` *inside* the container image and just call `docker exec my-container python healthcheck.py`.
- This keeps the logic *inside* the version-controlled image and out of the brittle deployment script.

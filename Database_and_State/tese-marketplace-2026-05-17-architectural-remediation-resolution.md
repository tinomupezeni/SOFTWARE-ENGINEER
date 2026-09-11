# Resolution: Tese Marketplace API Crises and Deployment Script Robustness

**Date:** 2026-05-17
**Project:** Tese-Marketplace
**Status:** Resolution Proposed (Architectural Directives)
**Guiding Principle Engineer:** Gemini CLI

## 1. Executive Summary
The Tese Marketplace is currently experiencing a "Cascading Failure" state where backend crashes (`store-api`) and deployment script bugs (`tese.ps1`) are masking each other. This resolution applies the **Scientific Method** and **First Principles** to decouple these failures and restore a verified production state.

## 2. Surgical Intervention: `tese-store-api`
The `NameError: name 'Depends' is not defined` is a failure of **Verification**. 

### Immediate Directive: Correct `app/main.py`
Apply the following imports to the top of `apps/store-api/app/main.py`:

```python
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from .database import get_db, engine
# ... other imports
```

Ensure the `/api/v1/health/deep` endpoint is defined exactly as follows to maintain the **Deep Health Check Standard**:

```python
@app.get("/api/v1/health/deep")
async def deep_health(db: Session = Depends(get_db)):
    health_status = {"status": "healthy", "components": {"database": "unknown"}}
    try:
        # First Principles: Verify DB connection
        db.execute("SELECT 1")
        health_status["components"]["database"] = "up"
    except Exception as e:
        health_status["status"] = "unhealthy"
        health_status["components"]["database"] = f"down: {str(e)}"
        raise HTTPException(status_code=503, detail=health_status)
    return health_status
```

## 3. Surgical Intervention: `tese.ps1`
The PowerShell script failed due to **Shell Escaping Traps** when executing remote Python health checks.

### Immediate Directive: Fix Python Fallback Health Check
In `tese.ps1`, update the `Verify-Deployment` function's Python check to use a **Here-String** or simplified quoting to prevent local interpretation of backslashes.

**Corrected Pattern:**
```powershell
$checkCommand = "python3 -c 'import urllib.request, sys; try: res=urllib.request.urlopen(\"$url\"); sys.exit(0 if res.getcode()==200 else 1); except: sys.exit(1)'"
# Execute via SSH
ssh $VPS_USER@$VPS_IP "docker exec $containerName $checkCommand"
```

## 4. Architectural Standard: The "Zero-Zombie" API Template
To prevent recurring `NameError` issues, all Marketplace microservices (Auth, Store, Brain, SMS) must adhere to this entry-point structure:

1. **Strict Imports**: Use `ruff check` locally before every commit.
2. **Standard Health Base**: Every service MUST implement `/health/shallow` and `/api/v1/health/deep`.
3. **Dependency Injection**: Always use FastAPI `Depends` for resource management (DB, Redis).

## 5. Verification Plan
Once the changes are applied, verify in this order:
1. **Local Build**: `docker build` the `store-api` and check for startup errors.
2. **Network Check**: Ping the VPS (159.198.42.231) to ensure port 22 is open.
3. **Surgical Deploy**: Re-deploy ONLY the `store-api` using the corrected `tese.ps1`.
4. **Deep Verification**: Manually curl the deep health endpoint:
   ```bash
   curl http://159.198.42.231:8001/api/v1/health/deep
   ```

---
**Guiding Principle:** "Verification is the Premium Skill. Never assume a service is 'up' until its dependencies are proven alive."

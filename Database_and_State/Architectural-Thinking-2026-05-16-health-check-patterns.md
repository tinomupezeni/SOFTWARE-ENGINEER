# Observability: Shallow vs. Deep Health Checks

**Date:** 2026-05-16
**Concept:** A system's ability to report its own internal health to external orchestrators (like Shipwright or a Load Balancer).

## 1. The Shallow Health Check (`/health/shallow`)
**Goal:** Is the web server alive?
- **Logic:** Returns `HTTP 200 OK` immediately.
- **Usage:** Used by Load Balancers to see if the process is running.
- **Risk:** Returns 200 even if the database is down, leading to "Zombie Services" that are "up" but can't do any work.

## 2. The Deep Health Check (`/api/v1/health/deep`)
**Goal:** Is the system functional?
- **Logic:** 
    1. Check Database connection (`SELECT 1`).
    2. Check Redis/Cache connection (`PING`).
    3. Check disk space (optional).
    4. Check upstream dependencies (optional).
- **Usage:** Used by deployment scripts (Shipwright/tese.ps1) to verify a successful rollout.
- **Value:** Prevents the "False Positive" where the frontend loads but the app is broken.

## 3. Implementation Blueprint (FastAPI)
```python
@app.get("/api/v1/health/deep")
async def health_check(db: Session = Depends(get_db)):
    health_status = {"status": "healthy", "components": {}}
    
    # 1. Check Database
    try:
        db.execute("SELECT 1")
        health_status["components"]["database"] = "up"
    except Exception as e:
        health_status["status"] = "unhealthy"
        health_status["components"]["database"] = f"down: {str(e)}"
        
    # 2. Add other checks here (Redis, S3, etc.)
    
    if health_status["status"] == "unhealthy":
        raise HTTPException(status_code=503, detail=health_status)
        
    return health_status
```

## 4. Orchestrator Integration
The deployment script should wait for the `/deep` endpoint to return 200 before considering the deployment "Done."

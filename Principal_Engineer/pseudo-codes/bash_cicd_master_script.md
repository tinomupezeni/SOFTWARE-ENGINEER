# CI/CD Master Bash Script (Pseudo-Code)

This script acts as your automated CI/CD pipeline. It pulls code, builds images, runs migrations, deploys, and verifies health—rolling back if something goes wrong.

```bash
#!/bin/bash
# deploy_master.sh

set -e # Exit immediately if a command exits with a non-zero status.

# 1. Configuration variables
PROJECT_DIR="/opt/hbec"
DOCKER_COMPOSE_FILE="docker-compose.prod.yml"

echo "Starting Deployment Pipeline..."

# 2. Pull Latest Code
cd $PROJECT_DIR
git fetch origin main
git reset --hard origin/main

# 3. Build New Images
echo "Building Docker images..."
docker compose -f $DOCKER_COMPOSE_FILE build

# 4. Pre-Flight Database Migrations
# Run migrations on a temporary container before bringing down the old ones.
echo "Running Database Migrations..."
docker compose -f $DOCKER_COMPOSE_FILE run --rm backend-service python manage.py migrate

# 5. Zero-Downtime Deployment
# The -d flag runs in background, --wait forces it to wait for HEALTHCHECKs to pass.
echo "Deploying new containers..."
docker compose -f $DOCKER_COMPOSE_FILE up -d --wait

# 6. Health Check Verification Gate (Manual Polling alternative if --wait isn't enough)
# Pseudo-code logic to check if a specific endpoint is 200 OK
MAX_RETRIES=10
RETRY_COUNT=0
HEALTH_ENDPOINT="https://api.yourdomain.com/health"

echo "Verifying application health..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" $HEALTH_ENDPOINT)
    
    if [ "$STATUS_CODE" -eq 200 ]; then
        echo "✅ Deployment Successful and Healthy!"
        
        # 7. Post-Deployment Cleanup
        echo "Pruning old docker images..."
        docker image prune -f
        exit 0
    fi
    
    echo "Waiting for service to be healthy... (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT+1))
done

# 8. Rollback Mechanism
echo "❌ Deployment Failed Health Check! Initiating Rollback..."
# In a robust system, you would tag previous images. For a simple rollback:
# Revert git commit and redeploy
git reset --hard HEAD~1
docker compose -f $DOCKER_COMPOSE_FILE up -d --wait
echo "⚠️ Rollback Complete. Check logs for failure reasons."
exit 1
```

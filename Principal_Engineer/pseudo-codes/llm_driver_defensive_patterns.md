# Defensive Engineering Patterns for LLM Drivers

When you are acting as the "System Architect driving the LLM," you are highly vulnerable to the **"Happy Path Bias."** LLMs naturally write code assuming the network is reliable, the database is fast, and every API call succeeds on the first try. In distributed systems (like your Redis Sentinel and Kafka/Outbox architecture), the opposite is true.

To prevent repeating past outages, you must force the LLM to implement these three defensive patterns.

## 1. The Idempotency Pattern (Preventing Duplicate Data)
**The Trap:** You ask the LLM to write a webhook receiver (e.g., for Paynow or a Curriculum Sync). It writes code that blindly creates a new record or charges the user every time the endpoint is hit.
**The Fix:** Force the LLM to use Idempotency Keys so that if a payload is delivered twice (which happens constantly in production), the system ignores the duplicate.

**Pseudo-Code to demand from the LLM:**
```python
def process_webhook(payload):
    # 1. Extract a unique ID from the payload (e.g., transaction_id)
    transaction_id = payload.get("id")
    
    # 2. Check if we've already processed this exact event
    if ProcessedEvent.objects.filter(tx_id=transaction_id).exists():
        return {"status": "already processed"} # Idempotent exit
        
    # 3. Process the logic inside an atomic database transaction
    with transaction.atomic():
        # ... Do the work (update student status, add payment, etc.)
        
        # 4. Record that we finished this event
        ProcessedEvent.objects.create(tx_id=transaction_id)
        
    return {"status": "success"}
```

## 2. The Background Task "Try-Catch-Alert" Pattern
**The Trap:** You ask the LLM to write a Celery task or a background cron job. It writes it perfectly, but if the task fails, it fails silently in the background. You only find out a week later when a user complains (e.g., the Celery OTP lockout incident or the curriculum sync failure).
**The Fix:** Force the LLM to wrap all asynchronous/background work in robust error handling that logs to your monitoring system (like Sentry) and implements retries.

**Pseudo-Code to demand from the LLM:**
```python
@celery.task(bind=True, max_retries=3)
def sync_curriculum_outbox(self, data):
    try:
        # 1. Attempt the risky network/database operation
        process_sync(data)
        
    except TemporaryNetworkError as exc:
        # 2. Exponential backoff for things that might fix themselves
        logger.warning(f"Network error, retrying in {self.request.retries ** 2} minutes")
        raise self.retry(exc=exc, countdown=60 * (self.request.retries ** 2))
        
    except Exception as fatal_error:
        # 3. Hard failure: Alert the team immediately (Sentry/Slack)
        alert_system.capture_exception(fatal_error)
        
        # 4. Graceful degradation: Mark the sync as "FAILED" in DB so it doesn't get stuck forever
        mark_sync_as_failed(data.id)
        raise
```

## 3. The "Soft Delete" Pattern
**The Trap:** The LLM uses `object.delete()` when modifying data. This caused your July 14th Curriculum Sync bug where a deleted/inactive board left the React frontend clinging to a ghost cache because the data just vanished.
**The Fix:** Never let the LLM use hard deletes on core business entities. 

**Pseudo-Code to demand from the LLM:**
```python
# BAD: What the LLM will write by default
def remove_subject(subject_id):
    Subject.objects.get(id=subject_id).delete()

# GOOD: What you must instruct it to write
def remove_subject(subject_id):
    subject = Subject.objects.get(id=subject_id)
    subject.is_active = False  # Soft delete
    subject.deleted_at = timezone.now()
    subject.save()
    
    # Optional: Broadcast "subject_deactivated" event so frontends know to clear their caches
```

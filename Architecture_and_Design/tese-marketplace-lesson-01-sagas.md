# Lesson Log: The Saga Pattern & RAM State Risks

**Date:** 2026-05-20
**Focus:** Module 1: Distributed Reliability & Saga Patterns
**Instructor:** Principal AI Engineer
**Student:** Junior Developer

---

## 1. Introduction: The "Dual Write" Trap

In a monolithic system, atomic transactions are straightforward:
```python
with db.begin():
    create_order(db)
    reduce_stock(db)
    # If anything fails, db.rollback() restores the database.
```
In our microservices architecture, these actions live in separate applications:
- **Order creation** is managed by `order-api`.
- **Stock management** is managed by `catalog-api`.

Because these operations span network boundaries, they cannot share a single database transaction. If `order-api` writes the order but `catalog-api` fails to reduce stock due to a network timeout, we have created an invalid order for items we do not have in stock. This is the **Dual Write Trap**.

---

## 2. The Current Architecture: Stateless Sagas

Let's look at how the orchestrator currently coordinates checkout in [composite.py:checkout_saga](file:///C:/Users/Dell/Documents/projects/New%20Tesee/Tese-Marketplace/apps/store-api/app/composite.py#L65-L154):

1. **Reserve Stock**: Loops through items and calls `/api/products/{pid}/reserve-stock` (Catalog API).
2. **Create Order**: If stock reservation succeeds, calls `/api/orders` (Order API).
3. **Simulate Payment**: If payment succeeds, calls `/api/products/{pid}/finalize-stock`.
4. **Rollback (Compensating Actions)**: If step 2 or payment fails, it loops back and calls `/api/products/{pid}/release-stock` to clean up reserved items.

### The Critical Vulnerability: The RAM State Risk
The orchestrator maintains the current stage of this saga inside standard Python local variables in memory:
```python
reserved_items = []
try:
    for item in items:
        # reserve stock...
        reserved_items.append(item)
```
If the container hosting `store-api` restarts, crashes, or loses power *after* reserving stock but *before* creating the order:
* The local variable `reserved_items` is wiped from RAM.
* The compensating rollback loop is never triggered.
* **Result**: Those reserved items become permanently locked in "Zombie" states, artificially deflating available store stock.

---

## 3. The Engineering Shift: Stateful Sagas & Persistent Outboxes

To transition from **Optimistic Engineering** (assuming systems won't crash) to **Pessimistic Engineering** (expecting crashes), we must store saga state in a shared database or Redis key-value store before sending remote requests.

```
[Start Checkout] ──► (Save Saga Status: "PENDING_RESERVATION" to DB)
                           │
                           ▼
                      [Reserve Stock]
                           │
                           ▼
                     (Save Saga Status: "RESERVED" + Item List to DB)
                           │
                           ▼
                      [Create Order]
```

If the container crashes at any stage:
1. On boot, a background worker inspects the Saga State database for records that have been in a `PENDING_RESERVATION` or `RESERVED` state for longer than a threshold (e.g., 2 minutes).
2. The worker automatically reads the list of reserved items and triggers the compensating calls (`/release-stock`) to restore consistency.

---

## 4. Architectural Assignment / Challenge

Let's test your ability to design robust distributed workflows using our codebase.

### The Challenge Scenario
We want to add a feature where a successful checkout triggers a WhatsApp confirmation message to the buyer. Currently, we write:
```python
# Inside checkout_saga
if payment_success:
    # 1. Finalize stock
    finalize_stock_calls()
    # 2. Call Notification Engine
    send_whatsapp_message(phone, "Your order is confirmed!")
```

If the network connection to the WhatsApp Gateway times out, our `send_whatsapp_message` function raises an exception.

### The Questions to Solve:
1. **The Incomplete Checkout bug**: Under our current code, if the WhatsApp call fails, what happens to the checkout response returned to the client? Do they get a success page?
2. **The Outbox Remediation**: Explain how we can use the **Transactional Outbox Pattern** to decouple order confirmation from message dispatching, ensuring a slow or down message gateway never blocks the checkout path.
3. **The Design**: Draft a simple SQL schema for a `message_outbox` table that would reside in our database to support this pattern.

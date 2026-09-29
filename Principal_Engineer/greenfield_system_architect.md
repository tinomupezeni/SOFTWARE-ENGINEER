# 1. The Greenfield System & Schema Architect

**When to use it:** Before a single line of feature code is written. Use this to force the AI to design the data models, state machines, and API topology for a completely new module.

---

Act as a Principal Software Architect specializing in domain-driven design, high-performance database schematics, and clean microservice topology. 

I want to build a new system/feature with the following requirements: [Insert Feature Requirements Here].

Before you write any application code, scripts, or view routing, you must deliver a comprehensive System Architecture Specification. Analyze the data lifecycle and system flow, and provide your output across these 4 distinct areas:

1. TOPOLOGICAL SYSTEM DATA FLOW
- Detail how data enters the edge, moves through memory buffers, and settles in persistent storage. 
- Specify which operations must run asynchronously (via queues/background workers) versus synchronously (blocking HTTP threads).

2. RELATIONAL STORAGE SCHEMA & INVARIANT CONSTRAINTS
- Provide the complete, production-grade SQL or DB schema layout (Tables, Fields, Data Types, Indexes, and Foreign Keys).
- Define strict database-level constraints (Unique constraints, Check constraints, Cascade rules) to ensure zero data corruption or orphan records.
- Explicitly outline how row-level isolation or multi-institutional boundaries are hard-coded into the data layer.

3. STATE MACHINE ENGINE & TRANSITION LOGIC
- Model the core states of this feature as a strict State Machine.
- Document every valid state, the explicit triggers that allow transitions, and the deterministic rollback steps if a transition breaks mid-flight.

4. EDGE INGESTION & VALIDATION CONTRACTS
- Define the exact payload structures (e.g., Pydantic models or JSON schemas) required to clear edge authentication and validation before hitting internal application services.

FORMAT YOUR RESPONSE USING CLEAR HEADINGS, MARKDOWN TABLES FOR SCHEMAS, AND SEQUENCE FLOW TEXT. DO NOT CODE THE BUSINESS LOGIC YET.

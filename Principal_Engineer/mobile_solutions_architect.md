Act as a world-class Principal Mobile Solutions Architect, Lead Mobile Systems Engineer, and Expert Performance Auditor. Your priority is building hyper-resilient, production-ready, fluid client-side applications that maintain flawless data integrity under extreme resource and network constraints.

I am preparing to build/refactor a mobile module or app feature with the following requirements: [Insert Mobile Feature Requirements Here].

Before you write any UI components or business logic syntax, you must deliver a comprehensive Mobile Engineering Specification. Analyze the client-side lifecycle and data synchronization mechanics, and deliver your architectural blueprint across these 5 dimensions:

1. LOCAL STATE, OS LIFECYCLE, & MEMORY MANAGEMENT
- How does this feature handle native OS lifecycle interruptions (e.g., app backgrounded, incoming phone call, low memory warnings)?
- Define the state preservation strategy. If the OS kills the app process in the background, how do we serialize and restore the user's exact state upon resume?
- Identify and mitigate potential memory leak vectors (e.g., un-retracted event listeners, active streams, or un-disposed animation controllers).

2. OFFLINE-FIRST ARCHITECTURE & DATA SYNCHRONIZATION
- Detail the local persistence layer layout (e.g., SQLite, Room, Hive, WatermelonDB). 
- Provide the exact data synchronization flow logic. How does the app queue mutations locally when offline, and what is the deterministic conflict-resolution policy (e.g., Last-Write-Wins, server override) when the network reconnects?
- Ensure all local database modifications run transactions asynchronously off the UI thread to guarantee zero data corruption.

3. MAIN-THREAD INTEGRITY & RENDERING PERFORMANCE (Jank Prevention)
- Enforce strict concurrency boundaries. Every heavy computational task (JSON parsing, cryptography, local DB indexing, image manipulation) must be explicitly offloaded to background threads or isolates.
- Define the UI performance optimization strategy for large, dynamic datasets (e.g., lazy-loading list view recyling, image caching, and debounced/throttled input rendering) to ensure a locked 60/120 FPS.

4. NETWORK EDGE RESILIENCE & BANDWIDTH OPTIMIZATION
- Design defensive network orchestration. Implement strict request timeouts, token auto-refresh interceptors, and a standardized global error handler for timeouts or socket exceptions.
- Provide a detailed exponential backoff retry mechanism with jitter for failed sync payloads.
- Detail how the app minimizes bandwidth utilization (e.g., payload caching, conditional HTTP headers like ETag, or compressed data payloads).

5. SECURE STORAGE & CLIENT-SIDE HARDENING
- Map out the client-side security architecture. Sensitive values (access tokens, API keys, personal identifiable data) must be encrypted and stored strictly inside native secure enclaves (iOS Keychain / Android Keystore), never in plain text local stores.
- Specify input sanitization rules and defense against reverse-engineering vectors at the application configuration layer.

FORMAT YOUR RESPONSE USING CLEAR HIERARCHICAL HEADINGS, DATA SEQUENCE FLOWS, AND SCHEMA TABLES WHERE APPROPRIATE. DO NOT EMIT THE FUNCTIONAL VIEW CODE YET.

### 🚨 CRITICAL STRUCTURAL RISKS (Fix Immediately)

* **[Silent Data Loss in Offline Sync Queue]**
    * **Location:** `lib/core/sync/sync_bloc.dart` -> `_onTriggerSync`
    * **The Systemic Vulnerability:** The offline synchronization queue blindly attempts to process pending mutations. If an endpoint request fails due to a standard network timeout, bad gateway, or connection drop, the catch block writes `mutation.status = 'failed'` and effectively abandons the payload forever. There is no retry policy, no distinction between a 400 Bad Request (unrecoverable) and a 503/SocketException (recoverable). Under unstable connectivity, student progression data will be silently lost.
    * **Architectural Remedy:** Implement a robust state-machine for sync items: `pending -> in_flight -> completed | retryable_error | fatal_error`. Use an exponential backoff policy for `retryable_error` statuses and explicitly check the `DioExceptionType` before marking a mutation as definitively failed.

* **[Unbounded Concurrency in Sync Execution]**
    * **Location:** `lib/core/sync/sync_bloc.dart` -> `_onTriggerSync`
    * **The Systemic Vulnerability:** `TriggerSync` events are fired dynamically upon connectivity changes without rate-limiting, debouncing, or event dropping. The `on<TriggerSync>` handler does not use a `droppable` or `restartable` transformer. Rapid network flapping will spawn multiple concurrent, unconstrained `_onTriggerSync` executions that query the same pending records and fire duplicated HTTP requests. 
    * **Architectural Remedy:** Apply the `droppable` event transformer from `bloc_concurrency` to the `TriggerSync` event handler to ensure only one sync process can run simultaneously.

* **[Broken Authentication Loop & Missing Token Refresh]**
    * **Location:** `lib/core/network/interceptors/auth_interceptor.dart` -> `onError`
    * **The Systemic Vulnerability:** A stub comment `// Trigger token refresh logic` exists inside the 401 Unauthorized handler, meaning the system will fundamentally crash or drop the user session whenever an access token expires. Furthermore, any requests that were in flight when the token expired will not be queued to retry with the newly minted token, leading to silent request drops.
    * **Architectural Remedy:** Implement a fully blocking token-refresh Mutex queue in Dio. When a 401 occurs, lock the request queue, fire the refresh token API call, update secure storage, and replay all queued/failed requests using the new access token.

### ⚠️ MAJOR ARCHITECTURAL DEBT (Prioritize for Next Sprint)

* **[Unstructured "Catch-All" Error Swallowing in BLoCs]**
    * **Location:** `lib/features/auth/presentation/bloc/auth_bloc.dart`
    * **The Anti-Pattern:** The codebase uses generic `catch (e)` blocks extensively and emits raw stringified errors (`emit(AuthError(e.toString()))`). This tightly couples presentation UI to backend exception traces and masks critical telemetry about the nature of failures (e.g. timeout vs invalid credentials).
    * **Refactoring Strategy:** Introduce a standardized `Failure` domain entity (e.g., `ServerFailure`, `NetworkFailure`, `CacheFailure`) and use the `fpdart` or `dartz` package `Either<Failure, T>` return types on all repositories. The BLoC should map these typed failures into localized UI messages.

* **[Missing Pagination & Backpressure on Remote Fetching]**
    * **Location:** `lib/core/network/dio_client.dart`
    * **The Anti-Pattern:** There is no infrastructure configuration for handling paginated content or streaming backpressure. If the backend returns 5,000 exam records, the mobile app will attempt to deserialize them all synchronously on the main Dart isolate, causing jank and out-of-memory (OOM) crashes on low-end devices.
    * **Refactoring Strategy:** Standardize pagination interfaces on repositories. Offload heavy JSON decoding to a separate isolate using Flutter's `compute()` method.

### 📊 DATA TOPOLOGY & SECURITY MATRIX AUDIT

* **Secure Storage Vulnerability:** `SecureStorageService` is used for tokens, which is correct, but there is no mechanism to securely encrypt local `Isar` databases on device. Sensitive curriculum progress, exams, and localized user metrics are currently stored in plaintext on disk, which is vulnerable on rooted/jailbroken devices. 
* **Data Ingestion Boundary:** Local databases are directly mutating schemas via raw mappings without DTO (Data Transfer Object) boundary validations to ensure backend schema changes don't crash the local parser.

### 🛠️ INFRASTRUCTURE RECOMMENDATIONS

* **Isolate Processing Pipeline:** Introduce dedicated background workers using `flutter_workmanager` or isolated processes to perform background syncing when the app is minimized.
* **Network Instrumentation:** Integrate Sentry or Datadog RUM to capture unhandled exceptions, dropped frames, and network latency anomalies, as current error logging relies solely on simple print interceptors.

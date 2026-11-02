# Flutter Mobile — Stock List Silently Failed to Refresh After Create/Delete

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Environment:** Development (real device, Samsung Galaxy S22+)
**Severity:** Medium
**Status:** Resolved

## Summary
After adding Products create/update/delete to the mobile app, the Stock list
screen never refreshed itself after a product was created or deleted — the
new/removed item only appeared after some other action (a manual search,
toggling the low-stock filter) forced a refetch. Root cause: a `context.read`
call on the wrong `BuildContext` relative to its `BlocProvider`, throwing a
`ProviderNotFoundError` that was silently swallowed by an un-awaited async
callback, so there was no visible crash and no error — the refresh simply
never happened.

## Symptoms
- Created a product via the "Add product" FAB; backend confirmed (201,
  verified via Django shell) the product existed, but the Stock list kept
  showing the old data until some unrelated interaction (toggling "Low stock
  only") forced a refetch.
- Same symptom after deleting a product from its detail screen: `DELETE`
  succeeded (204), but the list screen the user landed back on still showed
  the deleted item until manually refreshed.
- No error dialog, no crash, no visible symptom other than "the data is just
  stale."

## Environment Details
- **Server/Host:** Local Docker Compose backend (`192.168.60.242:8020`)
- **Services Affected:** Mobile Flutter app, Stock tab (`ProductListScreen`)
- **Related Components:** `core/routing/app_router.dart`,
  `features/products/presentation/controllers/product_list_cubit.dart`
- **Time First Observed:** During real-device verification of the new
  Products CRUD feature (Phase 4)

## Investigation Steps

### 1. Initial Diagnosis
Confirmed via Django shell and `docker compose logs backend` that both
create and delete succeeded on the backend every time. The bug was entirely
client-side: the already-correct data just wasn't being re-fetched.

### 2. Root Cause Analysis
Pulled `adb logcat` right after a create and found the real, unhandled
exception the UI never surfaced:

```bash
adb logcat -d -t 2000 | grep -iE "exception|error"
```

```
E flutter : [ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: Error: Could not find the correct Provider<ProductListCubit> above this Builder Widget
E flutter :       // Will throw a ProviderNotFoundError, because `context` is associated
```

### 3. Key Findings
- The Stock `GoRoute`'s builder looked like:
  ```dart
  builder: (context, state) => BlocProvider(
    create: (_) => ProductListCubit(context.read<ProductRepository>()),
    child: ProductListScreen(
      onAddProduct: () async {
        final created = await context.push<ProductEntity>(AppRoutes.newProduct);
        if (created != null && context.mounted) {
          context.read<ProductListCubit>().loadFirstPage(); // <-- throws
        }
      },
    ),
  ),
  ```
- `context` here is the route builder's **own** context — an ANCESTOR of the
  `BlocProvider` being constructed in this same call, not a descendant of it.
  `context.read<T>()` only looks upward from the given context, so it can
  never find a provider that this same build call is about to insert below
  it.
- Because `onAddProduct` is an `async` callback invoked from a widget's
  `onPressed`-style handler (not awaited by the caller), the thrown exception
  surfaces asynchronously, after the function that triggered it has already
  returned. Flutter reports it to `dart_vm_initializer`'s unhandled-exception
  hook, which logs it to `adb logcat` but does **not** crash the visible UI
  or show an error dialog — it just looks like nothing happened.
- Proved the mechanism precisely: reverted the fix, ran the regression test
  below, watched it fail with the exact same `ReadContext.read` stack trace
  seen on-device; restored the fix, watched it pass.

## Root Cause
`context.read<ProductListCubit>()` was called from a `BuildContext` that sits
**above** the `BlocProvider<ProductListCubit>` in the same widget subtree,
not below it — an ancestor/descendant mismatch that provider packages detect
and throw on, but which was invisible here because the throwing code ran
inside an un-awaited async closure.

## Prevention / Rule
**Guardrail:** any `context.read<T>()`/`context.watch<T>()` call made inside
a closure that is *defined* in the same widget-building expression that
*creates* the provider for `T` must use a context obtained from strictly
inside that provider (e.g. via a `Builder`, or the `builder:` callback of the
widget the provider wraps) — never the context parameter of the enclosing
`GoRoute`/`builder:` function itself. Code review for any new `GoRoute`
builder that both creates a `BlocProvider`/`RepositoryProvider` and wires
navigation callbacks against it should check this specifically, since it's a
pattern this app's router uses repeatedly (every tab's root route).

This closes the exact gap here: the ancestor-context mistake is structurally
easy to make (the enclosing `context` is right there, in scope, and reads of
app-wide providers like `ProductRepository` from that same context work
fine, making it non-obvious that a locally-created provider behaves
differently) and produces no crash to flag it in manual testing.

## Solution

### Immediate Fix
Wrapped the `BlocProvider`'s child in a `Builder` and used *its* context
(`innerContext`, a genuine descendant of the `BlocProvider`) for both the
`push` and the `read`:

```dart
builder: (context, state) => BlocProvider(
  create: (_) => ProductListCubit(context.read<ProductRepository>()),
  child: Builder(
    builder: (innerContext) => ProductListScreen(
      onAddProduct: () async {
        final created = await innerContext.push<ProductEntity>(AppRoutes.newProduct);
        if (created != null && innerContext.mounted) {
          innerContext.read<ProductListCubit>().loadFirstPage();
        }
      },
      // onOpenProduct fixed the same way
    ),
  ),
),
```

### Long-term Fix
None needed beyond the pattern above — the same `Builder` indirection should
be used for any future branch route that creates its own scoped
Bloc/Repository provider and also needs to react to a pushed child route's
result.

## Prevention
- [x] Code changes required — done (`Builder` wrapper), see above.
- [x] Regression test added — `test/core/shell/app_shell_navigation_test.dart`
      ("creating a product from the Stock tab refreshes the list"), built
      against the *real* `buildAppRouter` (a simplified/stub router could
      not have caught this, since the bug is in the real router's own
      provider wiring). Verified it fails on the unfixed code with the same
      `ReadContext.read` stack trace seen on-device, and passes on the fix.
- [ ] Monitoring/alerts to add — not applicable (client-side, dev-time bug).
- [ ] Documentation to update — covered by this entry.

## References
- `reports/CRM-2026-11-02-flutter-phase4-products-crud.md`
- `mobile_flutter/lib/core/routing/app_router.dart`
- `mobile_flutter/test/core/shell/app_shell_navigation_test.dart`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** Found and fixed within the same session as the
feature that introduced it.

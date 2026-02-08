---
trigger: always_on
---

# Project Rules: Milow (Flutter Multi-App Repository)

> **Scale Target**: Millions of users. Every decision must consider performance, reliability, and security at scale.

---

## 1. Persona & Context

- **Role**: Senior Staff Flutter Engineer / Architect.
- **Communication**: Professional, concise, technical, direct.
- **Priority**: Performance, Stability, Security, Design Compliance.

---

## 2. Monorepo Structure & Architecture

**Strictly enforce boundaries between applications and shared packages.**

### A. Structure

- **`apps/`**: Application entry points. Contains *only* app-specific configuration, routing, and dependency injection.
  - `apps/driver`: Mobile (iOS/Android)
  - `apps/terminal`: Desktop (macOS/Windows)
- **`packages/`**: Reusable code. **Always check here first before writing new code.**
  - `packages/core`: Logger, Error Handling, Analytics, Network Client.
  - `packages/ui`: Design System, Shared Widgets, Theme extensions.
  - `packages/data`: Supabase User Client, Shared Repository Interfaces.

### B. Dependency Flow

`Presentation` → `Domain` → `Data`

- **Presentation**: Widgets, State (Provider/Riverpod).
- **Domain**: Entities, Business Logic, Use Cases. **Pure Dart, no Flutter dependencies if possible.**
- **Data**: Repositories, DTOs, Data Sources.

---

## 3. Application Domains

**Do not conflate tech stacks between apps.**

### A. Driver App (Mobile) `apps/driver`

- **Target**: iOS & Android
- **State**: `Provider` (Legacy/Stable).
  - **Strict Rule**: No `riverpod` in this app to avoid confusion.
  - use `ChangeNotifier` with strict disposal.
- **Focus**: Offline-first, battery optimization, 48px+ touch targets
- **Libs**: `flutter_map`, `geolocator`, `dynamic_color`, `drift` (local db)

### B. Terminal App (Desktop) `apps/terminal`

- **Target**: macOS & Windows 10/11
- **State**: `Riverpod` (`riverpod_generator`).
  - **Strict Rule**: No `Provider` or manual providers. Use `@riverpod` annotations.
- **Focus**: Information density, keyboard shortcuts, native feel
- **Libs**: `fluent_ui`, `window_manager`, `flutter_riverpod`, `go_router`
- **Context Menus**: Always use native context menus.
- **must add company_id and restrict access whenever any table add in database

---

## 4. Design Systems

### A. M3 Expressive (Driver App)
>
> Ref: [M3 Expressive](https://m3.material.io/blog/building-with-m3-expressive)

- **Color**: `DynamicColorBuilder` with `DynamicSchemeVariant.vibrant`.
- **Typography**: `GoogleFonts.outfit`.
- **Standards**:
  - `FilledButton` (not Elevated).
  - `NavigationBar` (not BottomNavigationBar).

### B. Fluent UI (Terminal App)
>
> Ref: [Fluent 2](https://fluent2.microsoft.design)

- **Color**: `FluentTheme.of(context).resources`.
- **Materials**: Mica (Sidebars), Acrylic (Flyouts).
- **Typography**: `GoogleFonts.outfit` or `Segoe UI`.

---

## 5. Backend (Supabase)

### A. General

- **Typing**: Use generated Dart types (`supabase_gen`). No `Map<String, dynamic>`.
- **RLS**: **Mandatory** on ALL tables.
- **Transactions**: Use limits and constraints for multi-step operations.

### B. Edge Functions

- **Use When**:
  - Direct database access is unsafe (e.g., admin operations).
  - Complex logic requiring low latency (e.g., payment processing).
  - Webhooks (Stripe, Twilio).

### C. Data Integrity (Offline-First)

- **Conflict Resolution**: Implement **Last-Write-Wins (LWW)** or **Version Vectors** for sync.
- **Queues**: Mutations MUST be queued locally (`drift`/`hive`) when offline.
- **Sync**: Reconcile on connection restore.

---

## 6. Engineering Standards

### A. Error Handling

- **Pattern**: Use `Result<T, E>` (via `fpdart`). **Do not throw exceptions** for control flow.
- **No Silent Failures**: All `E` must be handled or explicitly ignored with comment.
- **Logging**: Log `E` with stack trace and context.

### B. Quality

- **Lints**: Zero warnings (`flutter_lints`).
- **Imports**: No relative imports across layers (`../../`). Use absolute imports.
- **Secrets**: Use `.env` file via `flutter_dotenv` or `envied`. **Never hardcode API keys.**

---

## 7. Observability (Enterprise Grade)

**Mandatory for all Production Builds.**

### A. Crash Reporting

- **Crashlytics**:
  - Wrap `runApp` in `runZonedGuarded`.
  - `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`.
- **Context**: Attach `user_id`, `app_version`, `device_model` to every report.

### B. Performance Monitoring

- **Firebase Performance**:
  - **Cold Start**: < 2s.
  - **API Latency**: Track p95 for all critical endpoints.
  - **Frame Rendering**: Monitor jank (>16ms).
- **Custom Traces**: Trace critical user journeys (e.g., "Submit Trip").

### C. Analytics

- **Service**: Use `AnalyticsService` wrapper (in `packages/core`).
- **Events**: Track `screen_view`, `feature_used`, `error_occurred`.
- **Funnels**: Define funnels for Onboarding, Trip Submission, Payment.

---

## 8. Network Resilience

### A. Network Client

- **Wrapper**: All features must use `CoreNetworkClient` (dio/http wrapper).
- **Resilience**:
  - **Exponential Backoff**: 1s → 2s → 4s (+ jitter). Max 3 retries.
  - **Circuit Breaker**: Open after 5 consecutive failures. Reset after 30s.

### B. Connectivity

- **State**: React to connectivity changes (`connectivity_plus`).
- **Offline**: Show non-intrusive UI indicator (SnackBar/Banner) when offline.

---

## 9. Security Hardening

- **Storage**: `flutter_secure_storage` for tokens.
- **Obfuscation**: `--obfuscate --split-debug-info` enabled.
- **Biometrics**: `local_auth` for sensitive actions (payments, settings).
- **API**: Implement Certificate Pinning.

---

## 10. Memory & Resource Management

- **Images**: `memCacheHeight/Width` mandatory for list views.
- **Disposal**:
  - `Riverpod`: Use `.autoDispose`.
  - `Provider`: Manually dispose in `dispose()`.
- **Leaks**: Run `leak_tracker` in CI.

---

## 11. Testing Strategy

### A. Coverage Goals

- **Domain/Logic**: 80% (Unit Tests).
- **Integration**: **100%** Coverage of Critical Flows (Auth, Dispatch).

### B. Taxonomy

- **Unit**: Tests a single class/function in isolation (mocks allowed).
- **Integration**: Tests a distinct flow (e.g., `LoginController` + `AuthRepository`). Uses real "fake" implementations (e.g., InMemoryDB).
- **E2E**: Full app test (Maestro/Patrol).

---

## 12. App Lifecycle & Features

- **Updates**: Force Update logic (Remote Config) to deprecate old versions.
- **Flags**: All new features wrapped in Feature Flags.
- **State Restoration**: Implement `RestorationMixin` for form data preservation.

---

## 13. Documentation

- **ADR**: Architecture Decision Records required for major structural changes.
- **Comments**: Explain "Why", not "What".
- **API**: Document public methods with `///` DartDoc.

---

## 14. Agent Guidelines (Antigravity/Gemini)

**Instructions for the AI Assistant:**

1. **Check Shared Patterns**: Before writing usage code, check `packages/` for existing solutions.
2. **Verify Standards**: Ensure generated code follows "Result" pattern and "Network Resilience" rules.
3. **No Hallucinations**: Do not import packages that are not in `pubspec.yaml` without asking.
4. **Tests**: Always propose a test plan (or write the test) for the code you write.
5. **Context**: Read `IMPLEMENTATION_PLAN.md` if it exists.

---

## 15. Enterprise Standards (Phase 4+)

### A. Dispatch Architecture

- **Multi-Stop Mandate**: All Loads MUST support `List<Stop>`. Do not use singular `pickup`/`receiver` fields.
- **Stop Sequence**: Stops must have a `sequence_id` (1-indexed) to enforce order.

### B. Integrations

- **Secrets**: All API keys (Samsara, QuickBooks) must reside in Supabase Edge Functions. Never in the Flutter app.

---

## 16. Safety-Critical Engineering (NASA Power of 10)

**Apply these principles to core logic to ensure extreme reliability at scale.**

1. **Simple Control Flow**: Avoid complex recursion; prefer iterative patterns for business-critical logic.
2. **Deterministic Loops**: All loops must have a checkable upper bound. For infinite sequences, use `.take(n)` or explicit timeouts.
3. **Allocation Awareness**: Minimize dynamic memory allocation in high-frequency paths (e.g., `build` methods). Use `const` constructors aggressively.
4. **Function Conciseness**: No function shall exceed 60 lines (standard sheet of paper).
5. **Invariant Density**: Minimum of two `assert()` calls per function to verify state and parameter validity.
6. **Smallest Scope**: Declare data objects at the smallest possible level of scope to prevent state leakage.
7. **Input/Output Validation**: Validate all parameters and handle every non-void return value (via `Result` types).
8. **Minimal Meta-Programming**: Avoid complex conditional imports or logic-heavy code generation where standard patterns suffice.
9. **Referential Clarity**: Limit deep object dereferencing (e.g., `a.b.c.d`). Use local variables for intermediate steps.
10. **Zero-Warning Compilation**: All code must compile with zero warnings under pedantic lint settings (Mandatory).

---

## 25. Golden Path Snippets

**Use these patterns as the absolute source of truth.**

### A. Riverpod Provider (Terminal)

```dart
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  FutureOr<User?> build() {
    return ref.watch(authRepositoryProvider).currentUser;
  }

  Future<void> updateName(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => 
      ref.read(authRepositoryProvider).updateName(name)
    );
  }
}
```

### B. Result Type (Error Handling)

```dart
// domain/repositories/auth_repository.dart
Future<Result<User, AuthFailure>> signIn(String email, String password);

// usage
final result = await repo.signIn(email, password);
result.fold(
  (failure) => _handleFailure(failure),
  (user) => _handleSuccess(user),
);
```

### C. Network Resilience (CoreNetworkClient)

```dart
// features/dispatch/data/repositories/load_repository.dart
Future<Result<List<Load>>> fetchLoads() async {
  return _client.query<List<Load>>(
    () async {
      final response = await _client.supabase.from('loads').select();
      return (response as List).map((json) => Load.fromJson(json)).toList();
    },
    operationName: 'fetchLoads',
  );
}
```

### D. Supabase RLS Policy

```sql
-- Allow read access to own profile
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- Allow update access to own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id);
```

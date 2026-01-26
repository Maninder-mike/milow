---
description: [PRO] Scaffold a new enterprise-grade feature for Driver (Mobile) or Terminal (Desktop).
---

# Workflow: Enterprise Feature Scaffolding

This workflow is used by Senior Staff Engineers to scaffold new features in the Milow project. It ensures 100% compliance with architectural, security, and observability standards.

## 1. Governance & Context

Determine the app and core requirements:

- **Driver App**: `apps/driver` (Mobile) | **Stack**: `Provider`, `M3 Expressive`.
- **Terminal App**: `apps/terminal` (Desktop) | **Stack**: `Riverpod`, `Fluent UI`.
- **Enterprise Mandate**: If this feature touches "Loads" or "Trips," it **MUST** support `List<Stop>` and `sequence_id` as per Phase 4 standards.
- **Security**: Identify if the feature requires `company_id` isolation.

## 2. Global Standards

- **Layering**: `Domain` must be **Pure Dart** (no `material.dart` or `flutter` imports).
- **Error Handling**: Use `Result<T, E>` from `fpdart` for all logic.
- **Resilience**: All data fetching must use `CoreNetworkClient`.
- **Observability**: Every public action must include a check for an `AnalyticsService` event.

## 3. Execution Plan

### Step 1: Scaffolding Directory Tree

// turbo
Create the standard directory structure:

```bash
lib/features/[feature_name]/
├── data/
│   ├── models/        # DTOs & JsonSerializable
│   └── repositories/  # Supabase implementations
├── domain/
│   ├── entities/      # Freezed models (Pure Dart)
│   └── repositories/  # Abstract interfaces
└── presentation/
    ├── providers/     # or Notifiers
    ├── widgets/       # UI Components
    └── pages/         # Feature entry points
```

### Step 2: Domain Layer (Pure Logic)

// turbo

1. Create `domain/entities/[feature_name].dart` using `@freezed`.
// turbo
2. Create `domain/repositories/[feature_name]_repository.dart`.
   - **Requirement**: Use `///` DartDoc for all methods.
   - **Requirement**: Return `Future<Result<T, E>>`.

### Step 3: Data Layer (Resilience)

// turbo

1. Create `data/repositories/supabase_[feature_name]_repository.dart`.
   - **Requirement**: Wrap queries with `_client.query<T>(...)` for automatic retries and logging.

### Step 4: Presentation Layer (State)

// turbo

1. Create state management based on the target app:
   - **Driver**: `ChangeNotifier` with explicit `dispose()` and loading state handling.
   - **Terminal**: `@riverpod` class extending `_$Notifier`. Use `AsyncValue` for async states.

### Step 5: Testing (Mandatory)

// turbo

1. Create `test/features/[feature_name]/` directory.
2. Scaffold `[feature_name]_repository_test.dart` (Unit) and `[feature_name]_notifier_test.dart` (Integration).
   - **Goal**: 80% coverage for domain logic.

## 4. Final Validation

- [ ] Run `dart analyze` (Zero warnings).
- [ ] Verify no relative imports.
- [ ] Ensure `company_id` is present in all database queries if multi-tenant.
- [ ] Confirm all `Result.fold()` paths are handled in the UI.

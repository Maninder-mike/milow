---
trigger: always_on
---

# Project Rules: Milow (Flutter)

## 1. Persona & Context

- **Role**: Senior Flutter Engineer / Architect.
- **Experience Level**: Expert. You are building for scale (millions of users).
- **Communication**: Professional, concise, technical, and direct.
- **Priorities**: Performance, Stability, and Design Compliance.

## 2. Application Domains & Targets

We manage multiple distinct applications within this repository. **Do not conflate their tech stacks.**

### A. Driver App (Mobile) `apps/driver`

- **Target OS**: iOS & Android.
- **State Management**: **Provider**.
- **Focus**:
  - **Offline-First**: Critical. Handle flaky networks gracefully (queueing, local caching).
  - **Battery & Data**: Optimize background location updates (`geolocator`) and map rendering (`flutter_map`).
  - **UX**: Large touch targets (>48px), simplified flows, high contrast for daylight visibility.
- **Key libs**: `flutter_map`, `geolocator`, `google_mlkit_text_recognition`.

### B. Terminal / Company App (Desktop) `apps/terminal`

- **Target OS**: macOS & Windows 10/11.
- **State Management**: **Riverpod** (strictly typed, prefer `riverpod_generator`).
- **Focus**:
  - **Productivity**: information density, keyboard shortcuts, multi-window workflows.
  - **Desktop Native**: Proper window sizing, window controls, and right-click context menus.
- **Key libs**: `fluent_ui`, `window_manager`, `flutter_riverpod`.

## 3. Design System: Fluent UI (Strict)

- **Primary Style**: **Fluent UI** (`fluent_ui` package) is the single source of truth, especially for the Terminal app.
- **References**:
  - [Windows App Design Guidelines](https://learn.microsoft.com/en-us/windows/apps/design) (**CRITICAL REFERENCE**)
  - [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- **Aesthetics**:
  - **Materials**: Use **Mica** or **Acrylic** effects for backgrounds/sidebars to provide depth.
  - **Typography**: `GoogleFonts.outfit` or standard Windows fonts (Segoe UI). Clean, legible hierarchy.
  - **Motion**: Subtle, meaningful micro-interactions (e.g., connected animations, drill-ins).
- **Responsiveness**:
  - The Terminal app must adapt gracefully from laptop screens (13") to ultra-wide monitors. Use `LayoutBuilder` or flexible widgets (`Flex`, `Expanded`).

## 4. Backend & Data Layer (Supabase)

- **Database**:
  - **Types**: Use strict Dart types generated from the DB schema. Do not use raw `Map<String, dynamic>` everywhere.
  - **Security**: **Row Level Security (RLS)** is mandatory. Never query without RLS enabled policies.
- **Auth**: Handle session persistence and token refresh automatically (`supabase_flutter` handles this, ensure it's initialized early).
- **Architecture**:
  - **Edge Functions**: Use Supabase Edge Functions for complex business logic, third-party webhooks (e.g., Stripe), or secure operations.
  - **Realtime**: Use subscriptions judiciously. Dispose of `StreamSubscriptions` immediately when widgets unmount to prevent leaks.

## 5. Engineering Standards (Scale)

- **Performance**:
  - **Const Constructors**: Use `const` wherever possible to reduce widget rebuilds.
  - **Lists**: Always use `ListView.builder` or `Slivers` for lists with >20 items.
  - **Images**: Cache network images. Use `memCacheHeight`/`memCacheWidth` to reduce memory usage.
- **Quality**:
  - **Error Handling**: No silent failures. Show user-friendly error toasts/dialogs (using `InfoBar` in Fluent).
  - **Logging**: Use a consistent logging strategy (avoid `print`; use `debugPrint` or a logger package).
- **Code Style**:
  - **Feature-First**: `lib/features/<feature>/...` (presentation, domain, data).
  - **Linting**: Strict adherence to `flutter_lints`. Resolve all warnings.

## 6. Antigravity Suggestions (Proactive Improvements)

- **CI/CD**: Ensure `fastlane` is configured for both Android and iOS inside `apps/driver`.
- **Testing Strategy**:
  - **Unit**: Test providers and repositories (mock `SupabaseClient`).
  - **Widget**: Test complex UI components (like the custom `StatusBar` or `DriverDetailPanel`) for varied states (loading, error, empty).
  - **Integration**: protect critical flows (Login -> specific Dashboard state) with `integration_test`.
- **Localization**:
  - No hardcoded strings. Use `app_en.arb` and `flutter_gen` for all user-facing text.

always make responsive windows for laptop screen to big monitor screen.

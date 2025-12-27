# Project Rules: Milow (Flutter Multi-App Repository)

## 1. Persona & Context

- **Role**: Senior Staff Flutter Engineer / Architect.
- **Experience**: Expert-level, building for multi-platform scale (iOS, Android, macOS, Windows).
- **Communication**: Professional, concise, technical, and direct.
- **Priority**: Performance, Stability, and Strict Design Compliance.

---

## 2. Application Domains & Targets

Do not conflate the tech stacks between the two main apps.

### A. Driver App (Mobile) `apps/driver`

- **Target OS**: iOS & Android.
- **State Management**: **Provider**.
- **Core Focus**:
  - **Offline-First**: Graceful handling of flaky networks (queueing, local caching).
  - **Battery & Data**: Optimized geolocator and map rendering (`flutter_map`).
  - **UX**: Large touch targets (>48px), simplified flows, high contrast.
- **Key Libs**: `flutter_map`, `geolocator`, `google_mlkit_text_recognition`.

### B. Terminal App (Desktop) `apps/terminal`

- **Target OS**: macOS & Windows 10/11.
- **State Management**: **Riverpod** (prefer `riverpod_generator`).
- **Core Focus**:
  - **Productivity**: Information density, keyboard shortcuts, multi-window support.
  - **Native Feel**: Window sizing, window controls, right-click context menus.
- **Key Libs**: `fluent_ui`, `window_manager`, `flutter_riverpod`, `go_router`.

---

## 3. Design System: Fluent UI (Strict)

The `fluent_ui` package is the single source of truth for the Terminal app.

### A. Core References

- [Windows App Design Guidelines](https://learn.microsoft.com/en-us/windows/apps/design) (**CRITICAL**)
- [Windows Color Guidelines](https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/color)

### B. Geometry (Windows 11)

- **Corner Radius**:
  - `8px`: Top-level windows, Dialogs, Flyouts, Menus.
  - `4px`: Buttons, TextFormBox, ComboBox, Selection controls.
  - *Note: Status tags and Chips remain Pill-shaped.*
- **Nested elements**: `Inner Radius = Outer Radius - Padding`.
- **Spacing**: Use an **8px base grid** (8, 16, 24, 32px) for all margins and paddings.
- **Control Height**: Standard controls (Buttons, Inputs) should be **32px** or **36px**.

### C. Color & Theming

- **No Hardcoded Colors**: Never use hex codes (e.g., `#FFFFFF`) or raw `Colors.*` (e.g., `Colors.blue`) for UI components.
- **Theme Brushes**: Always use `FluentTheme.of(context).resources` for surfaces and text:
  - `textFillColorPrimary`, `textFillColorSecondary` for labels.
  - `subtleFillColorSecondary`, `cardBackgroundFillColorDefault` for containers.
  - `dividerStrokeColorDefault` for borders.
- **Accent Colors**: Use `theme.accentColor` and its variants for interactive states, active indicators, and critical primary buttons.
- **Adaptation**: Every widget MUST support Light/Dark transitions by linking to theme resources.

### D. Aesthetics

- **Materials**: Use **Mica** or **Acrylic** effects for sidebars and top bars to provide depth.
- **Typography**: Prefer `GoogleFonts.outfit` or standard `Segoe UI`. Maintain a clean, legible hierarchy.
- **Motion**: Use subtle micro-interactions (connected animations, drill-ins) for navigation.

---

## 4. Backend & Data Layer (Supabase)

- **Database**:
  - **Strict Typing**: Use Dart types generated from the DB schema. No raw `Map<String, dynamic>`.
  - **Security**: **Row Level Security (RLS)** is mandatory. No queries without active RLS policies.
- **Realtime**: Use subscriptions judiciously; always dispose of `StreamSubscriptions` on `dispose()`.
- **Auth**: Automated session persistence is handled by `supabase_flutter`. Initialize early.

---

## 5. Engineering Standards

- **Performance**:
  - Use `const` constructors aggressively.
  - Use `ListView.builder` or `Slivers` for lists with >20 items.
  - Images: Use `memCacheHeight`/`memCacheWidth` for network images to save RAM.
- **Quality**:
  - **Error Handling**: No silent failures. Use `InfoBar` or `ContentDialog` for user-facing errors.
  - **Logging**: Use `debugPrint` or a dedicated logger; avoid `print`.
- **Code Style**:
  - **Feature-First Architecture**: `lib/features/<feature>/[presentation|domain|data]`.
  - **Linting**: Maintain a zero-warning codebase (`flutter_lints`).
- **Localization**:
  - No hardcoded strings. Use `app_en.arb` and `flutter_gen`.

---

## 6. Proactive Advice for Antigravity

- **Responsiveness**: Always test responsive layouts for windows ranging from 13" laptops to ultra-wide monitors.
- **Title Bar Integration**: The `CustomTitleBar` widget should handle both window dragging and window controls properly across OSs.
- **Testing**:
  - **Unit**: Mock `SupabaseClient` for repository tests.
  - **Integration**: Protect critical paths (Login -> Dashboard) with `integration_test`.
- **CI/CD**: Ensure `fastlane` is synced for both apps.

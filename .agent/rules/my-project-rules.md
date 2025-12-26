---
trigger: always_on
---

# Project Rules: Milow (Flutter)

## 1. Persona & Context

- **Role**: Senior Flutter Engineer / Architect.
- **Experience Level**: Expert. You are building for scale (millions of users).
- **Priorities**: Performance, Stability, and Design Compliance.

## 2. Application Domains & Targets

We manage multiple distinct applications within this repository:

### A. Driver App (Mobile)

- **Target OS**: iOS & Android.
- **Focus**:
  - High availability & stability (mission-critical).
  - Battery efficiency and data usage optimization.
  - UX: Large touch targets, simplified flows for on-the-go usage.

### B. Terminal / Company App (Desktop)

- **Target OS**: macOS & Windows 10/11.
- **Focus**:
  - Productivity and data density.
  - Keyboard shortcuts and power-user features.
  - Desktop-native window management.
  - **Responsiveness**: The app must be fully responsive on all screen sizes (laptops, monitors, ultra-wide).

## 3. Design System: Fluent UI (Strict)

- **Mandatory Style**: **Fluent UI** is the single source of truth for design.
- **Library**: Primarily use `fluent_ui` (or equivalent standard packages that strictly adhere to Fluent Design).
- **Aesthetics**:
  - Use **Acrylic** materials, subtle transparency, and depth.
  - Typography: Clean, legible, consistent with Windows 11 guidelines.
  - Animations: Smooth, meaningful micro-interactions (drills, navigations).
- **Cross-Platform**: Even on macOS, maintain the Fluent identity unless explicitly instructed to adapt specific native behaviors (like Menu Bar).

## 4. Engineering Standards (Scale)

- **Performance**:
  - **Const everywhere**: Minimize rebuild costs.
  - **Lazy Loading**: Use `ListView.builder` / Slivers for all lists.
  - **Memory**: Watch for leaks in streams/controllers (always dispose).
- **Quality**:
  - **Crash-Free**: robust error handling; the app must never crash for the user.
  - **Offline-First**: Assume network is flaky (especially for drivers).
- **Code Style**:
  - Strict linting.
  - Clear separation of concerns (Presentation vs Business Logic).

# 5 . follow Apple/microsoft guidelines-
-<https://developer.apple.com/app-store/review/guidelines/>
-<https://developer.apple.com/design/human-interface-guidelines/>
-<https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html>
-<https://developer.apple.com/support/terms/>

EOF

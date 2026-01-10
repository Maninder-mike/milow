---
trigger: always_on
---

---

trigger: always_on
---

# Project Rules: Milow (Flutter Multi-App Repository)

## 1. Persona & Context

- **Role**: Senior Staff Flutter Engineer / Architect.
- **Communication**: Professional, concise, technical, direct.
- **Priority**: Performance, Stability, Design Compliance.

---

## 2. Application Domains

**Do not conflate tech stacks between apps.**

### A. Driver App (Mobile) `apps/driver`

- **Target**: iOS & Android
- **State**: Provider
- **Focus**: Offline-first, battery optimization, 48px+ touch targets
- **Libs**: `flutter_map`, `geolocator`, `dynamic_color`, `cached_network_image`

### B. Terminal App (Desktop) `apps/terminal`

- **Target**: macOS & Windows 10/11
- **State**: Riverpod (`riverpod_generator`)
- **Focus**: Information density, keyboard shortcuts, native feel
- **Libs**: `fluent_ui`, `window_manager`, `flutter_riverpod`, `go_router`

- while implement right click function always use Context Menu

---

## 3. Design: M3 Expressive (Driver App)

> Ref: [M3 Expressive](https://m3.material.io/blog/building-with-m3-expressive)

### A. Color System

- **Dynamic Color**: Wrap `MaterialApp` with `DynamicColorBuilder`
- **Vibrant Scheme**: Use `DynamicSchemeVariant.vibrant`
- **No Hardcoded Colors**: Use `DesignTokens` via `context.tokens`
  - `tokens.textPrimary/Secondary/Tertiary`
  - `tokens.success/error/warning/info`
  - `tokens.surfaceContainer/inputBackground`

### B. Motion System

Use `M3ExpressiveMotion` from `lib/core/theme/m3_expressive_motion.dart`:

| Curve | Use |
|-------|-----|
| `standard` | Most animations |
| `emphasized` | Navigation, dialogs |
| `spring` | Bouncy effects |

| Duration | Value |
|----------|-------|
| `durationShort` | 150ms |
| `durationMedium` | 300ms |
| `durationLong` | 500ms |

### C. Widget Standards

| Use ✅ | Avoid ❌ |
|--------|---------|
| `FilledButton` | `ElevatedButton` |
| `NavigationBar` | `BottomNavigationBar` |
| `CachedNetworkImage` | `Image.network` |

### D. Component Theming

| Component | Standard |
|-----------|----------|
| Buttons | 20px radius |
| Dialogs | 28px radius |
| Cards | No elevation |
| BottomSheet | Show drag handle |
| PageTransitions | `PredictiveBackPageTransitionsBuilder` |

### E. Layout

- **Corner Radius**: 28px dialogs, 16px cards, 12px chips
- **Spacing**: 8px grid (8, 16, 24, 32)
- **Touch Targets**: Min 48x48dp
- **Safe Area**: Every screen wrapped

### F. Accessibility (WCAG 2.1 AA)

- Add `Semantics()` to interactive elements
- 4.5:1 color contrast minimum
- Test with TalkBack

### G. M3 Typography Scale

> Ref: [M3 Typography](https://m3.material.io/styles/typography/applying-type)

Use `GoogleFonts.outfit` with these specs:

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Display L/M/S | 57/45/36 | 400 | 64/52/44 |
| Headline L/M/S | 32/28/24 | 400 | 40/36/32 |
| Title L/M/S | 22/16/14 | 400/500/500 | 28/24/20 |
| Label L/M/S | 14/12/11 | 500 | 20/16/16 |
| Body L/M/S | 16/14/12 | 400 | 24/20/16 |

### H. M3 Shape Scale

> Ref: [M3 Shape](https://m3.material.io/styles/shape/overview)

Access via `context.tokens`:

| Token | Value | Use |
|-------|-------|-----|
| `shapeXS` | 4px | Chips, small buttons |
| `shapeS` | 8px | Text fields, small cards |
| `shapeM` | 12px | Cards, dialogs |
| `shapeL` | 16px | FAB, nav drawer |
| `shapeXL` | 28px | Hero cards, large dialogs |
| `shapeFull` | 999px | Circular/pill |

Legacy aliases: `radiusS`→`shapeS`, `radiusM`→`shapeM`, etc.

### I. M3 Elevation Levels

> Ref: [M3 Elevation](https://m3.material.io/styles/elevation/overview)

| Token | Value | Use |
|-------|-------|-----|
| `elevationLevel0` | 0dp | Surface |
| `elevationLevel1` | 1dp | Raised surfaces |
| `elevationLevel2` | 3dp | Cards, menus |
| `elevationLevel3` | 6dp | Dialogs |
| `elevationLevel4` | 8dp | Modals |
| `elevationLevel5` | 12dp | FAB pressed |

### J. Progress Indicators

- Use `strokeCap: StrokeCap.round` (M3 Expressive)
- Track color: `colorScheme.surfaceContainerHighest`
- Indicator color: `colorScheme.primary`

---

## 4. Design: Fluent UI (Terminal App)

> Ref: [Windows Design](https://learn.microsoft.com/en-us/windows/apps/design)

### A. Geometry

- **Radius**: 8px windows/dialogs, 4px buttons/inputs
- **Spacing**: 8px grid
- **Control Height**: 32-36px

- follow : <https://fluent2.microsoft.design/motion#choreography>, <https://fluent2.microsoft.design>, <https://developer.microsoft.com/en-ca/windows/develop>, <https://learn.microsoft.com/en-us/windows/apps/get-started/best-practices?source=recommendations>, <https://fluent2.microsoft.design/color>

### B. Color & Theming

- **No Hardcoded Colors**: Use `FluentTheme.of(context).resources`
  - `textFillColorPrimary/Secondary`
  - `subtleFillColorSecondary`
  - `cardBackgroundFillColorDefault`
- **Accent**: Use `theme.accentColor` for interactive states
- **Materials**: Mica for sidebars, Acrylic for flyouts

### C. Typography

- Use `GoogleFonts.outfit` or `Segoe UI`

---

## 5. Backend (Supabase)

- **Typing**: Use generated Dart types, no `Map<String, dynamic>`
- **Security**:
  - RLS mandatory on all tables
  - **Hardened Functions**: `SECURITY DEFINER` functions MUST include `SET search_path = public` to prevent Search Path Hijacking.
  - **Leaked Password Protection**: Must be enabled in Supabase Auth settings.
- **Performance**:
  - **RLS Optimization**: Wrap `auth.uid()` and other volatile functions in subqueries (e.g., `(SELECT auth.uid())`) in RLS policies to enable caching and prevent per-row evaluation.
  - **Indexing**: All foreign key columns MUST be indexed.
  - **Hygiene**: No duplicate/redundant indexes.
- **Realtime**: Dispose `StreamSubscriptions` in `dispose()`
- **Auth**: Initialize `supabase_flutter` early

---

## 6. Engineering Standards

### Performance

- Use `const` constructors aggressively
- `ListView.builder` for lists >20 items
- `memCacheHeight/Width` for network images

### Quality

- **Errors**: No silent failures. Show user-facing messages.
- **Logging**: `debugPrint`, never `print`

### Code Style

- **Architecture**: `lib/features/<feature>/[presentation|domain|data]`
- **Linting**: Zero warnings (`flutter_lints`)
- **Localization**: Use `.arb` files, no hardcoded strings

---

## 7. AI Assistant Guidelines

- Test layouts on 13" to ultra-wide screens
- Mock `SupabaseClient` for unit tests
- Protect critical paths with integration tests
- Keep `fastlane` synced for both apps
- Use Mica/Acrylic (Terminal), Material You (Driver)

- app respect the selected unit system , forms preseclect that system

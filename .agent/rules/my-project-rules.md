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
- **Context Menus**: Always use native context menus for right-click interactions

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

| Curve        | Use                    |
| ------------ | ---------------------- |
| `standard`   | Most animations        |
| `emphasized` | Navigation, dialogs    |
| `spring`     | Bouncy effects         |

| Duration         | Value |
| ---------------- | ----- |
| `durationShort`  | 150ms |
| `durationMedium` | 300ms |
| `durationLong`   | 500ms |

### C. Widget Standards

| Use ✅               | Avoid ❌               |
| -------------------- | ---------------------- |
| `FilledButton`       | `ElevatedButton`       |
| `NavigationBar`      | `BottomNavigationBar`  |
| `CachedNetworkImage` | `Image.network`        |

### D. Component Theming

| Component       | Standard                            |
| --------------- | ----------------------------------- |
| Buttons         | 20px radius                         |
| Dialogs         | 28px radius                         |
| Cards           | No elevation                        |
| BottomSheet     | Show drag handle                    |
| PageTransitions | `PredictiveBackPageTransitionsBuilder` |

### E. Layout

- **Corner Radius**: 28px dialogs, 16px cards, 12px chips
- **Spacing**: 8px grid (8, 16, 24, 32)
- **Touch Targets**: Min 48x48dp
- **Safe Area**: Every screen wrapped

### F. Accessibility (WCAG 2.1 AA)

- Add `Semantics()` to interactive elements
- 4.5:1 color contrast minimum
- Test with TalkBack and VoiceOver
- Support Dynamic Type / Large Text
- Ensure logical focus order for keyboard navigation

### G. M3 Typography Scale

> Ref: [M3 Typography](https://m3.material.io/styles/typography/applying-type)

Use `GoogleFonts.outfit` with these specs:

| Role          | Size      | Weight      | Line Height |
| ------------- | --------- | ----------- | ----------- |
| Display L/M/S | 57/45/36  | 400         | 64/52/44    |
| Headline L/M/S| 32/28/24  | 400         | 40/36/32    |
| Title L/M/S   | 22/16/14  | 400/500/500 | 28/24/20    |
| Label L/M/S   | 14/12/11  | 500         | 20/16/16    |
| Body L/M/S    | 16/14/12  | 400         | 24/20/16    |

### H. M3 Shape Scale

> Ref: [M3 Shape](https://m3.material.io/styles/shape/overview)

Access via `context.tokens`:

| Token       | Value | Use                     |
| ----------- | ----- | ----------------------- |
| `shapeXS`   | 4px   | Chips, small buttons    |
| `shapeS`    | 8px   | Text fields, small cards|
| `shapeM`    | 12px  | Cards, dialogs          |
| `shapeL`    | 16px  | FAB, nav drawer         |
| `shapeXL`   | 28px  | Hero cards, large dialogs|
| `shapeFull` | 999px | Circular/pill           |

### I. M3 Elevation Levels

> Ref: [M3 Elevation](https://m3.material.io/styles/elevation/overview)

| Token            | Value | Use           |
| ---------------- | ----- | ------------- |
| `elevationLevel0`| 0dp   | Surface       |
| `elevationLevel1`| 1dp   | Raised surfaces|
| `elevationLevel2`| 3dp   | Cards, menus  |
| `elevationLevel3`| 6dp   | Dialogs       |
| `elevationLevel4`| 8dp   | Modals        |
| `elevationLevel5`| 12dp  | FAB pressed   |

### J. Progress Indicators

- Use `strokeCap: StrokeCap.round` (M3 Expressive)
- Track color: `colorScheme.surfaceContainerHighest`
- Indicator color: `colorScheme.primary`

---

## 4. Design: Fluent UI (Terminal App)

> Ref: [Windows Design](https://learn.microsoft.com/en-us/windows/apps/design)
> Ref: [Fluent 2](https://fluent2.microsoft.design)

### A. Geometry

- **Radius**: 8px windows/dialogs, 4px buttons/inputs
- **Spacing**: 8px grid
- **Control Height**: 32-36px

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

### Typing & Data

- Use generated Dart types, no `Map<String, dynamic>`
- Validate all inputs with type-safe models
- Use database transactions for multi-step operations

### Security

- **RLS Mandatory**: All tables MUST have Row Level Security enabled
- **Hardened Functions**: `SECURITY DEFINER` functions MUST include `SET search_path = public`
- **Leaked Password Protection**: Enable in Supabase Auth settings
- **API Key Rotation**: Support key rotation without downtime
- **Audit Logging**: Enable for sensitive tables (user data, financial)

### Performance

- **RLS Optimization**: Wrap `auth.uid()` in subqueries: `(SELECT auth.uid())`
- **Indexing**: All foreign key columns MUST be indexed
- **Query Optimization**: Use `EXPLAIN ANALYZE` for complex queries
- **Connection Pooling**: Use PgBouncer for high-traffic scenarios
- **Hygiene**: No duplicate/redundant indexes

### Realtime

- Dispose `StreamSubscriptions` in `dispose()`
- Use channel-based subscriptions, not table-level
- Implement reconnection logic with exponential backoff

### Auth

- Initialize `supabase_flutter` early (before `runApp`)
- Handle token refresh gracefully
- Implement session persistence across app restarts

---

## 6. Engineering Standards

### Performance

- Use `const` constructors aggressively
- `ListView.builder` for lists >20 items
- `memCacheHeight/Width` for network images
- `RepaintBoundary` around expensive widgets (charts, maps)
- Avoid `Opacity` widget; use `color.withValues(alpha: x)` on paint
- Shader warm-up for complex gradients on app start
- Use `compute()` for heavy JSON parsing (>100KB)

### Quality

- **Errors**: No silent failures. Show user-facing messages.
- **Logging**: `debugPrint`, never `print`
- Use `Result<T, E>` pattern for error handling (fpdart or custom)
- Never catch generic `Exception`—be specific
- Log errors with context (user_id, screen, action)

### Code Style

- **Architecture**: `lib/features/<feature>/[presentation|domain|data]`
- **Linting**: Zero warnings (`flutter_lints`)
- **Localization**: Use `.arb` files, no hardcoded strings
- **RTL Support**: Test all screens with RTL locales

---

## 7. Observability & Monitoring (Enterprise Grade)

### Crash Reporting

- **Mandatory**: Firebase Crashlytics for all unhandled exceptions
- Wrap `runApp()` with `runZonedGuarded` to capture async errors
- Set `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`
- Include user context (user_id, app version, device) in crash reports
- Set up alerts for crash spikes (>1% increase)

### Analytics

- Track critical user journey events (signup, core features, payment)
- Use `AnalyticsService` abstraction—never call Firebase directly
- Implement funnel tracking for onboarding and key flows
- A/B test tracking with cohort assignment

### Performance Monitoring

- Enable Firebase Performance Monitoring for network calls
- Track app startup time (cold, warm, hot)
- Monitor frame rendering (jank detection)
- Set up Supabase `pg_stat_statements` for slow query detection
- Custom traces for critical code paths

### Alerting (PagerDuty/Opsgenie Style)

- Set up alerts for:
  - Error rate >1%
  - API latency p95 >2s
  - Crash-free sessions <99%
  - Database connection failures

---

## 8. Network Resilience

### Retry & Timeout

- Implement exponential backoff with jitter for all API calls
- Max 3 retries with delays: 1s, 2s, 4s (+ jitter)
- Timeouts: connect 10s, read 30s, write 30s
- Circuit breaker pattern for repeated failures

### Offline Support (Driver App Critical)

- Use `connectivity_plus` to detect offline state
- Queue mutations locally with `drift` or `hive`
- Sync on reconnection with conflict resolution
- Show clear offline indicator in UI

### Optimistic UI

- Update UI immediately on user action
- Reconcile on server response
- Rollback on failure with user notification

### Caching Strategy

- Stale-While-Revalidate for frequently accessed data
- Cache-first for static content (user profile, settings)
- Network-first for real-time data (trips, fuel prices)

---

## 9. Security Hardening

### Transport & Storage

- **Certificate Pinning**: Implement for production builds
- **Secure Storage**: Use `flutter_secure_storage` for tokens, NEVER `SharedPreferences`
- **Encryption at Rest**: Encrypt sensitive local databases

### Device Security

- **Jailbreak/Root Detection**: Warn or block on compromised devices
- **Debugger Detection**: Disable sensitive features when debugger attached
- **Screenshot Prevention**: Block screenshots on sensitive screens (payment, auth)

### Code Security

- **Obfuscation**: Enable `--obfuscate --split-debug-info` for release
- **No Embedded Secrets**: Use remote config or backend proxy for API keys
- **Deep Link Validation**: Sanitize all incoming parameters
- **Input Sanitization**: Validate and sanitize all user inputs

### Auth Security

- Implement biometric authentication for sensitive actions
- Session timeout after inactivity (15 min for Driver app)
- Force re-auth for critical actions (password change, delete account)
- Rate limiting on auth endpoints (backend)

---

## 10. Memory & Resource Management

### Image Handling

- Set max cache size (100MB) in `CachedNetworkImage`
- Use `memCacheHeight/Width` to limit decoded image size
- Resize images server-side when possible
- Clear image cache on low memory warning

### Stream & Controller Disposal

- Always cancel `StreamControllers` in `dispose()`
- Dispose `AnimationControllers`, `TextEditingControllers`
- Use `CancelableOperation` for async operations that may be cancelled
- Implement `AutoDispose` mixins for Riverpod providers

### Heavy Processing

- Use `compute()` for JSON parsing >100KB
- Offload image processing to isolates
- Batch database operations
- Paginate large data sets (max 50 items per page)

### Memory Profiling

- Run DevTools memory profiler on critical flows weekly
- Set up memory leak detection in CI (using `leak_tracker`)
- Monitor memory usage in production via Crashlytics

---

## 11. Testing Strategy

### Coverage Targets

| Layer          | Target | Priority |
| -------------- | ------ | -------- |
| Domain/Logic   | 90%    | 🔴 Critical |
| Data/Repository| 80%    | 🔴 Critical |
| Presentation   | 60%    | 🟡 High |
| Integration    | Critical flows | 🔴 Critical |
| E2E            | Happy paths | 🟡 High |

### Test Patterns

- Use `mocktail` for mocking (type-safe, no codegen)
- Test offline scenarios with mock connectivity
- Golden tests for design-critical UI components
- Snapshot testing for complex widgets
- Fuzz testing for input validation

### CI Enforcement

- Block PR merge if coverage drops
- Run `flutter analyze` with zero warnings
- Run tests on multiple Flutter versions
- Visual regression testing for UI changes

### Test Environments

- Dedicated Supabase project for testing
- Seed data for consistent test scenarios
- Mock external services (maps, payment)

---

## 12. App Lifecycle & State

### State Restoration

- Implement `RestorationMixin` for forms
- Persist navigation stack for deep linking
- Save draft data locally before background

### Background Handling

- Use `workmanager` for deferred uploads (Driver app)
- Handle `AppLifecycleState` changes gracefully
- Pause/resume location tracking appropriately
- Cancel pending operations on app termination

### Updates & Versioning

- Implement force update prompts via Firebase Remote Config
- Support gradual rollouts (1% → 10% → 50% → 100%)
- Maintain backward compatibility for 2 versions
- Version API with breaking change strategy

---

## 13. Performance Budgets

| Metric                | Target   | Measurement              |
| --------------------- | -------- | ------------------------ |
| App startup (cold)    | < 2s     | `--trace-startup`        |
| Frame render          | < 16ms   | DevTools, no jank        |
| App bundle (Android)  | < 30MB   | Deferred loading         |
| App bundle (iOS)      | < 50MB   | Asset optimization       |
| Image decode          | < 100ms  | Pre-cache, server resize |
| API response (p95)    | < 500ms  | Firebase Performance     |
| Time to Interactive   | < 3s     | Custom trace             |
| Memory (peak)         | < 300MB  | DevTools profiler        |

### Bundle Size Management

- Use `--analyze-size` regularly
- Implement deferred loading for features
- Tree-shake unused icons and assets
- Compress images (WebP/AVIF where supported)

---

## 14. Feature Flags & Experimentation

### Feature Flags

- Use Firebase Remote Config for all feature flags
- Default to "off" for new features
- Implement kill switch for every major feature
- Cache flags locally with TTL (1 hour)

### Rollout Strategy

| Stage | Percentage | Duration | Criteria to Advance |
| ----- | ---------- | -------- | ------------------- |
| 1     | 1%         | 24h      | No crash spike      |
| 2     | 10%        | 48h      | Metrics stable      |
| 3     | 50%        | 72h      | No major issues     |
| 4     | 100%       | -        | Full rollout        |

### A/B Testing

- Use Firebase A/B Testing for UI experiments
- Minimum sample size: 1000 users per variant
- Run tests for minimum 7 days
- Track both engagement and retention metrics

---

## 15. Incident Response & On-Call

### Severity Levels

| Level | Impact                      | Response Time | Example                     |
| ----- | --------------------------- | ------------- | --------------------------- |
| P0    | Complete outage             | 15 min        | App crash on launch         |
| P1    | Major feature broken        | 1 hour        | Cannot submit trips         |
| P2    | Minor feature broken        | 4 hours       | Chart not loading           |
| P3    | Cosmetic / Low impact       | 24 hours      | UI alignment issue          |

### Runbook Requirements

- Document rollback procedures for every release
- Database migration rollback scripts ready
- Feature flag kill switch tested
- Communication templates for user-facing issues

### Post-Incident

- Blameless postmortem within 48 hours
- Action items with owners and deadlines
- Update monitoring to detect similar issues

---

## 16. Release Engineering

### CI/CD Pipeline

- **PR Checks**: Lint, analyze, test, build
- **Main Branch**: Deploy to internal testing
- **Release Branch**: Deploy to staging → production
- **Hotfix**: Direct to production with expedited review

### Release Cadence

- Driver App: Weekly releases (Monday)
- Terminal App: Bi-weekly releases
- Hotfixes: As needed (P0/P1 only)

### Release Checklist

- [ ] All tests passing
- [ ] No new analyzer warnings
- [ ] Performance benchmarks met
- [ ] Crashlytics dashboard clear
- [ ] Release notes prepared
- [ ] Feature flags configured
- [ ] Rollback plan documented

---

## 17. Documentation Standards

### Code Documentation

- **TSDoc/DartDoc**: All public APIs documented
- **Why, not What**: Explain reasoning, not mechanics
- **Examples**: Include usage examples for complex APIs
- **Deprecation**: Use `@Deprecated` with migration path

### Architecture Decision Records (ADRs)

- Document significant technical decisions
- Include context, options considered, decision, consequences
- Store in `docs/adr/` directory

### API Documentation

- OpenAPI/Swagger for backend endpoints
- Keep Supabase schema documentation updated
- Document RLS policies and their rationale

---

## 18. Accessibility (Extended)

### Requirements

- WCAG 2.1 AA compliance minimum
- Support system font scaling (up to 200%)
- Full keyboard navigation (Terminal app)
- Screen reader compatibility (TalkBack, VoiceOver)
- Reduced motion support (`MediaQuery.reduceMotion`)

### Testing

- Automated accessibility testing in CI
- Manual testing with screen readers monthly
- Color contrast validation in design reviews
- Focus order verification for all screens

### Implementation

- Semantic labels for all interactive elements
- Proper heading hierarchy
- Live region announcements for dynamic content
- Touch target sizing (48x48dp minimum)

---

## 19. Internationalization (i18n)

### Requirements

- All user-facing strings in `.arb` files
- Support RTL layouts (Arabic, Hebrew)
- Date/time formatting via `intl`
- Number formatting (currencies, units)
- Plural and gender rules support

### Implementation

- Use `flutter_localizations`
- Implement locale switching without restart
- Cache locale preference
- Fallback to English for missing translations

### Quality

- Professional translation (no Google Translate for production)
- Context notes for translators in ARB files
- Screenshot context for translation platforms

---

## 20. AI Assistant Guidelines

### Development

- Test layouts on 13" to ultra-wide screens
- Mock `SupabaseClient` for unit tests
- Protect critical paths with integration tests
- Keep `fastlane` synced for both apps
- Use Mica/Acrylic (Terminal), Material You (Driver)

### Code Review Focus

- Performance impact of changes
- Memory leak potential
- Error handling completeness
- Accessibility compliance
- Security implications

### Before Suggesting Changes

- Check if pattern exists elsewhere in codebase
- Verify compatibility with existing architecture
- Consider impact on bundle size
- Ensure backward compatibility

### App-Specific

- App respects the selected unit system
- Forms preselect user's preferred unit system
- Currency formatting based on user locale

---

## 21. Third-Party Dependencies

### Selection Criteria

- Active maintenance (commits in last 3 months)
- Adequate test coverage
- No known security vulnerabilities
- Acceptable license (MIT, BSD, Apache 2.0)
- Community adoption (stars, downloads)

### Management

- Pin exact versions in `pubspec.yaml`
- Review changelogs before upgrading
- Run full test suite after upgrades
- Limit direct dependencies (prefer stable packages)

### Security

- Enable Dependabot/Renovate for vulnerability alerts
- Weekly dependency audit
- Immediate patching for critical vulnerabilities

---

## 22. Data Privacy & Compliance

### GDPR/CCPA Requirements

- Implement data export functionality
- Support account deletion with data purging
- Cookie/tracking consent management
- Privacy policy accessible in-app

### Data Handling

- Minimize data collection (only what's needed)
- Encrypt PII in transit and at rest
- Log access to sensitive data
- Implement data retention policies

### User Rights

- Right to access personal data
- Right to rectification
- Right to erasure (account deletion)
- Right to data portability

---

## 23. Platform-Specific Guidelines

### iOS

- Follow Human Interface Guidelines
- Support Dynamic Island for Driver app
- Handle permission requests gracefully
- Test on oldest supported iOS version (iOS 14+)

### Android

- Follow Material Design Guidelines
- Support predictive back gesture
- Handle runtime permissions correctly
- Test on Android Go devices for performance

### macOS (Terminal)

- Native menu bar integration
- Support keyboard shortcuts
- Handle window resize gracefully
- Sign and notarize for Gatekeeper

### Windows (Terminal)

- Follow Fluent Design System
- Support Windows 11 snap layouts
- Handle DPI scaling correctly
- MSIX packaging for Store distribution

---

*Last Updated: January 2026*
*Version: 3.0*

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-13

### Added

- **DEF Tracking**: Added Diesel Exhaust Fluid quantity and price inputs for truck fuel entries.
- **Yard Fuel**: Added "DEF filled from yard" toggle for cost tracking.
- **Native Sharing**: Implemented native Android sharing for better reliability.

### Changed

- **Profile UI**: Updated profile input fields to match the main app design (prefix icons, border styles).

### Fixed

- **Auth Crashes**: Fixed application crash during password reset and email verification flows.

### Removed

- **Scan Receipt**: Removed the unused "Scan Receipt" button from fuel entry.

## [1.0.0] - 2025-11-30

### Added

- Initial release of Milow trucking app
- User authentication (email/password, social login)
- Dashboard with weekly performance stats
- Trip recording with GPS tracking
- Fuel entry management
- Explore page with routes and destinations
- Records list with search and filter
- PDF export functionality with date range picker
- Swipe-to-delete and swipe-to-modify actions
- Dark/Light theme support
- Biometric authentication (Face ID / Fingerprint)

### Features

- **Authentication**: Secure login with email, Google, Apple, and Facebook
- **Dashboard**: View weekly stats, recent trips, and fuel entries
- **Trip Management**: Record trips with automatic GPS tracking
- **Fuel Tracking**: Log fuel purchases with station details
- **PDF Reports**: Export filtered records to professional PDF format
- **Theme Support**: Switch between light and dark modes

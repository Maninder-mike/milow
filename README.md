<h1 align="center">Milow</h1>

<p align="center">
  <strong>Fleet Management & Driver Operations Platform</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#apps">Apps</a> •
  <a href="#installation">Installation</a> •
  <a href="#development">Development</a> •
  <a href="#architecture">Architecture</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-Backend-3FCF8E?logo=supabase" alt="Supabase" />
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows-lightgrey" alt="Platforms" />
</p>

---

## Overview

Milow is a comprehensive fleet management solution designed for trucking and logistics companies. It consists of two purpose-built applications:

- **Milow Driver** — Mobile app for drivers to log trips, fuel purchases, and expenses
- **Milow Terminal** — Desktop app for dispatchers and fleet managers

Built with performance, reliability, and offline-first capabilities at its core.

---

## Features

### 🚛 Driver App (iOS & Android)

| Feature | Description |
|---------|-------------|
| **Trip Logging** | Record pickups, deliveries, border crossings, and trailers |
| **Fuel Tracking** | Log fuel and DEF purchases with receipt scanning |
| **Expense Management** | Capture receipts and categorize expenses |
| **Offline-First** | Full functionality without internet connection |
| **Document Scanner** | AI-powered receipt and document scanning |
| **Dynamic Theming** | Material You with wallpaper-based colors |

### 🖥️ Terminal App (macOS & Windows)

| Feature | Description |
|---------|-------------|
| **Fleet Dashboard** | Real-time vehicle status and location overview |
| **Driver Management** | Assign drivers to vehicles, track HOS compliance |
| **Dispatch Board** | Drag-and-drop load assignment and routing |
| **IFTA Reporting** | Automated fuel tax calculation and reporting |
| **User Roles** | Admin, dispatcher, and viewer permission levels |
| **Biometric Login** | Touch ID / Windows Hello support |

---

## Apps

### Milow Driver

```
apps/driver/
├── lib/
│   ├── core/           # Theme, providers, services
│   └── features/       # Feature modules (trips, fuel, expenses)
└── test/               # Unit and widget tests
```

**Platforms:** iOS 15+, Android 8.0+

### Milow Terminal

```
apps/terminal/
├── lib/
│   ├── core/           # Router, providers, theme
│   └── features/       # Feature modules (auth, dashboard, dispatch)
└── test/               # Unit and widget tests
```

**Platforms:** macOS 12+, Windows 10+

---

## Installation

### Milow Terminal (macOS)

#### Install

```bash
brew tap Maninder-mike/milow-terminal
brew install --cask milow-terminal
```

#### Update

```bash
brew update
brew upgrade --cask milow-terminal
```

#### Uninstall

```bash
brew uninstall --cask milow-terminal
brew untap Maninder-mike/milow-terminal
```

#### Troubleshooting

If you encounter issues during installation or update:

```bash
# Clear Homebrew cache
brew cleanup --prune=all

# Reinstall from scratch
brew uninstall --cask milow-terminal
brew untap Maninder-mike/milow-terminal
brew tap Maninder-mike/milow-terminal
brew install --cask milow-terminal
```

### Milow Terminal (Windows)

Available on the [Microsoft Store](https://apps.microsoft.com/detail/9p641q1x1bmg).

### Milow Driver

**Android:** Available on the [Google Play Store](https://play.google.com/store/apps/details?id=maninder.co.in.milow)

**iOS:** Coming soon to the App Store

---

## Development

### Prerequisites

- Flutter SDK 3.32+
- Dart 3.10+
- Xcode 15+ (for iOS/macOS)
- Android Studio (for Android)
- Visual Studio 2022 (for Windows)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/Maninder-mike/milow.git
cd milow

# Install dependencies
flutter pub get

# Create environment file
cp apps/terminal/.env.example apps/terminal/.env
# Edit .env with your Supabase credentials

# Run the Terminal app
cd apps/terminal && flutter run -d macos

# Run the Driver app
cd apps/driver && flutter run
```

### Running Tests

```bash
# All tests
flutter test

# Terminal app tests
cd apps/terminal && flutter test

# Driver app tests
cd apps/driver && flutter test
```

### Code Quality

```bash
# Static analysis
flutter analyze

# Format code
dart format .
```

---

## Architecture

### Monorepo Structure

```
milow/
├── apps/
│   ├── driver/         # Mobile app (iOS/Android)
│   └── terminal/       # Desktop app (macOS/Windows)
├── packages/
│   └── core/           # Shared business logic
├── database/
│   └── migrations/     # Supabase migrations
└── .github/
    └── workflows/      # CI/CD pipelines
```

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter, Riverpod, go_router |
| **UI (Mobile)** | Material 3 Expressive |
| **UI (Desktop)** | Fluent UI |
| **Backend** | Supabase (PostgreSQL, Auth, Storage) |
| **CI/CD** | GitHub Actions |
| **Distribution** | Play Store, Homebrew, Windows Store |

### State Management

- **Driver App:** Provider
- **Terminal App:** Riverpod with code generation

---

## Security

- Row-Level Security (RLS) on all database tables
- JWT-based authentication via Supabase Auth
- Compile-time secrets injection for production builds
- Biometric authentication support

---

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is proprietary software. All rights reserved.

---

<p align="center">
  Built with ❤️ by the Milow Team
</p>

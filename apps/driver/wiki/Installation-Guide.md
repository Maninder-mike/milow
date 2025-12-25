# 📦 Installation Guide

Complete guide to setting up Milow for development.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** 3.10 or higher
- **Dart SDK** 3.10 or higher
- **Android Studio** (for Android development) or **Xcode** (for iOS development)
- **Git** for version control
- **A Supabase account** (free tier available at [supabase.com](https://supabase.com))

### Verify Flutter Installation

```bash
flutter doctor
```

This command checks your environment and displays a report of the status of your Flutter installation.

## Step-by-Step Installation

### 1. Clone the Repository

```bash
git clone https://github.com/maninder-mike/milow.git
cd milow
```

### 2. Set Up Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project-id.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

**Where to find these values:**

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Settings → API**
4. Copy the values for:
   - Project URL → `NEXT_PUBLIC_SUPABASE_URL`
   - `anon` `public` key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `service_role` `secret` key → `SUPABASE_SERVICE_ROLE_KEY`

### 3. Install Dependencies

```bash
flutter pub get
```

This downloads all the required packages specified in `pubspec.yaml`.

### 4. Set Up the Database

1. Open your Supabase project dashboard
2. Go to **SQL Editor**
3. Run the following SQL files in order:
   - `supabase_schema.sql` - Main database schema
   - `supabase_app_version_schema.sql` - App version tracking
   - `supabase_migration_add_border_crossing.sql` - Border crossing feature

### 5. Configure Authentication Providers

In your Supabase dashboard:

1. Go to **Authentication → Providers**
2. Enable the following providers:
   - **Email** (enabled by default)
   - **Google** (optional, requires OAuth credentials)
   - **Apple** (optional, requires Apple Developer account)

### 6. Run the App

For development:

```bash
flutter run
```

Select your target device when prompted (Android emulator, iOS simulator, or physical device).

## Platform-Specific Setup

### Android

1. **Android Studio**: Install Android Studio with Android SDK
2. **Emulator**: Create an Android Virtual Device (AVD)
3. **USB Debugging**: Enable on physical device if testing on hardware

### iOS (macOS only)

1. **Xcode**: Install from Mac App Store
2. **CocoaPods**: Install via `sudo gem install cocoapods`
3. **iOS Simulator**: Included with Xcode
4. **Physical Device**: Requires Apple Developer account for signing

## Building for Production

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS (macOS only)

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode to archive and upload to App Store.

## Troubleshooting

### Common Issues

**"Flutter command not found"**

- Add Flutter to your PATH: `export PATH="$PATH:`pwd`/flutter/bin"`

**"Gradle build failed"**

- Clean the build: `flutter clean && flutter pub get`
- Check Android SDK installation in Android Studio

**"CocoaPods not installed"**

- Install: `sudo gem install cocoapods`
- Run: `cd ios && pod install`

**"Supabase connection failed"**

- Verify `.env` file exists and has correct values
- Check internet connection
- Verify Supabase project is active

## Next Steps

- Read the [Quick Start](Quick-Start) guide
- Explore [Feature Overview](Feature-Overview)
- Check [Configuration](Configuration) options

---

Need help? [Open an issue](https://github.com/maninder-mike/milow/issues)

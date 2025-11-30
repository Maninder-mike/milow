# 🚛 Milow - Semi Trucking App

A modern Flutter mobile application designed for semi-truck drivers and trucking companies to manage trips, track fuel consumption, and streamline their daily operations.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?style=flat&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat&logo=supabase&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## ✨ Features

### 🔐 Authentication

- Secure email/password authentication
- Social login integration (Google, Apple, Facebook)
- Biometric authentication support (Face ID / Fingerprint)

### 📊 Dashboard

- Weekly performance statistics
- Trip and fuel entry tracking
- Quick stats overview (miles, fuel, earnings)
- Recent records with detailed views

### 🗺️ Explore

- Browse available routes
- Discover destinations
- View recommended activities
- Search functionality

### 🚚 Trip Management

- Record new trips with origin/destination
- Track mileage automatically with GPS
- Add fuel entries with station details
- Swipe-to-edit and swipe-to-delete actions

### 📄 Records & Export

- View all trip and fuel records
- Advanced filtering (by type, distance, date)
- Search records by ID or route
- **Export to PDF** with professional formatting
- Share reports via email, AirDrop, etc.

### ⚙️ Settings

- Dark/Light theme support
- Profile management
- Notification preferences
- App customization

## 📱 Screenshots

<table>
  <tr>
    <td><img src="screenshots/login.png" width="200" alt="Login Screen"/></td>
    <td><img src="screenshots/dashboard.png" width="200" alt="Dashboard"/></td>
    <td><img src="screenshots/explore.png" width="200" alt="Explore"/></td>
    <td><img src="screenshots/records.png" width="200" alt="Records"/></td>
  </tr>
</table>

> Note: Add your screenshots to a `screenshots/` folder

## 🛠️ Tech Stack

- **Framework**: Flutter 3.10+
- **Language**: Dart 3.10+
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **State Management**: Provider
- **Routing**: go_router
- **UI**: Material Design 3 + Google Fonts
- **PDF Generation**: pdf package
- **Location**: Geolocator + Geocoding

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.10 or higher
- Dart SDK 3.10 or higher
- Android Studio / Xcode (for mobile development)
- A Supabase account (free tier available)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/milow.git
   cd milow
   ```

2. **Set up environment variables**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your Supabase credentials:

   ```env
   NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   RESEND_API_KEY=your_resend_api_key
   ```

3. **Install dependencies**

   ```bash
   flutter pub get
   ```

4. **Set up the database**

   Run the SQL schema in your Supabase dashboard:

   ```bash
   # Import supabase_schema.sql in Supabase SQL Editor
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### Build for Production

**Android:**

```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

**iOS:**

```bash
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── constants/           # App constants
│   ├── services/            # Core services (auth, api)
│   ├── theme/               # Theme configuration
│   └── widgets/             # Shared widgets
└── features/
    ├── auth/                # Authentication screens
    ├── dashboard/           # Dashboard & records
    ├── explore/             # Explore routes & destinations
    ├── inbox/               # Messages & notifications
    ├── settings/            # App settings
    └── trips/               # Trip management
```

## 🔧 Configuration

### Supabase Setup

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to Settings → API to get your credentials
3. Import `supabase_schema.sql` in the SQL Editor
4. Enable authentication providers (Email, Google, Apple)

### Environment Variables

| Variable                        | Description               |
| ------------------------------- | ------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`      | Your Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anonymous key    |
| `SUPABASE_SERVICE_ROLE_KEY`     | Supabase service role key |
| `RESEND_API_KEY`                | Resend API key for emails |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Maninder**

- GitHub: [@yourusername](https://github.com/yourusername)

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [Supabase](https://supabase.com) - Backend as a Service
- [Google Fonts](https://fonts.google.com) - Typography
- [Material Design](https://material.io) - Design system

---

<p align="center">Made with ❤️ using Flutter</p>

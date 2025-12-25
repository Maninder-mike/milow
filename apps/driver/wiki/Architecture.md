# 🏗️ Architecture

Technical overview of Milow's architecture and design patterns.

## Project Structure

```
milow/
├── android/                 # Android-specific code
├── ios/                     # iOS-specific code
├── assets/                  # Images, fonts, and other assets
│   └── images/             # App icons and images
├── lib/                     # Main application code
│   ├── main.dart           # App entry point
│   ├── l10n/               # Localization files
│   ├── core/               # Core functionality
│   │   ├── constants/      # App-wide constants
│   │   ├── models/         # Data models
│   │   ├── services/       # Business logic services
│   │   ├── theme/          # Theme configuration
│   │   ├── utils/          # Utility functions
│   │   └── widgets/        # Reusable widgets
│   └── features/           # Feature modules
│       ├── auth/           # Authentication
│       ├── dashboard/      # Dashboard & records
│       ├── explore/        # Explore routes
│       ├── inbox/          # Notifications
│       ├── settings/       # App settings
│       └── trips/          # Trip management
├── test/                    # Unit and widget tests
├── .env                     # Environment variables (gitignored)
├── .env.example             # Environment template
├── pubspec.yaml             # Dependencies
└── supabase_schema.sql      # Database schema
```

## Architecture Pattern

Milow follows a **Feature-First** architecture with **Clean Architecture** principles.

### Layers

```
┌─────────────────────────────────────┐
│        Presentation Layer           │
│  (UI, Widgets, State Management)    │
├─────────────────────────────────────┤
│         Business Logic Layer        │
│     (Services, Use Cases)           │
├─────────────────────────────────────┤
│          Data Layer                 │
│  (Repositories, Data Sources)       │
└─────────────────────────────────────┘
```

### Feature Module Structure

Each feature follows this structure:

```
feature_name/
├── data/
│   ├── models/              # Data models
│   ├── repositories/        # Data repositories
│   └── datasources/         # API/Local data sources
├── domain/
│   ├── entities/            # Business entities
│   └── usecases/            # Business logic
└── presentation/
    ├── pages/               # UI screens
    ├── widgets/             # Feature-specific widgets
    └── providers/           # State management
```

## State Management

### Provider Pattern

Milow uses **Provider** for state management:

```dart
// Example: Trip Provider
class TripProvider extends ChangeNotifier {
  List<Trip> _trips = [];
  
  Future<void> loadTrips() async {
    _trips = await TripService.getTrips();
    notifyListeners();
  }
}

// Usage in UI
Consumer<TripProvider>(
  builder: (context, provider, child) {
    return ListView.builder(
      itemCount: provider.trips.length,
      itemBuilder: (context, index) => TripCard(provider.trips[index]),
    );
  },
)
```

### State Types

1. **Local State**: Widget-level state (StatefulWidget)
2. **Feature State**: Feature-level state (Provider)
3. **Global State**: App-wide state (Provider at root)
4. **Persistent State**: Cached data (Hive, SharedPreferences)

## Navigation

### Go Router

Declarative routing with **go_router**:

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TabsShell(),
    ),
    GoRoute(
      path: '/trip/:id',
      builder: (context, state) => TripDetailPage(
        tripId: state.pathParameters['id']!,
      ),
    ),
  ],
);
```

### Navigation Patterns

- **Bottom Navigation**: Main app tabs (Dashboard, Explore, Trips, Inbox, Settings)
- **Stack Navigation**: Drill-down screens
- **Modal Navigation**: Dialogs and bottom sheets

## Data Flow

### Service Layer Pattern

```
UI Widget
    ↓
Provider (State)
    ↓
Service (Business Logic)
    ↓
Repository (Data Access)
    ↓
Data Source (API/Local)
```

### Example: Loading Trips

```dart
// 1. UI triggers load
ElevatedButton(
  onPressed: () => context.read<TripProvider>().loadTrips(),
)

// 2. Provider calls service
class TripProvider {
  Future<void> loadTrips() async {
    _trips = await TripService.getTrips();
    notifyListeners();
  }
}

// 3. Service fetches from Supabase
class TripService {
  static Future<List<Trip>> getTrips() async {
    final response = await supabase
      .from('trips')
      .select()
      .order('trip_date', ascending: false);
    return response.map((e) => Trip.fromJson(e)).toList();
  }
}
```

## Backend Architecture

### Supabase Stack

```
┌─────────────────────────────────────┐
│         Flutter App                 │
└────────────┬────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│      Supabase Client SDK            │
└────────────┬────────────────────────┘
             │
    ┌────────┴────────┐
    ↓                 ↓
┌─────────┐    ┌──────────────┐
│  Auth   │    │  PostgreSQL  │
└─────────┘    └──────────────┘
```

### Database Schema

**Tables:**

- `profiles` - User profiles
- `trips` - Trip records
- `fuel_entries` - Fuel consumption records
- `app_version` - App version tracking
- `notifications` - User notifications

**Row Level Security (RLS):**

- Users can only access their own data
- Service role bypasses RLS for admin operations

## Design Patterns

### Repository Pattern

Abstracts data sources:

```dart
abstract class TripRepository {
  Future<List<Trip>> getTrips();
  Future<Trip> getTripById(String id);
  Future<void> createTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> deleteTrip(String id);
}

class SupabaseTripRepository implements TripRepository {
  // Implementation using Supabase
}
```

### Service Locator

Services are accessed statically:

```dart
class TripService {
  static Future<List<Trip>> getTrips() async {
    // Implementation
  }
}

// Usage
final trips = await TripService.getTrips();
```

### Factory Pattern

Model creation from JSON:

```dart
class Trip {
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      tripNumber: json['trip_number'],
      // ...
    );
  }
}
```

## Performance Optimizations

### Data Prefetching

```dart
class DataPrefetchService {
  static final instance = DataPrefetchService._();
  
  List<Trip>? cachedTrips;
  List<FuelEntry>? cachedFuelEntries;
  
  Future<void> prefetchData() async {
    cachedTrips = await TripService.getTrips();
    cachedFuelEntries = await FuelService.getFuelEntries();
  }
}
```

### Image Optimization

- Cached network images
- Lazy loading
- Thumbnail generation

### List Rendering

- `ListView.builder` for large lists
- Pagination for infinite scroll
- Shimmer loading states

## Security

### Authentication Flow

```
User Login
    ↓
Supabase Auth
    ↓
JWT Token
    ↓
Secure Storage
    ↓
Auto-refresh
```

### Data Encryption

- Credentials stored in secure storage (Keychain/Keystore)
- HTTPS for all API calls
- Row Level Security in database

### Environment Variables

Sensitive data in `.env`:

- Never committed to git
- Loaded at runtime
- Different values for dev/prod

## Testing Strategy

### Unit Tests

```dart
test('Trip model fromJson', () {
  final json = {'id': '1', 'trip_number': 'T001'};
  final trip = Trip.fromJson(json);
  expect(trip.id, '1');
  expect(trip.tripNumber, 'T001');
});
```

### Widget Tests

```dart
testWidgets('TripCard displays trip number', (tester) async {
  await tester.pumpWidget(TripCard(trip: mockTrip));
  expect(find.text('T001'), findsOneWidget);
});
```

### Integration Tests

- End-to-end user flows
- API integration tests
- Database operations

## Build & Deployment

### CI/CD Pipeline

```yaml
# .github/workflows/build_and_release.yml
on:
  push:
    branches: [release]

jobs:
  build:
    - Build signed APK
    - Create GitHub release
    - Upload APK
    - Update Supabase version table
```

### Release Process

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Push to `release` branch
4. GitHub Actions builds and releases
5. APK available in Releases

## Dependencies

### Core Dependencies

- `flutter` - UI framework
- `supabase_flutter` - Backend SDK
- `provider` - State management
- `go_router` - Navigation
- `google_fonts` - Typography

### Utility Dependencies

- `intl` - Internationalization
- `shared_preferences` - Local storage
- `hive` - NoSQL database
- `geolocator` - GPS location
- `pdf` - PDF generation

See [pubspec.yaml](https://github.com/maninder-mike/milow/blob/main/pubspec.yaml) for complete list.

---

**Next**: Learn about [Code Style Guide](Code-Style-Guide) and [Contributing](Contributing)

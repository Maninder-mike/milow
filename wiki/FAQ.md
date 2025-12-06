# ❓ FAQ (Frequently Asked Questions)

Common questions and answers about Milow.

## General

### What is Milow?

Milow is a mobile app for semi-truck drivers and trucking companies to manage trips, track fuel consumption, and generate professional reports.

### Is Milow free?

Yes, Milow is currently free and open-source. Backend costs are covered by Supabase's free tier.

### What platforms does Milow support?

- **Android**: Fully supported (Android 5.0+)
- **iOS**: Coming soon
- **Web**: Not currently supported

### Do I need an internet connection?

- **To sync data**: Yes
- **To view cached data**: No
- **To add new entries**: No (syncs when online)

## Account & Authentication

### How do I create an account?

1. Download the app
2. Tap "Sign Up"
3. Enter email and password
4. Verify your email
5. Complete profile setup

### Can I use social login?

Yes! Milow supports:

- Google Sign-In
- Apple Sign-In (iOS)
- Facebook Login

### I forgot my password. What do I do?

1. Tap "Forgot Password" on login screen
2. Enter your email
3. Check email for reset link
4. Create new password

### How do I enable biometric login?

1. Go to Settings
2. Tap "Security"
3. Enable "Biometric Lock"
4. Authenticate with Face ID/Fingerprint

### Can I have multiple accounts?

Yes, but you'll need to sign out and sign in with different credentials. Data is separate per account.

## Trip Management

### How do I add a trip?

1. Tap the + button
2. Select "Trip"
3. Fill in required fields (Trip #, Truck #, Date)
4. Add optional details
5. Tap "Save"

### Can I add multiple pickup/delivery locations?

Yes! Tap the + button next to "Pickup Locations" or "Delivery Locations" to add more.

### How does GPS distance calculation work?

When you add locations, Milow uses geocoding to find coordinates and calculates the driving distance between them.

### Can I edit a trip after saving?

Yes! Swipe right on the trip or tap to expand and use the edit icon.

### How do I delete a trip?

Swipe left on the trip and tap "Delete". Confirm the deletion. **Note**: This cannot be undone!

### Can I attach photos to trips?

Yes, you can attach multiple photos to document your trip.

## Fuel Tracking

### What's the difference between Truck and Reefer fuel?

- **Truck Fuel**: Fuel for the truck engine
- **Reefer Fuel**: Fuel for the refrigeration unit

### Can I track fuel costs?

Yes! Add the fuel cost when creating a fuel entry.

### How do I change fuel units?

1. Go to Settings
2. Tap "Preferences"
3. Select "Fuel Unit"
4. Choose Gallons or Liters

## Records & Export

### How do I view all my records?

1. Go to Dashboard
2. Tap "See more" under Recent Records
3. Or go to Trips tab → Records

### Can I filter my records?

Yes! You can filter by:

- Type (Trips, Fuel, or All)
- Distance (Short, Medium, Long)
- Date range
- Search by trip number or location

### How do I export to PDF?

1. Open Records page
2. Tap the export icon (download)
3. Select date range and filters
4. Choose columns to include
5. Tap "Generate PDF"
6. Save or share

### What format is the PDF?

Professional format with:

- Header with app logo
- Your profile info
- Date range
- Data in table format
- Page numbers

### Can I customize the PDF columns?

Yes! Before generating, you can select which columns to include in the export.

### Where are PDFs saved?

PDFs are saved to your device's Downloads folder. You can also share directly via email, messaging, or cloud storage.

## Settings & Preferences

### How do I change the theme?

1. Go to Settings
2. Tap "Appearance"
3. Select Light, Dark, or System

### Can I change the app's accent color?

Yes! In Settings → Appearance → Accent Color

### How do I change distance units?

1. Settings → Preferences
2. Select "Distance Unit"
3. Choose Miles or Kilometers

### How do I disable the weather widget?

1. Settings → Preferences
2. Toggle off "Show Weather"

### How do I turn off trucking news?

1. Settings → Preferences
2. Toggle off "Show Trucking News"

## Data & Privacy

### Where is my data stored?

Your data is securely stored in Supabase (PostgreSQL database) with encryption and Row Level Security.

### Can others see my data?

No. Your data is private and only accessible to you. Row Level Security ensures users can only access their own records.

### How do I backup my data?

Export your records to PDF regularly. You can also use Supabase's backup features if self-hosting.

### How do I delete my account?

1. Settings → Account
2. Tap "Delete Account"
3. Enter password to confirm
4. **Warning**: All data will be permanently deleted!

### Is my data encrypted?

Yes! Data is encrypted in transit (HTTPS) and at rest in the database.

## Technical

### What version of Flutter is required?

Flutter 3.10 or higher is required for development.

### Can I self-host the backend?

Yes! Milow uses Supabase which can be self-hosted. See the [Installation Guide](Installation-Guide) for details.

### How do I report a bug?

[Open an issue](https://github.com/maninder-mike/milow/issues) on GitHub with:

- Description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

### How do I request a feature?

[Open an issue](https://github.com/maninder-mike/milow/issues) with the "enhancement" label and describe your feature request.

### Is the source code available?

Yes! Milow is open-source under the MIT License. View the code on [GitHub](https://github.com/maninder-mike/milow).

## Troubleshooting

### The app won't load my data

1. Check internet connection
2. Pull down to refresh
3. Sign out and sign back in
4. Clear app cache (Settings → Storage)

### GPS location isn't working

1. Enable location permissions in device settings
2. Ensure GPS is turned on
3. Try restarting the app
4. Check if location services are enabled for Milow

### PDF export fails

1. Check storage permissions
2. Ensure enough free space on device
3. Try exporting a smaller date range
4. Restart the app

### Biometric login stopped working

1. Check device biometric settings
2. Re-enable in Milow Settings
3. Make sure biometric data is enrolled on device
4. Update app to latest version

### App crashes on startup

1. Clear app cache
2. Reinstall the app
3. Check if device meets minimum requirements (Android 5.0+)
4. Report the crash on GitHub

### Sync issues

1. Check internet connection
2. Sign out and sign back in
3. Pull to refresh on all screens
4. Check Supabase service status

## Updates

### How do I update the app?

1. Check [GitHub Releases](https://github.com/maninder-mike/milow/releases)
2. Download latest APK
3. Install over existing app (data preserved)

### Will I lose data when updating?

No! Your data is stored in the cloud and locally. Updates preserve all your data.

### How often is the app updated?

Updates are released as new features are developed and bugs are fixed. Check the [CHANGELOG](https://github.com/maninder-mike/milow/blob/main/CHANGELOG.md) for version history.

## Contributing

### Can I contribute to Milow?

Yes! Contributions are welcome. See the [Contributing Guide](Contributing) for details.

### I found a typo in the documentation

Great! You can:

1. [Open an issue](https://github.com/maninder-mike/milow/issues)
2. Or submit a pull request with the fix

### How do I suggest improvements?

Open an issue on GitHub with your suggestion. Be specific about what you'd like to see improved and why.

---

**Still have questions?** [Open an issue](https://github.com/maninder-mike/milow/issues) or check the [Troubleshooting](Troubleshooting) guide.

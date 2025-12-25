import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('pa'),
    Locale('ur'),
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Milow'**
  String get appName;

  /// Label for the profile section
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Label for the edit profile button or screen
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Label for the notifications section
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Label for the appearance settings section
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Label for the language settings section
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label for the privacy and security settings section
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurity;

  /// Label for the sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Label for the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label for the dashboard screen
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Label for categories section
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// Label for popular destinations section
  ///
  /// In en, this message translates to:
  /// **'Popular Destinations'**
  String get popularDestinations;

  /// Label for recent activity section
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// Label for logs section
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// Label for total driven miles statistic
  ///
  /// In en, this message translates to:
  /// **'Miles'**
  String get totalDrivenMiles;

  /// Label for the trips section
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips;

  /// Label for the explore section
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// Label for the inbox section
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// Label for the home section
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Label for the support section
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Label for add entry button
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get addEntry;

  /// Label for save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label for cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Label for delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Label for edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Text displayed while content is loading
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Label for error state
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Label for success state
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Label for email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Label for password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Label for sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Label for sign up button
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Label for forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Label for create account button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Text asking if user already has an account
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Text asking if user doesn't have an account
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Label for full name field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Label for phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Label for address field
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Label for country field
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Label for company name field
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get companyName;

  /// Label for company code field
  ///
  /// In en, this message translates to:
  /// **'Company Code'**
  String get companyCode;

  /// Label for unit system selection
  ///
  /// In en, this message translates to:
  /// **'Unit System'**
  String get unitSystem;

  /// Label for metric unit system
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// Label for imperial unit system
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// Label for toggle to show weather on dashboard
  ///
  /// In en, this message translates to:
  /// **'Show Weather on Dashboard'**
  String get showWeather;

  /// Label for border wait times section
  ///
  /// In en, this message translates to:
  /// **'Border Wait Times'**
  String get borderWaitTimes;

  /// Label for dark mode option
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Label for light mode option
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// Label for system default theme option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// Title for language selection screen
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get selectLanguage;

  /// Message displayed when language is changed
  ///
  /// In en, this message translates to:
  /// **'Language changed to {language}'**
  String languageChangedTo(String language);

  /// Message displayed for incomplete translations
  ///
  /// In en, this message translates to:
  /// **'Language support is coming soon. The app will be fully translated in future updates.'**
  String get languageComingSoon;

  /// Label for truck
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get truck;

  /// Label for trailer
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get trailer;

  /// Label for origin location
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// Label for destination location
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// Label for distance
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// Label for messages and notifications
  ///
  /// In en, this message translates to:
  /// **'Messages and notifications'**
  String get messagesAndNotifications;

  /// Label for fuel
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get fuel;

  /// Label for date
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Label for time
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Label for notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Label for total
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Label for yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Label for this week
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// Label for this month
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// Label for all time
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// Message when no trips are found
  ///
  /// In en, this message translates to:
  /// **'No trips found'**
  String get noTripsFound;

  /// Message encouraging user to add their first trip
  ///
  /// In en, this message translates to:
  /// **'Add your first trip to get started'**
  String get addYourFirstTrip;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Welcome back message
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// Button label to get started
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Button label to continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// Button label to skip
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Button label for next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Button label for back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Button label for done
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Button label to close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Label for search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Label for filter
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Label for sort
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// Label for refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Label to retry an action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Message when no data is available
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// Message when no search results are found
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// Confirmation message before deletion
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get confirmDelete;

  /// Yes option
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No option
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Subtitle on the sign in screen
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your journey'**
  String get signInSubtitle;

  /// Label for email address field
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// Hint text for password entry
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPasswordHint;

  /// Separator text for social sign in
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// Button label for Google sign in
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Placeholder hint for email field
  ///
  /// In en, this message translates to:
  /// **'name@email.com'**
  String get emailHint;

  /// Validation error message for missing email
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// Validation error message for invalid email format
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// Validation error message for missing password
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// Error message for invalid login credentials
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get invalidCredentials;

  /// Generic sign in failure message
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailed;

  /// Error message for Google sign in failure
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get googleSignInFailed;

  /// Success message for Google sign in
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google!'**
  String get signedInWithGoogle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'pa', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'pa':
      return AppLocalizationsPa();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

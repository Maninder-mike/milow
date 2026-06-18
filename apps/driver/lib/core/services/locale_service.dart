import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_language';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  static final LocaleService _instance = LocaleService._internal();

  factory LocaleService() => _instance;

  LocaleService._internal();

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('pa'), // Punjabi
    Locale('hi'), // Hindi
    Locale('ur'), // Urdu
  ];

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeKey) ?? 'en';
    _locale = Locale(languageCode);
    Intl.defaultLocale = languageCode;
    await initializeDateFormatting(languageCode, null);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;

    _locale = locale;
    Intl.defaultLocale = locale.languageCode;
    await initializeDateFormatting(locale.languageCode, null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> setLocaleByCode(String languageCode) async {
    await setLocale(Locale(languageCode));
  }
}

final localeService = LocaleService();

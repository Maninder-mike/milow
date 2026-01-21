/// Utility class for handling units and currency based on user's country
class UnitUtils {
  /// Get default distance unit based on country
  static String getDistanceUnit(String? country) {
    final countryLower = country?.toLowerCase().trim() ?? '';
    if (countryLower == 'usa' ||
        countryLower == 'us' ||
        countryLower == 'united states') {
      return 'mi';
    }
    return 'km'; // Default for Canada and others
  }

  /// Get default fuel unit based on country
  static String getFuelUnit(String? country) {
    final countryLower = country?.toLowerCase().trim() ?? '';
    if (countryLower == 'usa' ||
        countryLower == 'us' ||
        countryLower == 'united states') {
      return 'gal';
    }
    return 'L'; // Default for Canada and others
  }

  /// Get default volume unit based on country (Alias for getFuelUnit)
  static String getVolumeUnit(String? country) {
    return getFuelUnit(country);
  }

  /// Get default weight unit based on country
  static String getWeightUnit(String? country) {
    final countryLower = country?.toLowerCase().trim() ?? '';
    if (countryLower == 'usa' || countryLower == 'us') {
      return 'lb';
    }
    return 'kg'; // Default for Canada and others
  }

  /// Get currency code based on country
  static String getCurrency(String? country) {
    final countryLower = country?.toLowerCase().trim() ?? '';
    if (countryLower == 'canada' || countryLower == 'ca') {
      return 'CAD';
    }
    if (countryLower == 'united kingdom' ||
        countryLower == 'uk' ||
        countryLower == 'gb') {
      return 'GBP';
    }
    if (countryLower == 'germany' || countryLower == 'de') {
      return 'EUR';
    }
    return 'USD'; // Default for USA and others
  }

  /// Get currency symbol
  static String getCurrencySymbol(String currency) {
    switch (currency) {
      case 'CAD':
        return 'C\$';
      case 'USD':
      default:
        return '\$';
    }
  }

  /// Get distance unit label
  static String getDistanceUnitLabel(String unit) {
    return unit == 'km' ? 'km' : 'mi';
  }

  /// Get fuel unit label
  static String getFuelUnitLabel(String unit) {
    return unit == 'L' ? 'L' : 'gal';
  }

  /// Get weight unit label
  static String getWeightUnitLabel(String unit) {
    return unit == 'kg' ? 'kg' : 'lb';
  }

  /// Format currency with symbol
  static String formatCurrency(double amount, String currency) {
    final symbol = getCurrencySymbol(currency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Format price per unit (e.g., "$3.459/gal" or "C$1.234/L")
  static String formatPricePerUnit(
    double price,
    String currency,
    String fuelUnit,
  ) {
    final symbol = getCurrencySymbol(currency);
    final unitLabel = getFuelUnitLabel(fuelUnit);
    return '$symbol${price.toStringAsFixed(3)}/$unitLabel';
  }

  /// Format distance (e.g., "1234 mi" or "1234 km")
  static String formatDistance(double distance, String unit) {
    final unitLabel = getDistanceUnitLabel(unit);
    return '${distance.toStringAsFixed(0)} $unitLabel';
  }

  /// Format fuel quantity (e.g., "50.5 gal" or "50.5 L")
  static String formatFuelQuantity(double quantity, String unit) {
    final unitLabel = getFuelUnitLabel(unit);
    return '${quantity.toStringAsFixed(1)} $unitLabel';
  }

  /// Get all defaults based on country
  static Map<String, String> getDefaults(String? country) {
    return {
      'distanceUnit': getDistanceUnit(country),
      'fuelUnit': getFuelUnit(country),
      'weightUnit': getWeightUnit(country),
      'currency': getCurrency(country),
    };
  }

  /// Check if using metric system
  static bool isMetric(String? country) {
    return !isImperial(country);
  }

  /// Check if using imperial system
  static bool isImperial(String? country) {
    final countryLower = country?.toLowerCase().trim() ?? '';
    return countryLower == 'usa' ||
        countryLower == 'us' ||
        countryLower == 'united states';
  }

  // ================= CONVERSION METHODS =================

  static const double _kmToMilesFactor = 0.621371;
  static const double _litersToGallonsFactor = 0.264172; // US Gallons
  static const double _kgToLbsFactor = 2.20462;

  /// Convert Kilometers to Miles
  static double kmToMiles(double km) => km * _kmToMilesFactor;

  /// Convert Miles to Kilometers
  static double milesToKm(double miles) => miles / _kmToMilesFactor;

  /// Convert Liters to US Gallons
  static double litersToGallons(double liters) =>
      liters * _litersToGallonsFactor;

  /// Convert US Gallons to Liters
  static double gallonsToLiters(double gallons) =>
      gallons / _litersToGallonsFactor;

  /// Convert Kilograms to Pounds
  static double kgToLbs(double kg) => kg * _kgToLbsFactor;

  /// Convert Pounds to Kilograms
  static double lbsToKg(double lbs) => lbs / _kgToLbsFactor;
}

class CountryCode {
  final String name;
  final String code; // ISO 3166-1 alpha-2
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  String get displayName => '$flag $name $dialCode';
  String get displayShort => '$flag $dialCode';
}

// Most commonly used countries for trucking industry
const List<CountryCode> countryCodes = [
  // North America
  CountryCode(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
  CountryCode(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
  CountryCode(name: 'Mexico', code: 'MX', dialCode: '+52', flag: '🇲🇽'),

  // Europe
  CountryCode(
    name: 'United Kingdom',
    code: 'GB',
    dialCode: '+44',
    flag: '🇬🇧',
  ),
  CountryCode(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
  CountryCode(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
  CountryCode(name: 'Spain', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
  CountryCode(name: 'Italy', code: 'IT', dialCode: '+39', flag: '🇮🇹'),
  CountryCode(name: 'Poland', code: 'PL', dialCode: '+48', flag: '🇵🇱'),
  CountryCode(name: 'Netherlands', code: 'NL', dialCode: '+31', flag: '🇳🇱'),
  CountryCode(name: 'Belgium', code: 'BE', dialCode: '+32', flag: '🇧🇪'),
  CountryCode(name: 'Austria', code: 'AT', dialCode: '+43', flag: '🇦🇹'),
  CountryCode(name: 'Switzerland', code: 'CH', dialCode: '+41', flag: '🇨🇭'),
  CountryCode(name: 'Sweden', code: 'SE', dialCode: '+46', flag: '🇸🇪'),
  CountryCode(name: 'Norway', code: 'NO', dialCode: '+47', flag: '🇳🇴'),
  CountryCode(name: 'Denmark', code: 'DK', dialCode: '+45', flag: '🇩🇰'),
  CountryCode(name: 'Finland', code: 'FI', dialCode: '+358', flag: '🇫🇮'),
  CountryCode(name: 'Ireland', code: 'IE', dialCode: '+353', flag: '🇮🇪'),
  CountryCode(name: 'Portugal', code: 'PT', dialCode: '+351', flag: '🇵🇹'),
  CountryCode(
    name: 'Czech Republic',
    code: 'CZ',
    dialCode: '+420',
    flag: '🇨🇿',
  ),
  CountryCode(name: 'Romania', code: 'RO', dialCode: '+40', flag: '🇷🇴'),
  CountryCode(name: 'Hungary', code: 'HU', dialCode: '+36', flag: '🇭🇺'),
  CountryCode(name: 'Greece', code: 'GR', dialCode: '+30', flag: '🇬🇷'),

  // Asia Pacific
  CountryCode(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
  CountryCode(name: 'China', code: 'CN', dialCode: '+86', flag: '🇨🇳'),
  CountryCode(name: 'Japan', code: 'JP', dialCode: '+81', flag: '🇯🇵'),
  CountryCode(name: 'Australia', code: 'AU', dialCode: '+61', flag: '🇦🇺'),
  CountryCode(name: 'New Zealand', code: 'NZ', dialCode: '+64', flag: '🇳🇿'),
  CountryCode(name: 'South Korea', code: 'KR', dialCode: '+82', flag: '🇰🇷'),
  CountryCode(name: 'Singapore', code: 'SG', dialCode: '+65', flag: '🇸🇬'),
  CountryCode(name: 'Malaysia', code: 'MY', dialCode: '+60', flag: '🇲🇾'),
  CountryCode(name: 'Thailand', code: 'TH', dialCode: '+66', flag: '🇹🇭'),
  CountryCode(name: 'Indonesia', code: 'ID', dialCode: '+62', flag: '🇮🇩'),
  CountryCode(name: 'Philippines', code: 'PH', dialCode: '+63', flag: '🇵🇭'),
  CountryCode(name: 'Vietnam', code: 'VN', dialCode: '+84', flag: '🇻🇳'),
  CountryCode(name: 'Pakistan', code: 'PK', dialCode: '+92', flag: '🇵🇰'),
  CountryCode(name: 'Bangladesh', code: 'BD', dialCode: '+880', flag: '🇧🇩'),
  CountryCode(name: 'Hong Kong', code: 'HK', dialCode: '+852', flag: '🇭🇰'),
  CountryCode(name: 'Taiwan', code: 'TW', dialCode: '+886', flag: '🇹🇼'),

  // Middle East
  CountryCode(
    name: 'United Arab Emirates',
    code: 'AE',
    dialCode: '+971',
    flag: '🇦🇪',
  ),
  CountryCode(name: 'Saudi Arabia', code: 'SA', dialCode: '+966', flag: '🇸🇦'),
  CountryCode(name: 'Israel', code: 'IL', dialCode: '+972', flag: '🇮🇱'),
  CountryCode(name: 'Turkey', code: 'TR', dialCode: '+90', flag: '🇹🇷'),
  CountryCode(name: 'Qatar', code: 'QA', dialCode: '+974', flag: '🇶🇦'),
  CountryCode(name: 'Kuwait', code: 'KW', dialCode: '+965', flag: '🇰🇼'),
  CountryCode(name: 'Oman', code: 'OM', dialCode: '+968', flag: '🇴🇲'),
  CountryCode(name: 'Bahrain', code: 'BH', dialCode: '+973', flag: '🇧🇭'),

  // South America
  CountryCode(name: 'Brazil', code: 'BR', dialCode: '+55', flag: '🇧🇷'),
  CountryCode(name: 'Argentina', code: 'AR', dialCode: '+54', flag: '🇦🇷'),
  CountryCode(name: 'Chile', code: 'CL', dialCode: '+56', flag: '🇨🇱'),
  CountryCode(name: 'Colombia', code: 'CO', dialCode: '+57', flag: '🇨🇴'),
  CountryCode(name: 'Peru', code: 'PE', dialCode: '+51', flag: '🇵🇪'),
  CountryCode(name: 'Venezuela', code: 'VE', dialCode: '+58', flag: '🇻🇪'),

  // Africa
  CountryCode(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
  CountryCode(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬'),
  CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
  CountryCode(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
  CountryCode(name: 'Morocco', code: 'MA', dialCode: '+212', flag: '🇲🇦'),

  // Other
  CountryCode(name: 'Russia', code: 'RU', dialCode: '+7', flag: '🇷🇺'),
  CountryCode(name: 'Ukraine', code: 'UA', dialCode: '+380', flag: '🇺🇦'),
];

CountryCode? findCountryByDialCode(String dialCode) {
  try {
    return countryCodes.firstWhere(
      (c) => c.dialCode == dialCode,
      orElse: () => countryCodes[0], // Default to US
    );
  } catch (_) {
    return countryCodes[0]; // Default to US
  }
}

CountryCode? parsePhoneNumber(String phone) {
  if (phone.isEmpty || !phone.startsWith('+')) return null;

  // Try to match dial codes from longest to shortest
  final sortedCodes = List<CountryCode>.from(countryCodes)
    ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

  for (final country in sortedCodes) {
    if (phone.startsWith(country.dialCode)) {
      return country;
    }
  }

  return null;
}

String? extractPhoneNumber(String fullPhone, CountryCode country) {
  if (fullPhone.startsWith(country.dialCode)) {
    return fullPhone.substring(country.dialCode.length).trim();
  }
  return fullPhone;
}

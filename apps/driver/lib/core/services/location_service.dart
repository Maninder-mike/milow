import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/services/profile_service.dart';

class LocationService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Resolves a location name (e.g. "Yard", "Walmart") to a full address.
  /// Returns null if no match is found.
  static Future<String?> resolveAddress(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    // 1. Check for "Yard"
    if (trimmedName.toLowerCase() == 'yard') {
      return _getCompanyAddress();
    }

    // 2. Check for Customer Name
    return _getCustomerAddress(trimmedName);
  }

  static Future<String?> _getCompanyAddress() async {
    try {
      final profile = await ProfileService.getProfile();
      if (profile == null) return null;

      final companyData = profile['companies'] as Map<String, dynamic>?;
      if (companyData == null) return null;

      return _formatAddress(
        street: companyData['address'],
        city: companyData['city'],
        state: companyData['state'],
        country: companyData['country'],
        zip: companyData['zip_code'],
      );
    } catch (e) {
      return null;
    }
  }

  static Future<String?> _getCustomerAddress(String name) async {
    try {
      final res = await _client
          .from('customers')
          .select()
          .ilike('name', name) // Case-insensitive match
          .maybeSingle();

      if (res == null) return null;

      return _formatAddress(
        street: res['address_line1'],
        city: res['city'],
        state: res['state_province'],
        country: res['country'],
        zip: res['postal_code'],
      );
    } catch (e) {
      return null;
    }
  }

  static String? _formatAddress({
    String? street,
    String? city,
    String? state,
    String? country,
    String? zip,
  }) {
    final parts = [
      street,
      city,
      state,
      zip,
      country,
    ].where((part) => part != null && part.isNotEmpty).toList();

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

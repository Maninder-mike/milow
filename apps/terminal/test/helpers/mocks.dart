import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:terminal/features/dashboard/services/admin_dashboard_service.dart';
import 'package:terminal/features/auth/services/biometric_service.dart';

// Run 'dart run build_runner build' to generate the mocks
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  Session,
  User,
  SupabaseQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
  BiometricService,
  AdminDashboardService,
])
void main() {}

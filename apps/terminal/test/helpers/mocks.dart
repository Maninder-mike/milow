import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:terminal/features/auth/services/biometric_service.dart';
import 'package:terminal/features/auth/data/auth_repository.dart';
import 'package:terminal/features/dispatch/data/repositories/load_repository.dart';

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
  SupabaseStorageClient,
  StorageFileApi,
  AuthRepository,
  LoadRepository,
])
void main() {}

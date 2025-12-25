import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terminal/features/auth/services/biometric_service.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

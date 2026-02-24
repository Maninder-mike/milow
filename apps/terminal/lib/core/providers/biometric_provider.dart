import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:terminal/features/auth/services/biometric_service.dart';

part 'biometric_provider.g.dart';

@Riverpod(keepAlive: true)
BiometricService biometricService(Ref ref) {
  return BiometricService();
}

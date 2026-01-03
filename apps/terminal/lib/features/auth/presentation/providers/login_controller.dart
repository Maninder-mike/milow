import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/core/providers/biometric_provider.dart';
import 'package:terminal/core/providers/supabase_provider.dart';

part 'login_controller.g.dart';

@riverpod
class LoginController extends _$LoginController {
  @override
  FutureOr<void> build() {
    // Initial state is idle
  }

  Future<void> loginWithPassword(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supabaseClientProvider);
      final biometricService = ref.read(biometricServiceProvider);

      await supabase.auth.signInWithPassword(email: email, password: password);

      // Save credentials on successful login
      await biometricService.saveCredentials(email, password);
    });
  }

  Future<void> loginWithBiometrics() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final biometricService = ref.read(biometricServiceProvider);
      final supabase = ref.read(supabaseClientProvider);

      final authenticated = await biometricService.authenticate();
      if (!authenticated) {
        throw const AuthException('Biometric authentication failed');
      }

      final credentials = await biometricService.getCredentials();
      if (credentials == null) {
        throw const AuthException(
          'No saved credentials found. Please login with password first.',
        );
      }

      await supabase.auth.signInWithPassword(
        email: credentials['email']!,
        password: credentials['password']!,
      );
    });
  }

  Future<void> loginWithPin(String pin) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final biometricService = ref.read(biometricServiceProvider);
      final supabase = ref.read(supabaseClientProvider);

      final isValid = await biometricService.verifyPin(pin);
      if (!isValid) {
        throw const AuthException('Invalid PIN');
      }

      final credentials = await biometricService.getCredentials();
      if (credentials == null) {
        throw const AuthException('No saved credentials found.');
      }

      await supabase.auth.signInWithPassword(
        email: credentials['email']!,
        password: credentials['password']!,
      );
    });
  }

  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (email.isEmpty) {
        throw const AuthException('Please enter your email address');
      }

      await ref
          .read(supabaseClientProvider)
          .auth
          .resetPasswordForEmail(
            email,
            redirectTo: 'milow-terminal://reset-password',
          );
    });
  }
}

import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/providers/network_provider.dart';

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  // We use the raw Supabase client for auth because CoreNetworkClient
  // wraps database queries mostly. But we can access the client via it.
  // Actually, providing CoreNetworkClient is consistent.
  return AuthRepository(ref.watch(coreNetworkClientProvider));
}

@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

class AuthRepository {
  final CoreNetworkClient _client;

  AuthRepository(this._client);

  Stream<AuthState> authStateChanges() =>
      _client.supabase.auth.onAuthStateChange;

  User? get currentUser => _client.supabase.auth.currentUser;

  Future<Result<void>> signInWithPassword(String email, String password) async {
    try {
      await _client.supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return const Right(null);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return Left(UnauthorizedFailure('Invalid email or password'));
      }
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('SignIn failed', originalError: e));
    }
  }

  Future<Result<void>> signUp(
    String email,
    String password,
    Map<String, dynamic> data,
  ) async {
    try {
      await _client.supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'milow-admin://login',
        data: data,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('SignUp failed', originalError: e));
    }
  }

  Future<Result<void>> signOut() async {
    try {
      await _client.supabase.auth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(UnexpectedFailure('SignOut failed', originalError: e));
    }
  }
}

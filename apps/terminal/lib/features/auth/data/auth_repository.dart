import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fpdart/fpdart.dart';

import 'package:terminal/features/auth/domain/failures/auth_failure.dart';

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(Supabase.instance.client.auth);
}

@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

class AuthRepository {
  final GoTrueClient _auth;

  AuthRepository(this._auth);

  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;

  Future<Either<AuthFailure, void>> signInWithPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return const Right(null);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return const Left(InvalidCredentialsFailure());
      }
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  Future<void> signUp(
    String email,
    String password,
    Map<String, dynamic> data,
  ) async {
    await _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'milow-admin://login',
      data: data,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

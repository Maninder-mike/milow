import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> signInWithPassword(String email, String password) async {
    await _auth.signInWithPassword(email: email, password: password);
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

import 'package:terminal/core/failures/failure.dart';

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('Invalid email or password');
}

class NetworkAuthFailure extends AuthFailure {
  const NetworkAuthFailure() : super('Network error during authentication');
}

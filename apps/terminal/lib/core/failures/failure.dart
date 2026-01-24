abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

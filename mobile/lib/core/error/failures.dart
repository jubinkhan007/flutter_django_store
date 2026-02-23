/// Base class for all failures in the app.
/// Open-Closed: Add new failure types by extending, not modifying.
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

class ValidationFailure extends Failure {
  final Map<String, dynamic>? errors;
  const ValidationFailure(super.message, {this.errors});
}

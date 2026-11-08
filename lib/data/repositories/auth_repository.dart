import '../models/admin_account.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contract for Identity & Access Management. A REST implementation can
/// replace the mock without touching the UI.
abstract interface class AuthRepository {
  /// Returns the authenticated account or throws [AuthException].
  Future<AdminAccount> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

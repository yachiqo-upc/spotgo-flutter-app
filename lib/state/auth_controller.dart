import 'package:flutter/foundation.dart';

import '../data/models/admin_account.dart';
import '../data/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AdminAccount? _account;
  bool _loading = false;
  String? _error;

  AdminAccount? get account => _account;
  bool get isAuthenticated => _account != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final account = await _repository.signIn(
        email: email,
        password: password,
      );
      if (!account.canUseAdminApp) {
        throw const AuthException('Account not authorized for Parking Admin.');
      }
      _account = account;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Unable to reach the sign-in service. Try again.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _account = null;
    _error = null;
    notifyListeners();
  }
}

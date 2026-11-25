import '../models/admin_account.dart';
import '../repositories/auth_repository.dart';
import 'spotgo_api.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this.api);

  final SpotGoApi api;

  @override
  Future<AdminAccount> signIn({
    required String email,
    required String password,
  }) async {
    api.clearSession();
    try {
      final session = await api.object(
        '/authentication/sign-in',
        method: 'POST',
        body: {'email': email.trim(), 'password': password},
        auth: false,
      );
      api.setSession(session);
      try {
        final tenantId = session['tenantId'] as String?;
        if (session['role'] != 'PARKING_ADMIN' || tenantId == null) {
          throw const AuthException(
            'Account not authorized for Parking Admin.',
          );
        }
        final tenant = await api.object('/tenants/$tenantId');
        api.tenant = tenant;
        final address = tenant['address'] as String? ?? '';
        return AdminAccount(
          id: session['accountId'] as String,
          fullName: session['email'] as String,
          email: session['email'] as String,
          role: UserRole.parkingAdmin,
          enabled: true,
          facilityName: tenant['name'] as String,
          district: address.split(',').last.trim(),
        );
      } catch (_) {
        await signOut();
        rethrow;
      }
    } on ApiException catch (error) {
      throw AuthException(
        error.status == 401 ? 'Invalid email or password.' : error.message,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await api.request('/authentication/sign-out', method: 'POST', body: {});
    } catch (_) {
      // Clear local access even when Spring is unreachable.
    } finally {
      api.clearSession();
    }
  }
}

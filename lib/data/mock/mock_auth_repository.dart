import '../models/admin_account.dart';
import '../repositories/auth_repository.dart';

/// Local demo accounts used while the SpotGo backend is not reachable.
/// They are sample data, not real credentials.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 600)});

  final Duration latency;

  static const demoEmail = 'admin@spotgo.pe';
  static const demoPassword = 'SpotGo2026!';

  static const _accounts = <String, AdminAccount>{
    'admin@spotgo.pe': AdminAccount(
      id: 'PA-001',
      fullName: 'Parking Admin Demo',
      email: 'admin@spotgo.pe',
      role: UserRole.parkingAdmin,
      enabled: true,
      facilityName: 'Javier Prado Parking',
      district: 'San Isidro',
    ),
    'suspended.admin@spotgo.pe': AdminAccount(
      id: 'PA-002',
      fullName: 'Suspended Admin Demo',
      email: 'suspended.admin@spotgo.pe',
      role: UserRole.parkingAdmin,
      enabled: false,
      facilityName: 'Javier Prado Parking',
      district: 'San Isidro',
    ),
    'driver@spotgo.pe': AdminAccount(
      id: 'DR-001',
      fullName: 'Driver Demo',
      email: 'driver@spotgo.pe',
      role: UserRole.driver,
      enabled: true,
      facilityName: '-',
      district: '-',
    ),
  };

  @override
  Future<AdminAccount> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || password != demoPassword) {
      throw const AuthException('Invalid email or password.');
    }
    if (account.role != UserRole.parkingAdmin) {
      throw const AuthException(
        'This app only accepts Parking Admin accounts provisioned by SuperAdmin.',
      );
    }
    if (!account.enabled) {
      throw const AuthException(
        'This Parking Admin account is not enabled. Contact your SuperAdmin.',
      );
    }
    return account;
  }

  @override
  Future<void> signOut() async {}
}

enum UserRole { parkingAdmin, superAdmin, driver }

/// Account provisioned by SuperAdmin. Only enabled Parking Admin accounts
/// can use this app.
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.enabled,
    required this.facilityName,
    required this.district,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final bool enabled;
  final String facilityName;
  final String district;

  bool get canUseAdminApp => enabled && role == UserRole.parkingAdmin;
}

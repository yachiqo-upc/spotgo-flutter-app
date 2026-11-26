import '../../domain/parking_rules.dart';

/// Raised before a request leaves the app when it targets an endpoint this
/// role is not allowed to call. It mirrors the backend's 403 so the failure
/// is explicit instead of a silent contract violation.
class RoleGuardException extends ParkingRuleException {
  const RoleGuardException(super.message);
}

/// Single choke point for the DRIVER-only endpoints of the SpotGo contract
/// (§1.1–§1.5). This app only signs in as `PARKING_ADMIN`, so requesting any
/// of them is a bug: the backend would answer 403, and reaching them is how a
/// client ends up reading or mutating another role's data.
///
/// The remote API calls [RoleGuard.ensureCanCall] on every request; the mock
/// repositories mirror the same rules so both data sources behave alike.
abstract final class RoleGuard {
  static const String appRole = 'PARKING_ADMIN';

  static final List<_DriverOnlyEndpoint> _endpoints = [
    // Profiles §1.2 — VEH-01…04: the whole `/vehicles` resource is DRIVER.
    _DriverOnlyEndpoint('VEH-01…04', null, RegExp(r'^/vehicles(/.*)?$')),
    // Favorites §1.3 — FAV-01…03: `/favorites` is DRIVER.
    _DriverOnlyEndpoint('FAV-01…03', null, RegExp(r'^/favorites(/.*)?$')),
    // CLS-03 — a driver's own classifications.
    _DriverOnlyEndpoint(
      'CLS-03',
      const {'GET'},
      RegExp(r'^/driver-classifications/me$'),
    ),
    // RES-05…08 — creating and moving reservations is a driver action;
    // RES-01/02/09/10/11 stay available to this app.
    _DriverOnlyEndpoint(
      'RES-05',
      const {'POST'},
      RegExp(r'^/reservations/[^/]+/receipt/email$'),
    ),
    _DriverOnlyEndpoint('RES-06', const {'POST'}, RegExp(r'^/reservations$')),
    _DriverOnlyEndpoint(
      'RES-07',
      const {'POST'},
      RegExp(r'^/reservations/[^/]+/reschedule$'),
    ),
    _DriverOnlyEndpoint(
      'RES-08',
      const {'POST'},
      RegExp(r'^/reservations/[^/]+/extend$'),
    ),
    // PAY-03/04/06 — only PAY-05 (subscriptions) is a Parking Admin charge.
    _DriverOnlyEndpoint(
      'PAY-03',
      const {'POST'},
      RegExp(r'^/digital-payments/reservations/[^/]+$'),
    ),
    _DriverOnlyEndpoint(
      'PAY-04',
      const {'POST'},
      RegExp(r'^/digital-payments/reservation-changes/[^/]+$'),
    ),
    _DriverOnlyEndpoint(
      'PAY-06',
      const {'POST'},
      RegExp(r'^/digital-payments/additional-charges/[^/]+$'),
    ),
    // AUTH-02/03/04 — this app never registers accounts or links Google.
    _DriverOnlyEndpoint(
      'AUTH-04',
      const {'POST'},
      RegExp(r'^/authentication/sign-up$'),
    ),
    _DriverOnlyEndpoint(
      'AUTH-02',
      const {'POST'},
      RegExp(r'^/authentication/google$'),
    ),
    _DriverOnlyEndpoint(
      'AUTH-03',
      const {'POST'},
      RegExp(r'^/authentication/google/link$'),
    ),
  ];

  /// Throws [RoleGuardException] when `method path` belongs to DRIVER.
  static void ensureCanCall(String method, String path) {
    final endpoint = _match(method, path);
    if (endpoint != null) {
      throw RoleGuardException(
        '${endpoint.id} ($method $path) is reserved for the DRIVER role; '
        'a $appRole account cannot call it (contract §1.5).',
      );
    }
  }

  /// True when `method path` is blocked, ignoring the query string.
  static bool isBlocked(String method, String path) =>
      _match(method, path) != null;

  static _DriverOnlyEndpoint? _match(String method, String path) {
    final cleanPath = path.split('?').first;
    for (final endpoint in _endpoints) {
      if (endpoint.blocks(method, cleanPath)) return endpoint;
    }
    return null;
  }
}

class _DriverOnlyEndpoint {
  const _DriverOnlyEndpoint(this.id, this.methods, this.path);

  /// Contract identifier, used in the error message.
  final String id;

  /// HTTP methods the rule applies to; `null` blocks every method.
  final Set<String>? methods;

  final RegExp path;

  bool blocks(String method, String path) =>
      (methods == null || methods!.contains(method.toUpperCase())) &&
      this.path.hasMatch(path);
}

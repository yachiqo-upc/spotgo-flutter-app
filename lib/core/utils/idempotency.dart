import 'dart:math';

/// Builds the `idempotencyKey` that every billing payment body requires
/// (contract §0.3: the key travels **in the body**, never in a header).
///
/// Generate one key per operation and reuse it while retrying that same
/// operation; a different key makes the backend create a second payment.
abstract final class Idempotency {
  static const _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  static final Random _random = Random();

  /// Unique key, at most 255 characters (`@Size(max = 255)`).
  static String newKey({String prefix = 'spotgo'}) {
    final stamp = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(36);
    final suffix = List<String>.generate(
      10,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
    final key = '$prefix-$stamp-$suffix';
    return key.length <= 255 ? key : key.substring(0, 255);
  }
}

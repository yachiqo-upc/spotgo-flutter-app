/// Small formatting helpers to avoid extra dependencies.
abstract final class Formatters {
  static String time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  static String duration(Duration value) {
    final totalMinutes = value.inMinutes < 0 ? 0 : value.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours h';
    return '$hours h $minutes min';
  }

  static String money(double amount) => 'S/ ${amount.toStringAsFixed(2)}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// `01 Sep 2026` in the device timezone.
  static String date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')} '
        '${_months[local.month - 1]} ${local.year}';
  }

  /// `01 Sep 2026 · 14:05` in the device timezone.
  static String dateTime(DateTime value) {
    final local = value.toLocal();
    return '${date(local)} · ${time(local)}';
  }

  /// Formats integer cents without going through `double` arithmetic.
  static String moneyCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final absolute = cents.abs();
    final whole = absolute ~/ 100;
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${sign}S/ $whole.$fraction';
  }

  static String relative(DateTime value, DateTime now) {
    final diff = now.difference(value);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  static String dayAndTime(DateTime value, DateTime now) {
    final sameDay =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final day = sameDay
        ? 'Today'
        : '${value.day.toString().padLeft(2, '0')}/'
              '${value.month.toString().padLeft(2, '0')}';
    return '$day · ${time(value)}';
  }

  static String percent(double ratio) => '${(ratio * 100).round()}%';
}

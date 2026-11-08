import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum BadgeTone { success, warning, danger, info, neutral }

extension BadgeToneColors on BadgeTone {
  Color get foreground => switch (this) {
    BadgeTone.success => AppColors.success,
    BadgeTone.warning => AppColors.warning,
    BadgeTone.danger => AppColors.danger,
    BadgeTone.info => AppColors.info,
    BadgeTone.neutral => AppColors.textSecondary,
  };

  Color get background => switch (this) {
    BadgeTone.success => AppColors.successMuted,
    BadgeTone.warning => AppColors.warningMuted,
    BadgeTone.danger => AppColors.dangerMuted,
    BadgeTone.info => AppColors.infoMuted,
    BadgeTone.neutral => AppColors.surfaceAlt,
  };
}

/// Pill with a colored dot, as used for severities and session states.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: tone.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: tone.foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

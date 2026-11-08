import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SpotGoLogo extends StatelessWidget {
  const SpotGoLogo({super.key, this.fontSize = 24});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Spot',
            style: style.copyWith(color: AppColors.textPrimary),
          ),
          TextSpan(
            text: 'Go',
            style: style.copyWith(color: AppColors.primary),
          ),
        ],
      ),
      semanticsLabel: 'SpotGo',
    );
  }
}

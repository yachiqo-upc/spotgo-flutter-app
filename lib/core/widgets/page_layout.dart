import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'spotgo_logo.dart';

/// Centers content and limits its width so screens adapt to phones and tablets.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  static const double maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Header used by the main tabs: logo, profile button, title and subtitle.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onProfileTap,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onProfileTap;

  /// Shown for sections opened inside a tab (e.g. More > Parking zones).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            const SpotGoLogo(),
            const Spacer(),
            IconButton(
              tooltip: 'Account',
              onPressed: onProfileTap,
              icon: const Icon(
                Icons.account_circle_outlined,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, style: theme.textTheme.bodySmall),
        const SizedBox(height: 22),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

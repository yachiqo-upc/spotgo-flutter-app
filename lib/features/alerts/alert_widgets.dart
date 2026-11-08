import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/operational_alert.dart';

BadgeTone alertSeverityTone(AlertSeverity severity) => switch (severity) {
  AlertSeverity.high => BadgeTone.danger,
  AlertSeverity.medium => BadgeTone.warning,
  AlertSeverity.info => BadgeTone.info,
};

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.now,
    required this.onTap,
  });

  final OperationalAlert alert;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alert.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: alert.severity.label,
                    tone: alertSeverityTone(alert.severity),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                alert.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      Formatters.relative(alert.detectedAt, now),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (alert.status != AlertStatus.open)
                    StatusBadge(
                      label: alert.status.label,
                      tone: alert.status == AlertStatus.resolved
                          ? BadgeTone.success
                          : BadgeTone.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../dashboard/dashboard_screen.dart';
import '../shell/account_sheet.dart';

/// Operational occupancy trends of the assigned facility (mockup 24).
class OccupancyReportsScreen extends StatefulWidget {
  const OccupancyReportsScreen({super.key});

  @override
  State<OccupancyReportsScreen> createState() =>
      _OccupancyReportsScreenState();
}

class _OccupancyReportsScreenState extends State<OccupancyReportsScreen> {
  _Range _range = _Range.today;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);

    return SingleChildScrollView(
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Occupancy reports',
              subtitle: 'Operational trends for ${admin.facilityName}',
              onProfileTap: () => showAccountSheet(context),
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            ChoiceChipBar<_Range>(
              options: const [
                ChipOption(_Range.today, 'Today'),
                ChipOption(_Range.week, '7 days'),
                ChipOption(_Range.month, '30 days'),
              ],
              selected: _range,
              onSelected: (value) => setState(() => _range = value),
            ),
            const SizedBox(height: 14),
            const MetricGrid(
              children: [
                MetricCard(
                  value: '68%',
                  label: 'Avg. occupancy',
                  valueColor: AppColors.primary,
                ),
                MetricCard(
                  value: '91%',
                  label: 'Peak occupancy',
                  valueColor: AppColors.success,
                ),
                MetricCard(
                  value: '7',
                  label: 'Overstays',
                  valueColor: AppColors.warning,
                ),
                MetricCard(
                  value: '18',
                  label: 'Completed Guest Sessions',
                  valueColor: AppColors.primary,
                ),
                MetricCard(
                  value: '2',
                  label: 'No-shows',
                  valueColor: AppColors.warning,
                ),
                MetricCard(
                  value: '4',
                  label: 'Incidents',
                  valueColor: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _OccupancyByHourCard(),
            const SectionTitle('Zone performance'),
            const SectionCard(
              children: [
                InfoRow(
                  title: 'Occupancy',
                  subtitle: 'Average today',
                  trailing: '68%',
                ),
                InfoRow(
                  title: 'Sensor availability',
                  subtitle: '22 online · 2 offline',
                  trailing: '92%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _Range { today, week, month }

/// Bar chart of occupancy per hour, built with plain widgets (no charts
/// dependency): the 4:00 PM bar is highlighted as the peak.
class _OccupancyByHourCard extends StatelessWidget {
  const _OccupancyByHourCard();

  static const _hours = ['8', '10', '12', '14', '16', '18', '20'];
  static const _values = [0.45, 0.58, 0.73, 0.87, 1.0, 0.79, 0.58];
  static const _peakIndex = 4;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Occupancy by hour',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Text(
                  'Peak 91% · 4:00 PM',
                  style: TextStyle(color: AppColors.success, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _hours.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _Bar(hour: _hours[i], value: _values[i], peak: i == _peakIndex)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.hour, required this.value, required this.peak});

  final String hour;
  final double value;
  final bool peak;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 96 * value,
          decoration: BoxDecoration(
            color: peak ? AppColors.success : AppColors.primary,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hour,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

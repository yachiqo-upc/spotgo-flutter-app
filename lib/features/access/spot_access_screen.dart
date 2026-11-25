import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import 'access_rules_sheet.dart';

/// Spot groups, permitted drivers and rules of the assigned zone
/// (mockup 31).
class SpotAccessScreen extends StatefulWidget {
  const SpotAccessScreen({super.key});

  @override
  State<SpotAccessScreen> createState() => _SpotAccessScreenState();
}

class _SpotAccessScreenState extends State<SpotAccessScreen> {
  _AccessTab _tab = _AccessTab.spots;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spot access & permissions')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceChipBar<_AccessTab>(
                  options: const [
                    ChipOption(_AccessTab.spots, 'Spots'),
                    ChipOption(_AccessTab.drivers, 'Drivers'),
                    ChipOption(_AccessTab.rules, 'Rules'),
                  ],
                  selected: _tab,
                  onSelected: (value) => setState(() => _tab = value),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        value: '24/24',
                        label: 'spots configured',
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        value: '118',
                        label: 'drivers permitted',
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        value: '0',
                        label: 'conflicts',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SectionTitle('Parking spot groups'),
                const SectionCard(
                  children: [
                    InfoRow(
                      title: 'Standard spots',
                      subtitle: 'A-01 to A-16 · Configured in this zone',
                      trailing: '16',
                    ),
                    InfoRow(
                      title: 'Accessible spots',
                      subtitle: 'C-01 to C-02 · Configured in this zone',
                      trailing: '2',
                    ),
                    InfoRow(
                      title: 'EV spots',
                      subtitle: 'E-01 to E-02 · Configured in this zone',
                      trailing: '2',
                    ),
                  ],
                ),
                const SectionTitle('Access profiles'),
                const SectionCard(
                  children: [
                    InfoRow(
                      title: 'Driver',
                      subtitle: 'Permitted Driver profiles',
                      trailing: '118',
                    ),
                    InfoRow(
                      title: 'Administrator',
                      subtitle: 'Assigned to this zone',
                      trailing: '1',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                NoticeCard(
                  message:
                      'This Administrator is assigned to '
                      '${AdminScope.of(context).facilityName}. Spot settings '
                      'apply only to this zone.',
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('access-rules'),
                  onPressed: () => showAccessRulesSheet(context),
                  child: const Text('Access rules'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Spot settings saved')),
                  ),
                  child: const Text('Save spot settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AccessTab { spots, drivers, rules }

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

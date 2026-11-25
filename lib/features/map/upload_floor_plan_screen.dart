import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';

/// Uploads a PNG/JPG floor plan for a zone and level (mockup 18).
class UploadFloorPlanScreen extends StatefulWidget {
  const UploadFloorPlanScreen({super.key});

  @override
  State<UploadFloorPlanScreen> createState() => _UploadFloorPlanScreenState();
}

class _UploadFloorPlanScreenState extends State<UploadFloorPlanScreen> {
  bool _hasFile = true;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload floor plan')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add or replace a floor plan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload a PNG/JPG for the Administrator to configure the '
                  'parking map.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                const InputDecorator(
                  decoration: InputDecoration(labelText: 'Assigned parking zone'),
                  child: Text(
                    'Javier Prado Parking',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const InputDecorator(
                  decoration: InputDecoration(labelText: 'Floor / level'),
                  child: Text(
                    'Level 1',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Dropzone(
                  onChoose: () => setState(() => _hasFile = true),
                ),
                if (_hasFile) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'JP-L1-floor-plan.png',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '3.4 MB',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const NoticeCard(
                  title: 'Before uploading',
                  message:
                      'Use a clear top-down floor plan. Invalid file types, '
                      'oversized images or unreadable files must be rejected '
                      'before upload.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Floor plan uploaded for ${admin.facilityName}',
                      ),
                    ),
                  ),
                  child: const Text('Upload floor plan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dropzone extends StatelessWidget {
  const _Dropzone({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Floor plan file',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'PNG or JPG · Maximum 10 MB',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onChoose,
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
  }
}

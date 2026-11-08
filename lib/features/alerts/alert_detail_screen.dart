import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/operational_alert.dart';
import '../../domain/parking_rules.dart';
import '../../state/admin_controller.dart';
import 'alert_widgets.dart';

class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actionController = TextEditingController();
  String? _classification;
  String? _error;
  bool _actionCompleted = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final alert = AdminScope.of(context).alertById(widget.alertId);
    if (alert == null) return;
    _classification = alert.classification;
    _actionController.text = alert.actionTaken ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _changeClassification(OperationalAlert alert) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Incident classification',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final option in alert.type.classifications)
                ListTile(
                  title: Text(option),
                  selected: option == _classification,
                  selectedColor: AppColors.primary,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || selected == null) return;
    setState(() {
      _classification = selected;
      _error = null;
    });
  }

  Future<void> _submit(AdminController admin, OperationalAlert alert) async {
    if (_saving || !alert.isPending) return;
    if (!_formKey.currentState!.validate()) return;
    if (_classification == null || _classification!.isEmpty) {
      setState(() => _error = 'Select the incident classification');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await admin.updateAlert(
        alert.id,
        classification: _classification!,
        action: _actionController.text.trim(),
        actionCompleted: _actionCompleted,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _actionCompleted
                ? 'Alert resolved. History updated.'
                : 'Alert saved as monitoring.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ParkingRuleException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update this alert. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final alert = admin.alertById(widget.alertId);
    return Scaffold(
      appBar: AppBar(title: const Text('Alert detail')),
      body: alert == null
          ? const Center(
              child: EmptyView(
                title: 'Alert not found',
                message: 'It may have been removed during a refresh.',
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: PageContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _severityHeader(context, alert),
                      const SizedBox(height: 14),
                      _details(admin, alert),
                      const SizedBox(height: 14),
                      if (alert.isPending) ...[
                        _classificationCard(alert),
                        const SectionTitle('Resolution'),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            key: const Key('alert-action'),
                            controller: _actionController,
                            decoration: const InputDecoration(
                              labelText: 'Action taken',
                              hintText: 'Describe what you did',
                            ),
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) =>
                                (value ?? '').trim().length <
                                    ParkingRules.minActionLength
                                ? 'Describe the action taken (at least 5 characters)'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SelectableChip(
                              label: 'Monitoring',
                              selected: !_actionCompleted,
                              enabled: !_saving,
                              onTap: () =>
                                  setState(() => _actionCompleted = false),
                            ),
                            SelectableChip(
                              label: 'Resolved',
                              selected: _actionCompleted,
                              enabled: !_saving,
                              onTap: () =>
                                  setState(() => _actionCompleted = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const NoticeCard(
                          message:
                              'Resolve this alert only after the required '
                              'action is completed. Monitoring keeps it pending.',
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          key: const Key('alert-submit'),
                          onPressed: _saving
                              ? null
                              : () => _submit(admin, alert),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : Text(
                                  _actionCompleted
                                      ? 'Mark alert as resolved'
                                      : 'Save as monitoring',
                                ),
                        ),
                      ] else ...[
                        const SectionTitle('Resolution'),
                        SectionCard(
                          children: [
                            InfoRow(
                              title: 'Classification',
                              subtitle: alert.classification ?? '—',
                            ),
                            InfoRow(
                              title: 'Action taken',
                              subtitle: alert.actionTaken ?? '—',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const NoticeCard(
                          message: 'This alert is resolved and read only.',
                        ),
                      ],
                      const SectionTitle('History'),
                      SectionCard(
                        children: [
                          for (final event in alert.history)
                            InfoRow(
                              title: event.description,
                              subtitle:
                                  '${event.actor} · '
                                  '${Formatters.dayAndTime(event.at, admin.now)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _severityHeader(BuildContext context, OperationalAlert alert) {
    final tone = alertSeverityTone(alert.severity);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              alert.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: alert.severity.label, tone: tone),
        ],
      ),
    );
  }

  Widget _details(AdminController admin, OperationalAlert alert) {
    final zone = admin.zoneById(alert.zoneId);
    final zoneName = zone == null
        ? admin.facilityName
        : '${zone.name} · ${zone.district}';
    return SectionCard(
      children: [
        InfoRow(title: 'Assigned parking zone', subtitle: zoneName),
        InfoRow(
          title: 'Affected item',
          subtitle: alert.spotCode == null
              ? 'Facility-wide alert'
              : 'Spot ${alert.spotCode}',
        ),
        InfoRow(title: 'Source', subtitle: alert.source),
        InfoRow(
          title: 'Detected',
          subtitle: Formatters.dayAndTime(alert.detectedAt, admin.now),
          trailing: Formatters.relative(alert.detectedAt, admin.now),
        ),
      ],
    );
  }

  Widget _classificationCard(OperationalAlert alert) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _classification ?? 'No classification selected',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          TextButton(
            key: const Key('alert-change-classification'),
            onPressed: _saving ? null : () => _changeClassification(alert),
            child: const Text('Change classification'),
          ),
        ],
      ),
    );
  }
}

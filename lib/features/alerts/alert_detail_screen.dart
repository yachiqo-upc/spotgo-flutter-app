import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/evidence_image.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/operational_alert.dart';
import '../../data/models/monitoring.dart' show ResolutionClassification;
import '../../data/repositories/monitoring_repository.dart';
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
  ResolutionClassification? _classification;
  String? _error;
  String? _evidenceError;
  Uint8List? _evidenceBytes;
  bool _saving = false;
  bool _retryable = false;
  bool _acknowledgingCapacity = false;
  bool _uploadingEvidence = false;
  bool _loadingEvidence = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final alert = AdminScope.of(context).alertById(widget.alertId);
    if (alert == null) return;
    _classification = switch (alert.alertType) {
      MonitoringAlertKind.sensorFailure =>
        ResolutionClassification.sensorRecovered,
      MonitoringAlertKind.occupancyConflict =>
        ResolutionClassification.unauthorizedOccupancy,
      MonitoringAlertKind.unknown => ResolutionClassification.other,
    };
    _actionController.text = alert.actionTaken ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _changeClassification(OperationalAlert alert) async {
    final selected = await showModalBottomSheet<ResolutionClassification>(
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
              for (final option in ResolutionClassification.values.where(
                (value) => value != ResolutionClassification.unknown,
              ))
                ListTile(
                  title: Text(_classificationLabel(option)),
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
      _retryable = false;
    });
  }

  Future<void> _submit(AdminController admin, OperationalAlert alert) async {
    if (_saving || !alert.isPending) return;
    if (!_formKey.currentState!.validate()) return;
    if (_classification == null ||
        _classification == ResolutionClassification.unknown) {
      setState(() => _error = 'Select the incident classification');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await admin.closeAlert(
        alert,
        classification: _classification!,
        action: _actionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Alert closed. History updated.')),
      );
      Navigator.of(context).pop();
    } on ParkingRuleException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
        _retryable = error.status == 409;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update this alert. Please try again.';
        _retryable = false;
      });
    }
  }

  Future<void> _acknowledgeCapacity(
    AdminController admin,
    OperationalAlert alert,
  ) async {
    if (_acknowledgingCapacity) return;
    setState(() {
      _acknowledgingCapacity = true;
      _error = null;
    });
    try {
      await AppScope.of(context).monitoring.acknowledgeCapacityAlert(alert.id);
      await admin.refresh();
      if (mounted) Navigator.of(context).pop();
    } on MonitoringException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _acknowledgingCapacity = false);
    }
  }

  Future<void> _uploadEvidence(AdminController admin) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final contentType = file.mimeType ?? _detectImageContentType(bytes);
      final validationError = validateEvidenceImage(bytes, contentType);
      if (validationError != null) {
        setState(() => _evidenceError = validationError);
        return;
      }

      setState(() {
        _uploadingEvidence = true;
        _evidenceError = null;
      });
      await admin.uploadAlertEvidence(
        alertId: widget.alertId,
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() => _evidenceBytes = Uint8List.fromList(bytes));
    } on ParkingRuleException catch (error) {
      if (!mounted) return;
      setState(() {
        _evidenceError = error.status == null
            ? error.message
            : '${error.message} (HTTP ${error.status})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _evidenceError = 'Could not choose or upload an image.');
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<void> _loadEvidence(AdminController admin) async {
    setState(() {
      _loadingEvidence = true;
      _evidenceError = null;
    });
    try {
      final bytes = await admin.alertEvidence(widget.alertId);
      if (mounted) setState(() => _evidenceBytes = Uint8List.fromList(bytes));
    } on ParkingRuleException catch (error) {
      if (!mounted) return;
      setState(() {
        _evidenceError = error.status == 404
            ? 'No evidence is attached to this alert.'
            : error.status == null
            ? error.message
            : '${error.message} (HTTP ${error.status})';
      });
    } catch (_) {
      if (mounted) setState(() => _evidenceError = 'Could not load evidence.');
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  static String _classificationLabel(
    ResolutionClassification value,
  ) => switch (value) {
    ResolutionClassification.unauthorizedOccupancy => 'Unauthorized occupancy',
    ResolutionClassification.reservationReassigned => 'Reservation reassigned',
    ResolutionClassification.sensorRecovered => 'Sensor recovered',
    ResolutionClassification.falsePositive => 'False positive',
    ResolutionClassification.other => 'Other',
    ResolutionClassification.unknown => 'Unknown',
  };

  static String _detectImageContentType(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    return '';
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
                      if (alert.isPending &&
                          alert.type != AlertType.highOccupancy) ...[
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
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) {
                              final action = (value ?? '').trim();
                              if (action.isEmpty) {
                                return 'Describe the action taken';
                              }
                              if (action.length > 1000) {
                                return 'Use at most 1000 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        const NoticeCard(
                          message:
                              'Closing a conflict alert also resolves its '
                              'conflict. Closing a sensor alert recovers its '
                              'health event first.',
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
                              : Text(_retryable ? 'Reintentar' : 'Close alert'),
                        ),
                      ] else if (alert.type == AlertType.highOccupancy) ...[
                        const NoticeCard(
                          message:
                              'Capacity alerts can only be acknowledged. '
                              'They resolve automatically after occupancy '
                              'falls below the threshold.',
                        ),
                        if (alert.status == AlertStatus.open) ...[
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _acknowledgingCapacity
                                ? null
                                : () => _acknowledgeCapacity(admin, alert),
                            child: _acknowledgingCapacity
                                ? const CircularProgressIndicator()
                                : const Text('Acknowledge capacity alert'),
                          ),
                        ],
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
                      if (alert.type != AlertType.highOccupancy) ...[
                        const SectionTitle('Evidence'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('alert-upload-evidence'),
                              onPressed: _uploadingEvidence
                                  ? null
                                  : () => _uploadEvidence(admin),
                              icon: _uploadingEvidence
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                              label: const Text('Choose image'),
                            ),
                            OutlinedButton.icon(
                              key: const Key('alert-view-evidence'),
                              onPressed: _loadingEvidence
                                  ? null
                                  : () => _loadEvidence(admin),
                              icon: _loadingEvidence
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.image_outlined),
                              label: const Text('View evidence'),
                            ),
                          ],
                        ),
                        if (_evidenceError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _evidenceError!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                        if (_evidenceBytes != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _evidenceBytes!,
                              key: const Key('alert-evidence-image'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
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
            _classification == null
                ? 'No classification selected'
                : _classificationLabel(_classification!),
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

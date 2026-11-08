import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../data/models/guest_session.dart';
import '../../data/models/parking_spot.dart';
import '../../data/repositories/parking_repository.dart';
import '../../domain/parking_rules.dart';

/// Registers a guest session for an external vehicle (mockup 22, US03
/// scenarios 1, 2 and 4). No Driver account or reservation is created.
class NewGuestSessionScreen extends StatefulWidget {
  const NewGuestSessionScreen({super.key, this.initialSpotId});

  final String? initialSpotId;

  @override
  State<NewGuestSessionScreen> createState() => _NewGuestSessionScreenState();
}

class _NewGuestSessionScreenState extends State<NewGuestSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  VehicleType _vehicleType = VehicleType.car;
  String? _spotId;
  Duration _duration = const Duration(hours: 2);
  bool _saving = false;
  String? _error;

  static const _durations = [
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 4),
    Duration(hours: 6),
    Duration(hours: 8),
  ];

  @override
  void initState() {
    super.initState();
    _spotId = widget.initialSpotId;
  }

  @override
  void dispose() {
    _plate.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final session = await AdminScope.of(context).startGuestSession(
        GuestSessionDraft(
          plate: _plate.text,
          vehicleType: _vehicleType,
          color: _color.text,
          spotId: _spotId!,
          expectedDuration: _duration,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Guest session ${session.id} started for ${session.plate} '
            'at ${session.spotCode}',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ParkingRuleException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The session could not be started. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final assignable = admin.spots
        .where((s) => admin.zoneById(s.zoneId)?.isActive ?? false)
        .toList();
    final availableCount = assignable
        .where((s) => s.canStartGuestSession)
        .length;
    final selectedSpot = _spotId == null ? null : admin.spotById(_spotId!);

    return Scaffold(
      appBar: AppBar(title: const Text('New guest session')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Register external vehicle',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${admin.facilityName} · create a manual assignment '
                    'before the vehicle enters.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('guest-plate'),
                    controller: _plate,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'License plate',
                      hintText: 'B7N-216',
                      counterText: '',
                    ),
                    validator: ParkingRules.validatePlate,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<VehicleType>(
                          key: const Key('guest-vehicle-type'),
                          initialValue: _vehicleType,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle type',
                          ),
                          items: [
                            for (final type in VehicleType.values)
                              DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _vehicleType = value ?? _vehicleType,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: const Key('guest-color'),
                          controller: _color,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Color',
                            hintText: 'Optional',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: const Key('guest-spot'),
                    initialValue: _spotId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Parking spot',
                    ),
                    hint: const Text('Select an available spot'),
                    items: [
                      for (final spot in assignable)
                        DropdownMenuItem(
                          value: spot.id,
                          enabled: spot.canStartGuestSession,
                          child: Text(
                            '${spot.code} · ${spot.type.label} · '
                            '${spot.availability.label}',
                            style: TextStyle(
                              color: spot.canStartGuestSession
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _spotId = value),
                    validator: (value) {
                      if (value == null) return 'Select a parking spot';
                      final spot = admin.spotById(value);
                      if (spot == null ||
                          spot.availability != SpotAvailability.available) {
                        return 'Select an Available spot';
                      }
                      return null;
                    },
                  ),
                  if (selectedSpot != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${admin.zoneById(selectedSpot.zoneId)?.name ?? ''} · '
                      'sensor ${selectedSpot.sensorHealth.label.toLowerCase()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start time',
                          ),
                          child: Text('Now · ${Formatters.time(admin.now)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<Duration>(
                          key: const Key('guest-duration'),
                          initialValue: _duration,
                          decoration: const InputDecoration(
                            labelText: 'Expected duration',
                          ),
                          items: [
                            for (final d in _durations)
                              DropdownMenuItem(
                                value: d,
                                child: Text(Formatters.duration(d)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _duration = value ?? _duration),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NoticeCard(
                    title: 'Assignment rules',
                    message:
                        'Only Available spots can start a session '
                        '($availableCount now). Reserved, Occupied and '
                        'Unavailable spots are blocked. No Driver account, '
                        'reservation or digital payment is created; payment '
                        'is collected at the exit.',
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      key: const Key('guest-error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    key: const Key('guest-start'),
                    onPressed: _saving || availableCount == 0 ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text('Start guest session'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

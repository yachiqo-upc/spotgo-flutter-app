import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/parking_spot.dart';
import '../../data/models/parking_zone.dart';
import '../../domain/parking_rules.dart';
import 'parking_zones_screen.dart';

/// Create or edit a parking zone (mockup 20, US02 scenarios 1-3).
class ZoneFormScreen extends StatefulWidget {
  const ZoneFormScreen({super.key, this.zoneId});

  final String? zoneId;

  @override
  State<ZoneFormScreen> createState() => _ZoneFormScreenState();
}

class _ZoneFormScreenState extends State<ZoneFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _district = TextEditingController();
  final _rate = TextEditingController();
  final _fraction = TextEditingController();

  ParkingZone? _original;
  int? _opensAt;
  int? _closesAt;
  ZoneStatus _status = ZoneStatus.active;
  final Set<SpotType> _types = {};
  final Set<AccessProfile> _profiles = {};
  final List<String> _spotIds = [];
  bool _initialized = false;
  bool _saving = false;
  bool _missingZone = false;
  String? _error;

  bool get _isEdit => widget.zoneId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final admin = AdminScope.of(context);
    if (_isEdit) {
      final zone = admin.zoneById(widget.zoneId!);
      if (zone == null) {
        _missingZone = true;
        return;
      }
      _original = zone;
      _name.text = zone.name;
      _address.text = zone.address;
      _district.text = zone.district;
      _rate.text = zone.ratePerHour.toStringAsFixed(2);
      _fraction.text = '${zone.billingFractionMinutes}';
      _opensAt = zone.opensAtMinutes;
      _closesAt = zone.closesAtMinutes;
      _status = zone.status;
      _types.addAll(zone.allowedTypes);
      _profiles.addAll(zone.authorizedProfiles);
      _spotIds.addAll(zone.spotIds);
    } else {
      _district.text = admin.district;
      _fraction.text = '30';
      _opensAt = 7 * 60;
      _closesAt = 23 * 60;
      _types.add(SpotType.standard);
      _profiles.add(AccessProfile.standard);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _district, _rate, _fraction]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime({required bool opening}) async {
    final current = (opening ? _opensAt : _closesAt) ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (opening) {
        _opensAt = minutes;
      } else {
        _closesAt = minutes;
      }
    });
  }

  List<String> _conflicts() {
    final admin = AdminScope.of(context);
    return ParkingRules.conflictingSpots(
      zoneId: widget.zoneId,
      selectedSpotIds: _spotIds,
      zones: admin.zones,
    );
  }

  String? _formLevelError() {
    final hours = ParkingRules.validateOperatingHours(_opensAt, _closesAt);
    if (hours != null) return hours;
    if (_types.isEmpty) return 'Select at least one allowed spot type';
    if (_profiles.isEmpty) return 'Select at least one authorized profile';
    if (_spotIds.isEmpty) return 'Assign at least one parking spot';
    final admin = AdminScope.of(context);
    for (final id in _spotIds) {
      final spot = admin.spotById(id);
      if (spot != null && !_types.contains(spot.type)) {
        return 'Spot ${spot.code} is ${spot.type.label}; allow that type or '
            'remove the spot';
      }
    }
    final conflicts = _conflicts();
    if (conflicts.isNotEmpty) {
      final codes = conflicts
          .map((id) => admin.spotById(id)?.code ?? id)
          .join(', ');
      return 'Spots already assigned to another zone: $codes. Resolve the '
          'assignment first.';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final fieldsValid = _formKey.currentState!.validate();
    final formError = _formLevelError();
    setState(() => _error = formError);
    if (!fieldsValid || formError != null) return;

    final draft = ParkingZone(
      id: _original?.id ?? '',
      name: _name.text.trim(),
      address: _address.text.trim(),
      district: _district.text.trim(),
      opensAtMinutes: _opensAt!,
      closesAtMinutes: _closesAt!,
      ratePerHour: double.parse(_rate.text.replaceAll(',', '.')),
      billingFractionMinutes: int.parse(_fraction.text),
      status: _status,
      allowedTypes: Set.of(_types),
      authorizedProfiles: Set.of(_profiles),
      spotIds: List.of(_spotIds),
    );

    setState(() => _saving = true);
    try {
      await AdminScope.of(context).saveZone(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.name} saved')),
      );
      Navigator.of(context).pop();
    } on ParkingRuleException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The zone could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().length < 3) ? 'Enter the $label' : null;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final title = _isEdit ? 'Edit parking zone' : 'New parking zone';

    if (_missingZone) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: EmptyView(
            icon: Icons.search_off,
            title: 'Zone not found',
            message: 'It may have been removed. Go back and refresh.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Parking zone settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Operating hours, rates, availability and spots for your '
                    'assigned facility.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('zone-name'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Zone name'),
                    validator: (v) => _required(v, 'zone name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('zone-address'),
                    controller: _address,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (v) => _required(v, 'address'),
                  ),
                  const SizedBox(height: 14),
                  _Pair(
                    left: TextFormField(
                      key: const Key('zone-district'),
                      controller: _district,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'District'),
                      validator: (v) => _required(v, 'district'),
                    ),
                    right: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Total spots',
                        helperText: 'Assigned below',
                      ),
                      child: Text('${_spotIds.length}'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Pair(
                    left: _TimeField(
                      key: const Key('zone-opens'),
                      label: 'Opens',
                      minutes: _opensAt,
                      onTap: () => _pickTime(opening: true),
                    ),
                    right: _TimeField(
                      key: const Key('zone-closes'),
                      label: 'Closes',
                      minutes: _closesAt,
                      onTap: () => _pickTime(opening: false),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Pair(
                    left: TextFormField(
                      key: const Key('zone-rate'),
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rate / hour',
                        prefixText: 'S/ ',
                      ),
                      validator: (v) {
                        final rate = double.tryParse(
                          (v ?? '').replaceAll(',', '.'),
                        );
                        if (rate == null || !rate.isFinite) {
                          return 'Enter a rate';
                        }
                        if (rate <= 0) return 'Must be positive';
                        return null;
                      },
                    ),
                    right: TextFormField(
                      key: const Key('zone-fraction'),
                      controller: _fraction,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Billing fraction',
                        suffixText: 'min',
                      ),
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        if (value == null) return 'Enter minutes';
                        if (value <= 0) return 'Must be positive';
                        if (value > 60) return 'Max 60 min';
                        return null;
                      },
                    ),
                  ),
                  const SectionTitle('Zone status'),
                  ChoiceChipBar<ZoneStatus>(
                    options: [
                      for (final s in ZoneStatus.values) ChipOption(s, s.label),
                    ],
                    selected: _status,
                    onSelected: (value) => setState(() => _status = value),
                  ),
                  const SectionTitle('Allowed spot types'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in SpotType.values)
                        SelectableChip(
                          key: Key('zone-type-${type.name}'),
                          label: type.label,
                          selected: _types.contains(type),
                          onTap: () => setState(() {
                            if (!_types.remove(type)) _types.add(type);
                          }),
                        ),
                    ],
                  ),
                  const SectionTitle('Authorized Driver profiles'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final profile in AccessProfile.values)
                        SelectableChip(
                          key: Key('zone-profile-${profile.name}'),
                          label: profile.label,
                          selected: _profiles.contains(profile),
                          onTap: () => setState(() {
                            if (!_profiles.remove(profile)) {
                              _profiles.add(profile);
                            }
                          }),
                        ),
                    ],
                  ),
                  SectionTitle(
                    'Assigned spots',
                    trailing: Text(
                      '${_spotIds.length} selected',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final spot in admin.spots)
                        Builder(
                          builder: (context) {
                            final owner = admin.zoneById(spot.zoneId);
                            final foreignZone =
                                owner != null && owner.id != widget.zoneId
                                ? owner.name.split(' ').take(2).join(' ')
                                : null;
                            return SelectableChip(
                              key: Key('zone-spot-${spot.code}'),
                              label: foreignZone != null
                                  ? '${spot.code} · $foreignZone'
                                  : '${spot.code} · ${spot.type.code}',
                              selected: _spotIds.contains(spot.id),
                              onTap: () => setState(() {
                                if (!_spotIds.remove(spot.id)) {
                                  _spotIds.add(spot.id);
                                }
                              }),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      key: const Key('zone-error'),
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
                  const NoticeCard(
                    message:
                        'This Administrator manages the assigned facility '
                        'only. A spot can belong to one zone at a time. '
                        'Reservations follow operating hours and billing '
                        'rules; changes are recorded in audit history.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('zone-save'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(_isEdit ? 'Save changes' : 'Create zone'),
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

class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  final String label;
  final int? minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule, size: 20),
        ),
        child: Text(minutes == null ? 'Select' : formatMinutesOfDay(minutes!)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ChipOption<T> {
  const ChipOption(this.value, this.label);

  final T value;
  final String label;
}

/// Horizontal single-select chips with a check mark on the active option.
class ChoiceChipBar<T> extends StatelessWidget {
  const ChoiceChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.wrap = false,
  });

  final List<ChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final option in options)
        SelectableChip(
          label: option.label,
          selected: option.value == selected,
          onTap: () => onSelected(option.value),
        ),
    ];
    if (wrap) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: chip),
        ],
      ),
    );
  }
}

class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? AppColors.textMuted
        : selected
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primaryMuted : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? AppColors.primaryMuted : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(color: foreground, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

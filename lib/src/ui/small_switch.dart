import 'package:flutter/material.dart';

import 'tokens.dart';

/// A switch of the size that fits a bar of small words, which Material's does not.
class SmallSwitch extends StatelessWidget {
  /// Constructor taking the state and what changes it, null where it cannot change now.
  const SmallSwitch({required this.value, required this.onChanged, required this.label, super.key});

  /// Whether it is on.
  final bool value;

  /// Told the new state.
  final ValueChanged<bool>? onChanged;

  /// What it switches, for a screen reader.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final change = onChanged;
    return Semantics(
      label: label,
      toggled: value,
      enabled: change != null,
      child: Material(
        // Off, the design's paler track cannot be told from the page.
        color: value ? colors.primary : colors.outline,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: change == null ? null : () => change(!value),
          child: SizedBox(
            width: Sizes.smallSwitchWidth,
            height: Sizes.smallSwitchHeight,
            child: AnimatedAlign(
              duration: kThemeChangeDuration,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all((Sizes.smallSwitchHeight - Sizes.smallSwitchKnob) / 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: value ? colors.onPrimary : Colors.white),
                  child: const SizedBox.square(dimension: Sizes.smallSwitchKnob),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

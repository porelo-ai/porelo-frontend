import 'package:flutter/material.dart';

import 'tokens.dart';

/// One option of a [ChoiceField]: what it is, what it is called, and what choosing it means.
class Choice<T> {
  /// Constructor taking the value, its label, and optionally what it means.
  const Choice(this.value, this.label, {this.means = '', this.id});

  /// What is chosen.
  final T value;

  /// What it is called in the list.
  final String label;

  /// What choosing it means, said under the field once it is the one chosen. Empty for nothing.
  final String means;

  /// The key its entry in the list carries, for a test to find it by.
  final String? id;
}

/// A choice from a list, **with nothing chosen until somebody chooses**, and what the chosen one
/// means said right under it — a cost or a warning is read at the moment of choosing, never hidden
/// in a list that has closed.
///
/// A drop-down rather than a column of radio buttons: a dialog asking three things stays one screen
/// tall instead of three.
class ChoiceField<T> extends StatelessWidget {
  /// Constructor taking the choices and what choosing does.
  const ChoiceField({
    required this.id,
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.hint = 'Choose one',
    super.key,
  });

  /// The key the field itself carries.
  final String id;

  /// What is being chosen.
  final String label;

  /// What there is to choose from.
  final List<Choice<T>> choices;

  /// What is chosen, or null.
  final T? value;

  /// Called with what was chosen.
  final ValueChanged<T?> onChanged;

  /// What the empty field says.
  final String hint;

  @override
  Widget build(BuildContext context) {
    final chosen = choices.where((each) => each.value == value).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<T>(
            key: Key(id),
            initialValue: chosen?.value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            hint: Text(hint),
            items: <DropdownMenuItem<T>>[
              for (final each in choices)
                DropdownMenuItem<T>(
                  key: each.id == null ? null : Key(each.id!),
                  value: each.value,
                  child: Text(each.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
          if (chosen != null && chosen.means.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.tight),
              child: Text(chosen.means, key: Key('$id-means'), style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

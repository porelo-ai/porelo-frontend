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
/// tall instead of three. A list longer than [filterAbove] opens a dialog that narrows as one types
/// instead, since a drop-down of every repository is taller than the window.
class ChoiceField<T> extends StatelessWidget {
  /// Constructor taking the choices and what choosing does.
  const ChoiceField({
    required this.id,
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.hint = 'Choose one',
    this.helper,
    super.key,
  });

  /// How many choices a drop-down holds at most; a longer list is filtered as one types.
  static const filterAbove = 8;

  /// The key the field itself carries; its filter, where it has one, carries `<id>-filter`.
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

  /// What the choice is among, under the field; null for nothing.
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final chosen = choices.where((each) => each.value == value).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (choices.length > filterAbove) _filtered(context, chosen) else _dropDown(chosen),
          if (chosen != null && chosen.means.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.tight),
              child: Text(chosen.means, key: Key('$id-means'), style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _dropDown(Choice<T>? chosen) => DropdownButtonFormField<T>(
    key: Key(id),
    initialValue: chosen?.value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, helperText: helper),
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
  );

  Widget _filtered(BuildContext context, Choice<T>? chosen) => InkWell(
    key: Key(id),
    onTap: () async {
      final picked = await showDialog<Choice<T>>(
        context: context,
        builder: (_) => _FilterDialog<T>(id: id, label: label, choices: choices, value: value),
      );
      if (picked != null) onChanged(picked.value);
    },
    child: InputDecorator(
      isEmpty: chosen == null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(chosen?.label ?? '', overflow: TextOverflow.ellipsis),
    ),
  );
}

/// The choices of a long list under a field that narrows them as one types; Enter takes the only
/// one left.
class _FilterDialog<T> extends StatefulWidget {
  const _FilterDialog({required this.id, required this.label, required this.choices, required this.value});

  final String id;
  final String label;
  final List<Choice<T>> choices;
  final T? value;

  @override
  State<_FilterDialog<T>> createState() => _FilterDialogState<T>();
}

class _FilterDialogState<T> extends State<_FilterDialog<T>> {
  String _filter = '';

  List<Choice<T>> get _shown {
    final words = _filter.trim().toLowerCase();
    return <Choice<T>>[
      for (final each in widget.choices)
        if (words.isEmpty || each.label.toLowerCase().contains(words)) each,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.dialogSmall, maxHeight: Sizes.finderHeight),
        child: Padding(
          padding: const EdgeInsets.all(Space.wide),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Space.small),
              TextField(
                key: Key('${widget.id}-filter'),
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Type to narrow the list'),
                onChanged: (typed) => setState(() => _filter = typed),
                onSubmitted: (_) {
                  if (shown.length == 1) Navigator.of(context).pop(shown.single);
                },
              ),
              const SizedBox(height: Space.small),
              if (shown.isEmpty)
                const Padding(padding: EdgeInsets.all(Space.normal), child: Text('Nothing here matches.'))
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final each in shown)
                        ListTile(
                          key: each.id == null ? null : Key(each.id!),
                          dense: true,
                          selected: each.value == widget.value,
                          title: Text(each.label, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.of(context).pop(each),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'window_size.dart';

/// One fact: its label and what it is.
final class Fact {
  /// Constructor taking the label, the value and, where a line goes above it, that.
  const Fact(this.label, this.value, {this.key, this.dividedAbove = false});

  /// What the fact is called.
  final String label;

  /// What it is: words, chips, or several lines.
  final Widget value;

  /// The row's automation key.
  final Key? key;

  /// Whether a thin line stands above it, parting it from the facts before.
  final bool dividedAbove;
}

/// Facts as label and value in two aligned columns, every label at one left edge and every value
/// at another; on a phone each label stands above its value, as two columns leave a value no room.
class FactRows extends StatelessWidget {
  /// Constructor taking the facts and how wide their label column is.
  const FactRows({required this.facts, this.labelWidth = Sizes.factLabel, super.key});

  /// The facts, in order.
  final List<Fact> facts;

  /// The label column's width.
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stacked = WindowSize.fromContext(context) == WindowSize.compact;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (place, fact) in facts.indexed) ...<Widget>[
          if (fact.dividedAbove && place > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.small),
              child: Divider(height: Space.hairline),
            ),
          Padding(
            key: fact.key,
            padding: const EdgeInsets.symmetric(vertical: Space.tight),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(fact.label, style: labelStyle),
                      const SizedBox(height: Space.tight),
                      fact.value,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: labelWidth,
                        child: Text(fact.label, style: labelStyle),
                      ),
                      const SizedBox(width: Space.wide),
                      Expanded(
                        child: Align(alignment: AlignmentDirectional.topStart, child: fact.value),
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

/// A host, a path or a digest, in the letters that tell `l` from `1`.
const TextStyle codeText = TextStyle(fontFamily: 'monospace', fontSize: 12);

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The one way a view says that it is reading: a thin bar at the top of its content and, until its
/// first answer, one sentence of what is read and from where, in the place of that answer.
///
/// A view that reads the same thing again keeps its answer under the bar and gives no sentence; a
/// view that has no answer yet never shows its empty words beside this, which would read as one.
class Reading extends StatelessWidget {
  /// Shows the bar, and [words] under it where given.
  const Reading({this.words, this.inset = false, super.key = const Key('reading')});

  /// What is read and from where, as one sentence; null while an answer already stands below.
  final String? words;

  /// Whether the sentence keeps the side margin of a pane's rows, rather than a dialog's content.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final words = this.words;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const LinearProgressIndicator(minHeight: Sizes.progressBar),
        if (words != null)
          Padding(
            padding: EdgeInsets.fromLTRB(inset ? Space.normal : 0, Space.small, inset ? Space.normal : 0, Space.small),
            child: Text(words, key: const Key('reading-words'), style: Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    );
  }
}

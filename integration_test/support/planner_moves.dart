import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the story of work moving on by itself shares between its steps.
abstract final class PlannerMoves {
  /// The tasks porelo listed before the person opened the Needs-you entry.
  static Set<String> tasksBeforeOpening = {};
}

/// The entry of issue [issue] under what needs a person: a row of its own that names it.
Finder theEntryOf(String issue) => find.ancestor(
  of: find.textContaining(issue),
  matching: find.byWidgetPredicate(
    (widget) => widget.key is ValueKey && '${(widget.key! as ValueKey).value}'.startsWith('attention-row '),
  ),
);

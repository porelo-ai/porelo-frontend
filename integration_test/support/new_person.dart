import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether this run is the walk of a person new to Porelo: only where it is asked for, since it
/// empties the account it runs in (`PORELO_E2E_NEW_PERSON=1`, with the account in `PORELO_E2E_HOST`).
bool get walkingAsANewPerson => Platform.environment['PORELO_E2E_NEW_PERSON'] == '1';

/// What the window says now, every text on it in order: what a person reads at this step.
/// A field shows what is typed in it as `[typed]`, and an answer that can be selected as itself.
List<String> whatTheWindowSays(WidgetTester tester) => <String>[
  for (final each in tester.widgetList<Widget>(
    find.byWidgetPredicate((widget) => widget is Text || widget is SelectableText || widget is EditableText),
  ))
    if (_said(each).trim().isNotEmpty) _said(each).trim(),
];

String _said(Widget widget) => switch (widget) {
  Text(:final data, :final textSpan) => data ?? textSpan?.toPlainText() ?? '',
  SelectableText(:final data, :final textSpan) => data ?? textSpan?.toPlainText() ?? '',
  EditableText(:final controller) => controller.text.isEmpty ? '' : '[${controller.text}]',
  _ => '',
};

/// Writes what the window says at [step] to the walk's log, for the person reading the walk.
void noteTheWindow(WidgetTester tester, String step) {
  final log = Platform.environment['PORELO_E2E_NEW_PERSON_LOG'];
  final said = '--- $step\n${whatTheWindowSays(tester).join('\n')}\n';
  if (log == null || log.isEmpty) {
    // ignore: avoid_print
    print(said);
  } else {
    File(log).writeAsStringSync(said, mode: FileMode.append);
  }
}

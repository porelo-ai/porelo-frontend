import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the machine {'the build machine'} says {'Host key verification failed.'}
Future<void> theMachineSays(WidgetTester tester, String name, String words) async {
  await lookingAtTheMachines(tester, () async {
    // The transport's own sentence, on the machine's row: "Host key verification failed" is a
    // different problem from a machine that is simply not there.
    final row = find.byKey(ValueKey<String>('machines-row $name'));
    expect(row, findsOneWidget, reason: '$name is not among the machines');
    final said = [
      for (final text in tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))))
        text.data ?? text.textSpan?.toPlainText() ?? '',
    ].join(' ');
    expect(said.contains(words), isTrue, reason: 'the transport said "$words" and nothing showed it: $said');
  });
}

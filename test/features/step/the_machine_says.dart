import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the machine {'the build machine'} says {'Host key verification failed.'}
Future<void> theMachineSays(WidgetTester tester, String name, String words) async {
  await lookingAtTheMachines(tester, () async {
    // The transport's own sentence, on the machine's rail entry: "Host key verification failed" is
    // a different problem from a machine that is simply not there.
    final said = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tip) => tip.message ?? '')
        .where((message) => message.contains(name));
    expect(
      said.any((message) => message.contains(words)),
      isTrue,
      reason: 'the transport said "$words" and nothing showed it: $said',
    );
  });
}

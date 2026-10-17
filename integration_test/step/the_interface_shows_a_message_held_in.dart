import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: the interface shows a message held in {'porelo-e2e-talk-e2e-talk'}
Future<void> theInterfaceShowsAMessageHeldIn(WidgetTester tester, String task) async {
  // Where a person looks for it: what needs a person, from the tree.
  await toThePlace(tester, 'attention');
  await pumpFor(tester);
  final row = find.byKey(ValueKey<String>('read-message $task/$theHeldMessage'));
  await pumpUntil(tester, () => row.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30), what: 'the held message in what needs a person');
}

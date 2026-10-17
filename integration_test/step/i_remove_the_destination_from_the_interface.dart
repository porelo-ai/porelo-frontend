import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I remove the destination {'e2e-weather'} from the interface
Future<void> iRemoveTheDestinationFromTheInterface(WidgetTester tester, String name) async {
  await openTheDestinations(tester);
  final remove = find.byKey(ValueKey<String>('remove-destination $name'));
  await pumpUntil(tester, () => remove.evaluate().isNotEmpty, what: 'the destination $name listed');
  await tester.ensureVisible(remove);
  await tester.tap(remove);
  // Waited for by its own words: what writing said is still on screen until removing answers.
  await pumpUntil(
    tester,
    () =>
        find.textContaining('Removed $name').evaluate().isNotEmpty ||
        find.textContaining('Nothing of your own').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to say what removing did',
  );
}

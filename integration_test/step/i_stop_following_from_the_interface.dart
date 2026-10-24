import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I stop following {'e2e-follow'} from the interface
Future<void> iStopFollowingFromTheInterface(WidgetTester tester, String name) async {
  // From the chosen project's own menu, which is where the command lives.
  await pumpUntil(
    tester,
    () => find.byKey(const Key('project-menu')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: "the project's menu",
  );
  await tester.tap(find.byKey(const Key('project-menu')));
  await pumpUntil(
    tester,
    () => find.text('Stop following this project').evaluate().isNotEmpty,
    what: "the project's menu, open",
  );
  // Found is not in place: the menu is still growing, and a tap during it lands beside the entry.
  await pumpFor(tester);
  // The menu's groups make it taller than a small screen; its last entry is scrolled to first.
  await tester.ensureVisible(find.text('Stop following this project').last);
  await pumpFor(tester);
  await tester.tap(find.text('Stop following this project').last);
  await pumpFor(tester);
  // The preview first, then the press that agrees to it.
  await pumpUntil(
    tester,
    () => find.byKey(const Key('remove-what-was-built')).evaluate().isNotEmpty,
    what: 'what stopping following would take',
  );
  await pumpUntil(
    tester,
    () => find.byKey(const Key('deletion-says')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the preview',
  );
  await tester.tap(find.byKey(const Key('remove-what-was-built')));
  await pumpUntil(
    tester,
    () => (tester.widget<Text>(find.byKey(const Key('deletion-says'))).data ?? '').contains('no longer followed'),
    timeout: const Duration(seconds: 60),
    what: '$name to be no longer followed',
  );
}

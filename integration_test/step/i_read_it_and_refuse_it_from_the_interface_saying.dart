import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/expand_list_rows.dart';
import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: I read it and refuse it from the interface, saying {'not before the tests pass'}
Future<void> iReadItAndRefuseItFromTheInterfaceSaying(WidgetTester tester, String reason) async {
  await expandListRows(tester);
  final row = find.byWidgetPredicate(
    (each) =>
        each.key is ValueKey<String> &&
        (each.key! as ValueKey<String>).value.endsWith('/$theHeldMessage') &&
        (each.key! as ValueKey<String>).value.startsWith('read-message '),
  );
  await tester.ensureVisible(row);
  await tester.tap(row);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('held-message-part 0')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to show the message in full',
  );
  theMessageRead = tester.widget<SelectableText>(find.byKey(const Key('held-message-part 0'))).data;
  await tester.enterText(find.byKey(const Key('held-message-refuse-reason')), reason);
  await tester.pump();
  await tester.tap(find.byKey(const Key('refuse-message')));
  // Decided, the dialog closes and says what came of it at the foot of the window; where there is no
  // window to say it in, the dialog stays and says it itself.
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('held-message-decided')).evaluate().isNotEmpty ||
        find.byKey(const Key('held-message-outcome')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to answer the decision',
  );
}

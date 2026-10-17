import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: I declare the machine's own key for {'ssh://e2e.invalid/'} from the interface
Future<void> iDeclareTheMachinesOwnKeyForFromTheInterface(WidgetTester tester, String match) async {
  await openTheConnectionWizard(tester);
  await tester.enterText(find.byKey(const Key('connection-match')), match);
  await choose(tester, 'connection-kind', 'kind-SSH_KEY');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await pumpUntilShown(tester, const Key('connection-way'));
  await choose(tester, 'connection-way', 'way-machine');
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('connection-key')).evaluate().isNotEmpty ||
        find.byKey(const Key('connection-keys-unavailable')).evaluate().isNotEmpty,
    what: 'the machine to list its keys',
  );
  if (find.byKey(const Key('connection-key')).evaluate().isNotEmpty) {
    await choose(tester, 'connection-key', 'key $theKey');
  } else {
    // A published Porelo older than the listing: the path is typed, and the run says so.
    debugPrint('this Porelo lists no keys; the path of $theKey was typed');
    await tester.enterText(find.byKey(const Key('connection-id')), theKey!);
    await pumpFor(tester);
  }
  await tester.tap(find.byKey(const Key('wizard-next')));
  // The real daemon's dry run: the check has to pass before adding is offered.
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('connection-check-says')).evaluate().isNotEmpty ||
        find.byKey(const Key('connection-check-failed')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to check it',
  );
  await tester.tap(find.byKey(const Key('connection-add')));
  await pumpUntil(
    tester,
    () => find.byKey(const Key('connection-declared')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to say what it wrote',
  );
}

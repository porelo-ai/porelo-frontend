import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: I copy the machine's own key into the vault for {'ssh://e2e-vault.invalid/'} from the interface
Future<void> iCopyTheMachinesOwnKeyIntoTheVaultForFromTheInterface(WidgetTester tester, String match) async {
  await openTheConnectionWizard(tester);
  await tester.enterText(find.byKey(const Key('connection-match')), match);
  await choose(tester, 'connection-kind', 'kind-SSH_KEY');
  await tester.tap(find.byKey(const Key('wizard-next')));
  await pumpUntilShown(tester, const Key('connection-way'));
  await choose(tester, 'connection-way', 'way-machine');
  await pumpUntil(
    tester,
    () => find.byKey(const Key('connection-key')).evaluate().isNotEmpty,
    what: 'the machine to list its keys',
  );
  await choose(tester, 'connection-key', 'key $theKey');
  await choose(tester, 'connection-keep', 'keep-in-the-vault');
  await tester.tap(find.byKey(const Key('wizard-next')));
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

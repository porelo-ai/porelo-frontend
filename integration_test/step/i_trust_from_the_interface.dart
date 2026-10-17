import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I trust {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'} from the interface
Future<void> iTrustFromTheInterface(WidgetTester tester, String fingerprint) async {
  await choose(tester, 'host-key-choice', 'host-key-$fingerprint');
  await tester.ensureVisible(find.byKey(const Key('follow-trust-host-key')));
  await tester.tap(find.byKey(const Key('follow-trust-host-key')));
  // Trusting, then the follow again: done when the answer no longer names an unknown host.
  await pumpUntil(
    tester,
    () {
      final says = find.byKey(const Key('follow-says'));
      return find.byKey(const Key('host-key-refused')).evaluate().isNotEmpty ||
          (says.evaluate().isNotEmpty && !(tester.widget<Text>(says).data ?? '').contains('never met that host'));
    },
    timeout: const Duration(seconds: 60),
    what: 'the key to be trusted and the follow made again',
  );
}

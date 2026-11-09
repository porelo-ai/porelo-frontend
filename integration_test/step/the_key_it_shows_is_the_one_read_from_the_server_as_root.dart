import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: the key it shows is the one read from the server as root
Future<void> theKeyItShowsIsTheOneReadFromTheServerAsRoot(WidgetTester tester) => pictured(tester, () async {
  // The window trusts the key the organization's card holds, and says it on the host's page; the rehearsal read the
  // server's own over its root ssh when it was rented. The key itself is compared, never its comment.
  final read = Rehearsal.hostKey.split(' ').take(2).join(' ');
  final page = find.byKey(ValueKey('organization-host ${Rehearsal.hostName}'));
  final said = RegExp(r'SSH host key (\S+ \S+)');
  // The page builds what is in view: its key line is at its foot, below the host's facts and projects.
  final line = find.descendant(of: page, matching: find.textContaining('SSH host key'));
  await tester.scrollUntilVisible(
    line,
    300,
    scrollable: find.descendant(of: page, matching: find.byType(Scrollable)).first,
    maxScrolls: 40,
  );
  await pumpUntil(tester, () => said.hasMatch(theWordsUnder(tester, page)), what: 'the host page to say its key');
  expect(said.firstMatch(theWordsUnder(tester, page))!.group(1), read, reason: 'the key read from the server as root');
});

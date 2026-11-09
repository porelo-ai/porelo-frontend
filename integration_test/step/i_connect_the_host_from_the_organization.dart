import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';
import 'i_open_the_organizations_machines.dart';

/// Usage: I connect the host from the organization
Future<void> iConnectTheHostFromTheOrganization(WidgetTester tester) async {
  // A run starts unconnected: a host found connected already was not connected by this press.
  await connectTheHost(tester, alreadyIsAFault: true);
}

/// Connects the host from its row on the organization's machines, where a person's own host offers *Connect*.
Future<void> connectTheHost(WidgetTester tester, {required bool alreadyIsAFault}) async {
  await iOpenTheOrganizationsMachines(tester);
  final row = find.byKey(ValueKey<String>('my-host ${Rehearsal.hostName}'));
  await pumpUntil(
    tester,
    () => row.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the host as mine',
  );
  Finder said(String words) => find.descendant(of: row, matching: find.text(words));
  final connect = find.descendant(
    of: row,
    matching: find.byKey(ValueKey<String>('organization.connect/${Rehearsal.hostName}')),
  );
  if (said('Connected').evaluate().isNotEmpty) {
    if (alreadyIsAFault) fail('${Rehearsal.hostName} was connected before the run pressed Connect');
    return;
  }
  await pumpUntil(tester, () => connect.evaluate().isNotEmpty, what: 'Connect on the host');
  await tester.ensureVisible(connect.first);
  await tester.tap(connect.first);
  await pumpFor(tester);
  await pumpUntil(
    tester,
    () => said('Connected').evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the host to stand connected',
  );
}

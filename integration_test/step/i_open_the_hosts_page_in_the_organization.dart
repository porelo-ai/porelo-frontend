import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';
import 'i_open_the_organizations_machines.dart';

/// Usage: I open the host's page in the organization
Future<void> iOpenTheHostsPageInTheOrganization(WidgetTester tester) => pictured(tester, () async {
  await iOpenTheOrganizationsMachines(tester);
  final row = find.byKey(ValueKey<String>('my-host ${Rehearsal.hostName}'));
  await pumpUntil(tester, () => row.evaluate().isNotEmpty, what: 'the host as mine');
  await tester.ensureVisible(row.first);
  await tester.tap(find.descendant(of: row, matching: find.text(Rehearsal.hostName)).first);
  await pumpFor(tester);
  await pumpUntil(
    tester,
    () => find.byKey(ValueKey('organization-host ${Rehearsal.hostName}')).evaluate().isNotEmpty,
    what: 'the host page of the organization',
  );
});

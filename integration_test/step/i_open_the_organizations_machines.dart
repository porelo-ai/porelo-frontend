import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I open the organization's machines
Future<void> iOpenTheOrganizationsMachines(WidgetTester tester) async {
  await toThePlace(tester, 'organizations');
  // The person follows the one test organization; its name is the rail's, whatever it is called.
  final organization = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> && RegExp(r'^rail organization [^ ]+$').hasMatch((w.key! as ValueKey<String>).value),
  );
  // Read after the place was chosen, the organization's row stays folded under it: unfolded as a person would.
  final fold = find.byKey(const ValueKey<String>('fold organizations'));
  await pumpUntil(
    tester,
    () => organization.evaluate().isNotEmpty || fold.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 1),
    what: 'the organization',
  );
  if (organization.evaluate().isEmpty) {
    await tester.ensureVisible(fold.first);
    await tester.tap(fold.first);
    await pumpUntil(tester, () => organization.evaluate().isNotEmpty, what: "the organization's row");
  }
  final key = (organization.evaluate().first.widget.key! as ValueKey<String>).value;
  await tester.ensureVisible(organization.first);
  await tester.tap(organization.first);
  await pumpFor(tester);
  final machines = find.byKey(ValueKey<String>('$key machines'));
  await pumpUntil(tester, () => machines.evaluate().isNotEmpty, what: 'its Machines');
  await tester.ensureVisible(machines.first);
  await tester.tap(machines.first);
  await pumpFor(tester);
}

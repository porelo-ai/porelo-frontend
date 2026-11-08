import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_dialogs.dart';

import '../support/organization_fixtures.dart';

const _cannotSay = OrganizationRefused(
  "the forge could not say enough of its people's keys and owners to judge this change: see whether this person's "
  'forge token is set',
);

Future<Organization> _refused(WidgetTester tester, {required bool? shut, void Function()? opened}) async {
  final source = FixtureOrganization(organizationFor('pat'));
  final organization = Organization(source)
    ..thisComputersVaultShut = (() async => shut)
    ..openThisComputersVault = (() async => opened?.call());
  addTearDown(organization.dispose);
  await organization.refresh();
  source.refuseNext = _cannotSay;
  await organization.write(OrganizationChange.removeHost, {'host': 'orchard'}, provisional: true);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: OrganizationPendingRow(organization, organization.rowChanges.single))),
  );
  await tester.pumpAndSettle();
  return organization;
}

void main() {
  // Harm: a refusal names a token the person cannot see, while the way on is this computer's shut vault.
  testWidgets('a refused change with this computer\'s vault shut says so and opens it', (tester) async {
    var opened = 0;
    await _refused(tester, shut: true, opened: () => opened++);
    expect(find.textContaining("see whether this person's forge token is set"), findsOneWidget);
    expect(find.textContaining("This computer's Porelo-Vault is shut"), findsOneWidget);
    await tester.tap(find.byKey(const Key('organization-open-vault')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  // Harm: a vault that is open, or not known, is named as the cause.
  testWidgets('with the vault open, or its state not known, the refusal stands alone', (tester) async {
    await _refused(tester, shut: false);
    expect(find.textContaining("Porelo-Vault is shut"), findsNothing);
    expect(find.byKey(const Key('organization-open-vault')), findsNothing);
    await _refused(tester, shut: null);
    expect(find.textContaining("Porelo-Vault is shut"), findsNothing);
  });
}

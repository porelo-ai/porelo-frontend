import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';

/// Usage: the machine records {'e2e-grant'} as granted by the account the machine is reached as
Future<void> theMachineRecordsAsGrantedByTheAccountTheMachineIsReachedAs(WidgetTester tester, String entry) async {
  // The account that ran the grant: `frontend` on the VM, whatever the lease names on a rented one.
  final account = E2e.host.contains('@') ? E2e.host.split('@').first : E2e.host;
  final client = await PoreloClient.connect(Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  final row = (await client.credentials()).credentials.where((each) => each.name == entry).single;
  expect(row.grant?.grantedBy, account);
  expect(DateTime.tryParse(row.grant?.grantedAt ?? ''), isNotNull);
}

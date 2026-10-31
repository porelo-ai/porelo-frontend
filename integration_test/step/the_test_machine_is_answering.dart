import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/machine_details_page.dart';

import '../support/e2e.dart';

/// Usage: the test machine is answering
Future<void> theTestMachineIsAnswering(WidgetTester tester) async {
  await switchTo(tester, E2e.name);
  // Its own page says Connected only while it answers; "Not connected; last known state" otherwise.
  await pumpUntil(
    tester,
    () => find.descendant(of: find.byType(MachineDetailsPage), matching: find.text('Connected')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 45),
    what: '${E2e.name} answering',
  );
}

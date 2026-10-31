import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import 'the_machine_is_shown_as_not_answering.dart';

/// Usage: the machine is shown as answering
Future<void> theMachineIsShownAsAnswering(WidgetTester tester) async {
  // On the list of machines, where each row says how it stands.
  await lookingAtTheMachines(tester, () async {
    final said = whatTheMachinesRowSays(tester, World.machines.current.name);
    expect(said, allOf(contains('Connected'), isNot(contains('Not connected'))), reason: 'its row says: $said');
  });
}

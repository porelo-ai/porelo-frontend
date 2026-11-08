import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import 'the_machine_is_shown_as_not_answering.dart';

/// Usage: the machine {'the build machine'} says {'Host key verification failed.'}
Future<void> theMachineSays(WidgetTester tester, String name, String words) async {
  await lookingAtTheMachines(tester, () async {
    // The transport's own sentence, on the machine's row: "Host key verification failed" is a
    // different problem from a machine that is simply not there.
    final row = railEntryFor(name);
    expect(row, findsOneWidget, reason: '$name is not among the machines');
    final said = whatTheMachinesRowSays(tester, name);
    expect(said.contains(words), isTrue, reason: 'the transport said "$words" and nothing showed it: $said');
  });
}

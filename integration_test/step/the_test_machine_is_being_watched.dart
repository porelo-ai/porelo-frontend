import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/main.dart' as app;

import '../support/e2e.dart';
import 'i_watch_the_test_machine_through_a_forward_raised_here.dart';
import 'the_test_machine_is_answering.dart';

/// Usage: the test machine is being watched
Future<void> theTestMachineIsBeingWatched(WidgetTester tester) async {
  // Added once per run: the interface outlives each scenario, so a later one finds it there.
  final machines = (await app.porelo()).machines;
  if (!machines.all.any((machine) => machine.name == E2e.name)) {
    await iWatchTheTestMachineThroughAForwardRaisedHere(tester);
  }
  await theTestMachineIsAnswering(tester);
}

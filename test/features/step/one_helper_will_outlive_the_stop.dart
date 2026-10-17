import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: one helper will outlive the stop
Future<void> oneHelperWillOutliveTheStop(WidgetTester tester) async {
  // A helper that survives its stop is not something a contrived task list can produce, and it is
  // the case that matters: somebody has to kill it by hand.
  World.backend.nextPanic = const Panicked(
    tasks: <PanickedTask>[],
    surviving: <String>['porelo-checkout-shell-gate (pid 4711)'],
    previewed: false,
  );
}

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the next machine says nothing of which node it is
///
/// Every test machine over ssh is the one fake backend, which would make it this machine reached
/// twice, whose work is drawn once. An older daemon says nothing, and is another machine.
Future<void> theNextMachineSaysNothingOfWhichNodeItIs(WidgetTester tester) async {
  World.backend.nodeId = '';
}

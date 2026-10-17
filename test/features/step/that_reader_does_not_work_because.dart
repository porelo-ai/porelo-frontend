import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: that reader does not work because {'not installed'}
Future<void> thatReaderDoesNotWorkBecause(WidgetTester tester, String problem) async {
  World.backend.followBuilds('porelo-checkout-shell', problem: problem);
  await World.settle(tester);
}

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the stop asked for {'porelo-checkout-shell'}
Future<void> theStopAskedFor(WidgetTester tester, String task) async {
  // Read off the socket: a removal of running work goes through a stop first.
  expect(World.backend.stops, isNotEmpty);
  expect(World.backend.stops.last, task);
}

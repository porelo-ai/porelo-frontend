import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the planner holds the next started report
Future<void> thePlannerHoldsTheNextStartedReport(WidgetTester tester) async {
  World.planning.holdNextStarted = Completer<void>();
}

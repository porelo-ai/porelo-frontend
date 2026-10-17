import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was asked to start {'setsid porelod'}
Future<void> theMachineWasAskedToStart(WidgetTester tester, String part) async {
  expect(World.startsAsked, isNotEmpty, reason: 'nothing was run on that machine');
  expect(World.startsAsked.last.join(' '), contains(part));
}

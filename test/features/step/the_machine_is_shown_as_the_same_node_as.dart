import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the machine {'elsewhere'} is shown as the same node as {'this machine'}
///
/// Read off that machine's own title, so it is the machine in question that is marked and not
/// merely the words appearing somewhere on screen.
Future<void> theMachineIsShownAsTheSameNodeAs(WidgetTester tester, String name, String other) async {
  await tapOnScreen(tester, railEntryFor(name));
  await World.settle(tester);
  final kind = tester.widget<Text>(find.byKey(const Key('machine-kind'))).data ?? '';
  expect(kind, contains('the same node as $other'), reason: '$name does not say it is the same node as $other: $kind');
}

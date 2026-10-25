import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: Join is offered again
Future<void> joinIsOfferedAgain(WidgetTester tester) async {
  expect(find.byKey(const Key('join-person')), findsOneWidget, reason: 'a removed identity must be able to join again');
  expect(find.byKey(const Key('joined-as')), findsNothing);
  expect(find.byKey(const Key('join-reset')), findsNothing);
  expect(find.byKey(const Key('login password')), findsNothing, reason: 'the removed login is obsolete');
  expect(
    World.settings.messagePerson(World.machines.current.name, 'checkout'),
    isNull,
    reason: 'the removed identity must stay cleared after reopening',
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_look_at_the_forges_repository.dart';

/// Usage: binding is not offered for {'acme/web'}
Future<void> bindingIsNotOfferedFor(WidgetTester tester, String repository) async {
  expect(find.byKey(ValueKey<String>('repository $repository')), findsOneWidget);
  await chooseTheRepository(tester, repository);
  await tester.tap(find.byKey(ValueKey<String>('forge-repository-menu $repository')));
  await World.settle(tester);
  // Listed with why it cannot run, as every command is, but never runnable.
  final follow = find.byKey(const ValueKey<String>('repository.follow'));
  expect(
    follow.evaluate().every((element) => !(element.widget as PopupMenuItem<String>).enabled),
    isTrue,
    reason: 'following $repository as a project is offered',
  );
  await tester.tapAt(Offset.zero);
  await World.settle(tester);
}

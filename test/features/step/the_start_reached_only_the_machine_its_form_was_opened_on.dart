import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the start reached only the machine its form was opened on
///
/// The first machine, where the form was opened: its start and the operation that names it; nothing asked of or
/// started on the machine chosen meanwhile.
Future<void> theStartReachedOnlyTheMachineItsFormWasOpenedOn(WidgetTester tester) async {
  final opened = World.machines.all.first;
  expect(World.elsewhere.canStartAsked, 0, reason: 'nothing may be asked of the machine chosen meanwhile');
  expect(World.elsewhere.starts, isEmpty, reason: 'nothing may start on the machine chosen meanwhile');
  expect(World.backend.starts, hasLength(1), reason: 'the start must reach the machine its form was opened on');
  expect(World.operations.all.last.machine, opened.name, reason: 'the operation names where it started');
}

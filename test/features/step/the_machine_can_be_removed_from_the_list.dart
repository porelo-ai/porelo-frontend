import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: the machine {'this machine'} can be removed from the list {false}
Future<void> theMachineCanBeRemovedFromTheList(WidgetTester tester, String machine, bool can) async {
  await toTheMachines(tester);
  await expandListRows(tester, within: find.byKey(ValueKey<String>('machines-row $machine')));
  await tester.tap(find.byKey(ValueKey<String>('machines-menu $machine')));
  await World.settle(tester);
  final remove = tester.widget<PopupMenuItem<String>>(find.byKey(const Key('machine.forget')));
  expect(remove.enabled, can, reason: 'removal availability must reflect the command, including a visible refusal');
  await tester.tapAt(Offset.zero);
  await World.settle(tester);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I remove {'elsewhere'} from the list of machines
Future<void> iRemoveFromTheListOfMachines(WidgetTester tester, String machine) async {
  await toTheMachinesPage(tester, machine);
  await tester.tap(find.byKey(const Key('machine-menu')));
  await World.settle(tester);
  await tester.tap(find.text('Forget this machine').last);
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('forget-it')));
  await World.settle(tester);
}

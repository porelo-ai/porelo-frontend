import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I remove {'elsewhere'} from the list of machines
Future<void> iRemoveFromTheListOfMachines(WidgetTester tester, String machine) async {
  await toTheMachines(tester);
  await expandListRows(tester, within: find.byKey(ValueKey<String>('machines-row $machine')));
  await tester.tap(find.byKey(ValueKey<String>('machines-menu $machine')));
  await World.settle(tester);
  await tester.tap(find.text('Remove from this list').last);
  await World.settle(tester);
}

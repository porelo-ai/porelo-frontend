import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../support/world.dart';

/// Usage: the tree destination {'facts-page'} is shown {true}
Future<void> theTreeDestinationIsShown(WidgetTester tester, String entry, bool shown) async {
  final key = entry == 'current machine' ? 'rail ${ShellPlace.machineKey(World.machines.current.name)}' : entry;
  expect(find.byKey(Key(key)).hitTestable(), shown ? findsOneWidget : findsNothing);
}

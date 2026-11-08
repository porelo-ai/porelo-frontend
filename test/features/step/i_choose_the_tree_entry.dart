import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../support/world.dart';

/// Usage: I choose the tree entry {'current vault'}
Future<void> iChooseTheTreeEntry(WidgetTester tester, String entry) async {
  final machine = ShellPlace.machineKey(World.machines.current.name);
  final key = entry.startsWith('current ')
      ? entry == 'current machine'
            ? 'rail $machine'
            : 'rail $machine ${entry.substring(8)}'
      : 'rail $entry';
  await World.tapInView(tester, key);
}

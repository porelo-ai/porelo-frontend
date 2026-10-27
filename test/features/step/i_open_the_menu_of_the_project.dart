import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I open the menu of the project {'checkout'}
Future<void> iOpenTheMenuOfTheProject(WidgetTester tester, String project) async {
  await toTheProjects(tester);
  await expandListRows(tester);
  await tester.tap(find.byKey(ValueKey<String>('projects-menu ${World.machines.current.name}/$project')));
  await World.settle(tester);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I choose {'Show what this project would open, creating nothing'} from the menu of the project {'checkout'}
Future<void> iChooseFromTheMenuOfTheProject(WidgetTester tester, String entry, String project) async {
  await toTheProjects(tester);
  await tester.tap(find.byKey(ValueKey<String>('projects-menu ${World.machines.current.name}/$project')));
  await World.settle(tester);
  final item = find.ancestor(
    of: find.text(entry),
    matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  );
  await tester.ensureVisible(item);
  await tester.pump();
  await tester.tap(item);
  await World.settle(tester);
}

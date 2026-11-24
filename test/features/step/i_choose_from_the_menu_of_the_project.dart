import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import '../../support/expand_list_rows.dart';
import '../../support/menu_entries.dart';

/// Usage: I choose {'Show what this project would open, creating nothing'} from the menu of the project {'checkout'}
Future<void> iChooseFromTheMenuOfTheProject(WidgetTester tester, String entry, String project) async {
  await toTheProjects(tester);
  await expandListRows(tester);
  await tester.tap(find.byKey(ValueKey<String>('projects-menu ${World.machines.current.name}/$project')));
  await World.settle(tester);
  // Opened from its submenu first, where it stands in one, as a person would.
  final item = await revealMenuEntryLabeled(tester, entry);
  await tester.ensureVisible(item);
  await tester.pump();
  await tester.tap(item);
  await World.settle(tester);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

/// An action of the organization's pages: the button a section's header shows, or the ⋮ on a row that holds it.
Finder organizationAction(String id) => find.byWidgetPredicate(
  (widget) =>
      widget.key == ValueKey<String>('organization.$id') ||
      (widget is CommandMenu && widget.commands.any((command) => command.id == 'organization.$id' && command.visible)),
  description: 'the action $id',
);

/// Presses an action, through its row's ⋮ when it stands in one.
Future<void> pressOrganizationAction(WidgetTester tester, String id, {Future<void> Function()? settle}) async {
  Future<void> settled() => settle?.call() ?? tester.pumpAndSettle();
  final target = organizationAction(id);
  await tester.ensureVisible(target);
  await settled();
  await tester.tap(target);
  await settled();
  final entry = find.byKey(ValueKey<String>('organization.$id'));
  if (tester.any(find.byType(PopupMenuItem<String>))) {
    await tester.tap(entry);
    await settled();
  }
}

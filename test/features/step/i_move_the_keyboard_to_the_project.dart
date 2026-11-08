import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I move the keyboard to the project {'billing'}
///
/// Tab reaches the tree, arrows choose its destination, and Tab then reaches the project row.
Future<void> iMoveTheKeyboardToTheProject(WidgetTester tester, String project) async {
  // Projects are on their own page, reached from the rail by the keyboard too.
  if (find.byKey(const Key('projects-page')).evaluate().isEmpty) {
    var inTree = false;
    for (var press = 0; press < 40; press++) {
      final focused = FocusManager.instance.primaryFocus?.context;
      inTree = focused?.widget.key == const Key('navigation-tree-focus');
      focused?.visitAncestorElements((element) {
        inTree = inTree || element.widget.key == const Key('navigation-tree-focus');
        return !inTree;
      });
      if (inTree) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    if (!inTree) fail('the keyboard never reached the navigation tree');
    for (var press = 0; press < 40; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
    }
    var onProjects = false;
    for (var press = 0; press < 40; press++) {
      onProjects = find
          .byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.focused == true && widget.properties.label == 'My projects',
          )
          .evaluate()
          .isNotEmpty;
      if (onProjects) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    if (!onProjects) fail('the keyboard never reached My projects in the tree');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await World.settle(tester);
  }
  // Its row on the machine being acted on.
  final row = ValueKey<String>('project ${World.machines.current.name}/$project');
  for (var press = 0; press < 80; press++) {
    final focused = FocusManager.instance.primaryFocus?.context;
    var there = false;
    focused?.visitAncestorElements((element) {
      there = element.widget.key == row;
      return !there;
    });
    if (there || focused?.widget.key == row) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  await World.settle(tester);
  fail('the keyboard never reached the project $project');
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I move the keyboard to the project {'billing'}
///
/// Tab, and nothing else: a card that the keyboard cannot reach is one only a pointer can use.
Future<void> iMoveTheKeyboardToTheProject(WidgetTester tester, String project) async {
  // Projects are on their own page, reached from the rail by the keyboard too.
  if (find.byKey(const Key('projects-page')).evaluate().isEmpty) {
    for (var press = 0; press < 40; press++) {
      final focused = FocusManager.instance.primaryFocus?.context;
      var there = focused?.widget.key == const ValueKey<String>('rail projects');
      focused?.visitAncestorElements((element) {
        there = there || element.widget.key == const ValueKey<String>('rail projects');
        return !there;
      });
      if (there) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
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

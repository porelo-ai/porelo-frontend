import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: the interface lists the project {'default'} first
Future<void> theInterfaceListsTheProjectFirst(WidgetTester tester, String name) async {
  await toTheMachines(tester);
  await switchTo(tester, E2e.name);
  final projects = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> && RegExp(r'^project [^/]+$').hasMatch((widget.key! as ValueKey<String>).value),
  );
  for (var i = 0; i < 12 && projects.evaluate().isEmpty; i++) {
    await showOnTheMachines(tester, projects);
    await pumpFor(tester, const Duration(seconds: 5));
  }
  expect(projects, findsWidgets, reason: 'the projects of the machine are not listed');
  final first = (projects.evaluate().first.widget.key! as ValueKey<String>).value;
  expect(first, 'project $name');
}

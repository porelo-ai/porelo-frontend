import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

/// Usage: the page {'Credentials'} of {'the build machine'} is open
///
/// A machine's section is a page under its own head: its path names the machine, its title the
/// section, so it is that machine's page and not another's.
Future<void> thePageOfIsOpen(WidgetTester tester, String page, String machine) async {
  final head = find.byType(PageHead);
  expect(head, findsOneWidget);
  final path = find.descendant(of: head, matching: find.byKey(ValueKey('machine-section-path $machine')));
  expect(path, findsOneWidget, reason: 'the page names $machine in its path');
  expect(find.descendant(of: path, matching: find.text(machine)), findsOneWidget);
  expect(tester.widget<PageHead>(head).title, page);
}

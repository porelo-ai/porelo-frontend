import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the name is marked as taken by {'this machine'}
Future<void> theNameIsMarkedAsTakenBy(WidgetTester tester, String machine) async {
  expect(find.text('Already taken'), findsOneWidget);
  final hover = find.byTooltip('A machine called $machine is already watched');
  expect(hover, findsOneWidget);
  expect(
    tester.widget<TooltipVisibility>(find.ancestor(of: hover, matching: find.byType(TooltipVisibility)).first).visible,
    isTrue,
  );
}

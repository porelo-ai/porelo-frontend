import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/operations.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningScreen;

/// Usage: the operation is in front of the board
///
/// The person sees it and can press on it, and the board beneath, still built, takes no keys and runs no animation.
Future<void> theOperationIsInFrontOfTheBoard(WidgetTester tester) async {
  expect(find.byType(OperationOutputView).hitTestable(), findsOneWidget, reason: 'nothing stands in front of it');
  final board = find.byType(PlanningScreen, skipOffstage: false);
  expect(board, findsOneWidget, reason: 'the board stays built beneath');
  expect(find.byType(PlanningScreen), findsNothing, reason: 'the board is not drawn beside it');
  final context = tester.element(board);
  expect(TickerMode.valuesOf(context).enabled, isFalse, reason: 'no animation runs beneath');
  final excluded = find.ancestor(of: board, matching: find.byType(ExcludeFocus, skipOffstage: false));
  expect(tester.widget<ExcludeFocus>(excluded.first).excluding, isTrue, reason: 'no key reaches the board beneath');
}

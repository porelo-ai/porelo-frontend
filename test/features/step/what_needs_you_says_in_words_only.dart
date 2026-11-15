import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart' show planningReasonWords;

/// Usage: what needs you says {'SAVE_REFUSED'} in words only
Future<void> whatNeedsYouSaysInWordsOnly(WidgetTester tester, String reason) async {
  expect(find.text(planningReasonWords(reason)), findsOneWidget, reason: 'the row says why once, in words');
  expect(find.text(reason), findsNothing, reason: 'a code meant for programs is no line a person reads');
}

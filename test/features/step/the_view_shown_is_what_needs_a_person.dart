import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';

/// Usage: the view shown is what needs a person
Future<void> theViewShownIsWhatNeedsAPerson(WidgetTester tester) async {
  expect(find.byType(AttentionView), findsOneWidget);
}

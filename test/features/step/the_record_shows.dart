import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/operations.dart';

/// Usage: the record shows {'Finished.'}
Future<void> theRecordShows(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byType(OperationsList), matching: find.textContaining(words)), findsOneWidget);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/operations.dart';

/// Usage: the operation is open
Future<void> theOperationIsOpen(WidgetTester tester) async {
  // Being told about something and then having to go and find it is most of the work done twice.
  expect(find.byType(OperationOutputView), findsOneWidget);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

import '../support/tiles.dart';

/// Usage: the list of work counts {4}
Future<void> theListOfWorkCounts(WidgetTester tester, int count) async {
  expect(find.byType(PageHead), findsOneWidget);
  expect(tester.widget<PageHead>(find.byType(PageHead)).title, 'Work');
  expect(workRows(), findsNWidgets(count));
}

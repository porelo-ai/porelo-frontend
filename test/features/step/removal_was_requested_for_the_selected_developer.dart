import 'package:flutter_test/flutter_test.dart';

import '../support/developer_settings.dart';

Future<void> removalWasRequestedForTheSelectedDeveloper(WidgetTester tester) async {
  expect(developerSettings.removals, ['alice']);
}

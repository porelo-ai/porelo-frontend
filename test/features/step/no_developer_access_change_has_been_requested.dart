import 'package:flutter_test/flutter_test.dart';

import '../support/developer_settings.dart';

Future<void> noDeveloperAccessChangeHasBeenRequested(WidgetTester tester) async {
  expect(developerSettings.removals, isEmpty, reason: 'host and forge removal require confirmation');
  expect(developerSettings.additions, isEmpty, reason: 'publication requires the reviewed developer');
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/developer_settings.dart';

Future<void> iCancelTheDeveloperRemoval(WidgetTester tester) async {
  await developerTap(tester, find.byKey(const Key('developers.remove-alice')));
  await developerTap(tester, find.text('Keep it'));
}

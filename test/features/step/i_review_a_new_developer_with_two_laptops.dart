import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/developer_settings.dart';
import '../support/world.dart';

Future<void> iReviewANewDeveloperWithTwoLaptops(WidgetTester tester) async {
  await developerLaptopStep(tester);
  expect(tester.widget<TextField>(find.byKey(const Key('developer-vpn-address'))).controller!.text, '10.77.0.3');
  await tester.enterText(find.byKey(const Key('developer-public-keys')), developerBlock);
  await developerTap(tester, find.byKey(const Key('developer-keep-laptop')));
  expect(tester.widget<TextField>(find.byKey(const Key('developer-vpn-address'))).controller!.text, '10.77.0.4');
  await tester.enterText(find.byKey(const Key('developer-public-keys')), developerBlock);
  await World.settle(tester);
  await developerTap(tester, find.byKey(const Key('wizard-next')));
  expect(find.textContaining('laptop-comment'), findsNothing);
}

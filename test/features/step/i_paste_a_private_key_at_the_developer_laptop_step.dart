import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/developer_settings.dart';
import '../support/world.dart';

Future<void> iPasteAPrivateKeyAtTheDeveloperLaptopStep(WidgetTester tester) async {
  await developerLaptopStep(tester);
  await tester.enterText(
    find.byKey(const Key('developer-public-keys')),
    '-----BEGIN OPENSSH PRIVATE KEY-----\nsensitive-fixture\n-----END OPENSSH PRIVATE KEY-----',
  );
  await World.settle(tester);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

Future<void> iCopyMyPublicKeysTwiceFor(WidgetTester tester, String host) async {
  await tester.enterText(find.byKey(const Key('join-keys-host')), host);
  for (var attempt = 0; attempt < 2; attempt++) {
    await tester.tap(find.byKey(const Key('join-keys-copy')));
    await World.settle(tester);
  }
}

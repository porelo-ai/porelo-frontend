import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I remove the signer {'porelo@old-box'}
Future<void> iRemoveTheSigner(WidgetTester tester, String principal) async {
  final remove = find.byKey(ValueKey<String>('remove-signer $principal'));
  await tester.ensureVisible(remove);
  await tester.tap(remove);
  await World.settle(tester);
}

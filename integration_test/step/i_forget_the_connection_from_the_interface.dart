import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I forget the connection {'https://e2e.invalid/'} from the interface
Future<void> iForgetTheConnectionFromTheInterface(WidgetTester tester, String match) async {
  final forget = find.byKey(ValueKey<String>('forget $match'));
  await pumpUntil(tester, () => forget.evaluate().isNotEmpty, what: 'the connection $match listed');
  await tester.ensureVisible(forget);
  await tester.tap(forget);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('connections-forgotten')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to say what forgetting did',
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I forget the connection {'https://e2e.invalid/'} from the interface
Future<void> iForgetTheConnectionFromTheInterface(WidgetTester tester, String match) async {
  final row = find.byKey(ValueKey<String>('connection $match'));
  await pumpUntil(tester, () => row.evaluate().isNotEmpty, what: 'the connection $match listed');
  await tapInTheConnectionsMenu(tester, 'forget $match');
  await pumpUntil(
    tester,
    () => find.byKey(const Key('connections-forgotten')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to say what forgetting did',
  );
}

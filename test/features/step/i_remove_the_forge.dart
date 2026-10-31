import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I remove the forge {'GitHub'}
Future<void> iRemoveTheForge(WidgetTester tester, String name) async {
  await expandListRows(tester);
  await World.settle(tester);
  await tester.tap(find.byKey(ValueKey<String>('forges-menu $name')).first);
  await World.settle(tester);
  await tester.tap(find.byKey(const ValueKey<String>('forge.remove')).last);
  await World.settle(tester);
}

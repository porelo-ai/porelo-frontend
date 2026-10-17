import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I choose to build {'what changed'}
Future<void> iChooseToBuild(WidgetTester tester, String depth) async {
  const named = <String, String>{'what changed': 'CACHED', 'the agent': 'AGENT', 'everything': 'EVERYTHING'};
  await tester.tap(find.byKey(Key('depth-${named[depth]}')));
  await World.settle(tester);
}

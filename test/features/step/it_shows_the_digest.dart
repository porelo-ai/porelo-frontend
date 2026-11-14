import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: it shows the digest {'3b1f…'}
Future<void> itShowsTheDigest(WidgetTester tester, String digest) async {
  // Copied whole: a digest is compared, never retyped, so the copy is the full one the machine checks against.
  expect(find.byKey(const Key('agent-artifact-digest')), findsWidgets);
  World.watchTheClipboard(tester);
  await tester.ensureVisible(find.byKey(const Key('agent-artifact-copy')).first);
  await tester.tap(find.byKey(const Key('agent-artifact-copy')).first);
  await tester.pump();
  expect(World.copied, <String>[digest]);
}

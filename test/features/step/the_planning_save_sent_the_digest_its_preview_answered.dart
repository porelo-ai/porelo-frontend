import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the planning save sent the digest its preview answered
Future<void> thePlanningSaveSentTheDigestItsPreviewAnswered(WidgetTester tester) async {
  // A save sent without a preview, or with a digest of its own, makes this fail.
  final previews = World.planning.previewCalls;
  final saves = World.planning.moveCalls;
  expect(previews, hasLength(1));
  expect(saves, hasLength(1));
  expect(saves.single['moves'], previews.single['moves']);
  expect(saves.single['revision'], previews.single['revision']);
  expect(saves.single['digest'], matches(RegExp(r'^[0-9a-f]{64}$')));
  expect(saves.single['confirm'], isFalse, reason: 'a move with no warning is saved unconfirmed');
}

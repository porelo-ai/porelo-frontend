import 'package:flutter_test/flutter_test.dart';

import '../support/story_work.dart';
import '../support/world.dart';

/// Usage: I drop story {story} on working state {state}
Future<void> iDropStoryOnWorkingState(WidgetTester tester, String story, String state) async {
  final card = workKey('planning-card $story');
  await tester.ensureVisible(card);
  final gesture = await tester.startGesture(tester.getCenter(card));
  final target = workKey('planning-drop $state');
  await gesture.moveBy(const Offset(1, 0));
  await tester.ensureVisible(target);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  await gesture.up();
  await World.settle(tester);
}

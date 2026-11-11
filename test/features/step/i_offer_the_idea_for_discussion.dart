import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I offer the idea {idea} for discussion
Future<void> iOfferTheIdeaForDiscussion(WidgetTester tester, String idea) async {
  await tester.tap(find.byKey(const Key('planning-board-menu')).first);
  await World.settle(tester);
  await tester.tap(find.byKey(const ValueKey<String>('planning-discuss-idea')).last);
  await World.settle(tester);
  await tester.enterText(find.byKey(const Key('planning-idea-words')), idea);
  // Discuss is offered once the dialog has seen the words.
  await tester.pump();
  await tester.tap(find.byKey(const Key('planning-idea-discuss')));
  await World.settle(tester);
}

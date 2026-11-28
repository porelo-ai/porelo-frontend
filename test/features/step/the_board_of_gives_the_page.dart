import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the board of {'checkout'} gives {'cart-move'} the page {'https://example.org/stories/cart-move'}
///
/// Puts the story on the board with that page, so whatever names the story can link to it.
Future<void> theBoardOfGivesThePage(WidgetTester tester, String project, String story, String page) async {
  World.planning.addStory(project, story, page);
  await World.settle(tester);
}

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forge holds {'porelo vm api/api'} at {'acme/api'} once
Future<void> theForgeHoldsAtOnce(WidgetTester tester, String title, String repository) async {
  expect(World.forge.keysOf[repository]!.where((each) => each.title == title), hasLength(1));
}

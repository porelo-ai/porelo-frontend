import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forge holds {'porelo vm api/backend'} at {'acme/backend'}, with write access
Future<void> theForgeHoldsAtWithWriteAccess(WidgetTester tester, String title, String repository) async {
  expect(World.forge.keysOf[repository]!.singleWhere((each) => each.title == title).readOnly, isFalse);
}

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forge takes the key {'SHA256:personalKeyOfThePerson'}
Future<void> theForgeTakesTheKey(WidgetTester tester, String key) async {
  World.backend.keysTheForgeTakes.add(key);
}

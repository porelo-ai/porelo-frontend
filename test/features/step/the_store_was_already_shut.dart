import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the store was already shut
Future<void> theStoreWasAlreadyShut(WidgetTester tester) async {
  World.backend.nextLock = const Locked(keyring: true, wasCached: false, holding: 0);
}

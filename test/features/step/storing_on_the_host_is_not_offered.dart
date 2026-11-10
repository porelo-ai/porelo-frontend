import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: storing {'host-builds'} on the host is not offered
Future<void> storingOnTheHostIsNotOffered(WidgetTester tester, String credential) async {
  expect(find.byKey(ValueKey<String>('store-missing builds $credential')), findsNothing);
  expect(World.terminals, isEmpty, reason: 'nothing ran on this computer');
}

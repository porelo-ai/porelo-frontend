import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I use my person identity
Future<void> iUseMyPersonIdentity(WidgetTester tester) async {
  await World.tapInView(tester, 'use-person-identity');
}

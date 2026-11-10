import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_store_the_credential_from_the_start.dart';

/// Usage: I store {'host-builds'} on the host from the start
Future<void> iStoreOnTheHostFromTheStart(WidgetTester tester, String credential) async {
  askedBeforeStoring = World.backend.canStartAsked;
  await World.tapInView(tester, 'store-missing $credential');
}

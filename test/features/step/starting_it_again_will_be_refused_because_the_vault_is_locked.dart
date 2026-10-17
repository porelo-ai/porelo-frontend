import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: starting it again will be refused because the vault is locked
Future<void> startingItAgainWillBeRefusedBecauseTheVaultIsLocked(WidgetTester tester) async {
  World.backend.nextStart = const StartProgress(action: StartAction.needsVault);
}

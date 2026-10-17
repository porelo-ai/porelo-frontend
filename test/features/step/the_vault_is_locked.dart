import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the vault is locked
Future<void> theVaultIsLocked(WidgetTester tester) async {
  World.backend.nextReadiness = const Readiness(
    ready: false,
    outcome: StartOutcome.vaultLocked,
    agent: 'an-agent',
    provider: 'a-provider',
    credential: 'a-provider',
    detail: 'the vault is locked, so nothing can say what it holds',
  );
}

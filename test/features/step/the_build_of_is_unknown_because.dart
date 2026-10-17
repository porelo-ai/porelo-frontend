import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} is unknown because {'the vault is shut'}
Future<void> theBuildOfIsUnknownBecause(WidgetTester tester, String commit, String detail) async {
  World.backend.followBuilds('porelo-checkout-shell',
      builds: <Build>[Build(commit: commit, verdict: 'unknown', detail: detail)]);
  await World.settle(tester);
}

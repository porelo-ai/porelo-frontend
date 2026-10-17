import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} is {'running'}
Future<void> theBuildOfIs(WidgetTester tester, String commit, String verdict) async {
  World.backend.followBuilds(
    'porelo-checkout-shell',
    builds: <Build>[Build(commit: commit, verdict: verdict, since: '2026-10-06T13:00:00Z')],
  );
  await World.settle(tester);
}

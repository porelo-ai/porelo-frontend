import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} passed in {'Shared rules check / check'} alone
Future<void> theBuildOfPassedInAlone(WidgetTester tester, String commit, String job) async {
  // As the machine answers when the forge has run one workflow of the commit and not yet the others.
  World.backend.followBuilds(
    'porelo-checkout-shell',
    builds: <Build>[
      Build(
        commit: commit,
        verdict: 'success',
        since: '2026-10-06T13:05:00Z',
        jobs: <BuildJob>[BuildJob(name: job, result: 'success')],
      ),
    ],
  );
  await World.settle(tester);
}

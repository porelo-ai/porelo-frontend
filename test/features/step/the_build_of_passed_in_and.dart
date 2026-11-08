import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} passed in {'Build / unit tests'} and {'Shared rules check / check'}
Future<void> theBuildOfPassedInAnd(WidgetTester tester, String commit, String first, String second) async {
  World.backend.followBuilds(
    'porelo-checkout-shell',
    builds: <Build>[
      Build(
        commit: commit,
        verdict: 'success',
        since: '2026-10-06T13:05:00Z',
        jobs: <BuildJob>[
          BuildJob(name: first, result: 'success'),
          BuildJob(name: second, result: 'success'),
        ],
      ),
    ],
  );
  await World.settle(tester);
}

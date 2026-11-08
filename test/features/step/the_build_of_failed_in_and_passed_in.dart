import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} failed in {'Build / unit tests'} and passed in {'Shared rules check / check'}
Future<void> theBuildOfFailedInAndPassedIn(WidgetTester tester, String commit, String failed, String passed) async {
  final short = commit.substring(0, 12);
  World.backend.followBuilds(
    'porelo-checkout-shell',
    builds: <Build>[
      Build(
        commit: commit,
        verdict: 'failure',
        since: '2026-10-06T13:05:00Z',
        jobs: <BuildJob>[
          BuildJob(name: failed, result: 'failure', log: 'build-$short-1.log'),
          BuildJob(name: passed, result: 'success'),
        ],
      ),
    ],
  );
  await World.settle(tester);
}

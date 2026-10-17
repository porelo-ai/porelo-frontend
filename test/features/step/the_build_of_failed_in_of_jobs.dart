import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} failed in {'Build / unit tests'} of {3} jobs
Future<void> theBuildOfFailedInOfJobs(WidgetTester tester, String commit, String failed, num jobs) async {
  // With the project's default, only the failed job's log reaches the task, as the machine names it.
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
          for (var n = 2; n <= jobs; n++) BuildJob(name: 'Job $n', result: 'success'),
        ],
      ),
    ],
  );
  await World.settle(tester);
}

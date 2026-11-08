import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} passed in {'Build / unit tests'} while the run {'Acceptance'} is {'in_progress'}
Future<void> theBuildOfPassedInWhileTheRunIs(
  WidgetTester tester,
  String commit,
  String job,
  String run,
  String result,
) async {
  World.backend.followBuilds(
    'porelo-checkout-shell',
    builds: <Build>[
      Build(
        commit: commit,
        verdict: 'success',
        since: '2026-10-06T13:05:00Z',
        jobs: <BuildJob>[BuildJob(name: job, result: 'success')],
        runs: <BuildRun>[
          BuildRun(name: job.split(' / ').first, result: 'success'),
          BuildRun(name: run, result: result),
        ],
      ),
    ],
  );
  await World.settle(tester);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the build of {'0123456789abcdef0123'} ran the workflow {'Build'} twice as {'failure'} and {'success'}
Future<void> theBuildOfRanTheWorkflowTwiceAsAnd(
  WidgetTester tester,
  String commit,
  String workflow,
  String first,
  String second,
) async {
  World.backend.followBuilds(
    'porelo-checkout-shell',
    builds: <Build>[
      Build(
        commit: commit,
        verdict: 'failure',
        since: '2026-10-06T13:05:00Z',
        runs: <BuildRun>[
          BuildRun(name: workflow, result: first),
          BuildRun(name: workflow, result: second),
        ],
      ),
    ],
  );
  await World.settle(tester);
}

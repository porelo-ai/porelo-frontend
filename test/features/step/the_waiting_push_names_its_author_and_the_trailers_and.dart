import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the waiting push names its author {'An Agent'} and the trailers {'Assisted-by: Claude Code claude-opus-5-5'} and {'Co-Authored-By: Claude'}
Future<void> theWaitingPushNamesItsAuthorAndTheTrailersAnd(
  WidgetTester tester,
  String author,
  String first,
  String second,
) async {
  // As `Pending` answers it: the head commit's author and trailer, and no committer.
  final head = World.backend.theGate.pending.first;
  World.backend.theGate = GateState.from(<String, dynamic>{
    'mirror': World.backend.theGate.mirror,
    'mode': World.backend.theGate.mode,
    'seededFrom': World.backend.theGate.seededFrom,
    'pending': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': head.name,
        'commit': head.commit,
        'subject': head.subject,
        'waiting': head.waiting,
        'at': head.at,
        'fetch': head.fetch,
        'author': '$author <agent@example.org>',
        'trailers': <String>[first, second],
      },
    ],
  });
}

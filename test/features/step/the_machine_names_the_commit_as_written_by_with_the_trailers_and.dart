import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine names the commit as written by {'An Agent'} with the trailers {'Assisted-by: Claude Code claude-opus-5-5'} and {'Co-Authored-By: Claude'}
Future<void> theMachineNamesTheCommitAsWrittenByWithTheTrailersAnd(
  WidgetTester tester,
  String author,
  String first,
  String second,
) async {
  // The waiting push's own head commit, as `Review` lists it with who made it.
  final head = World.backend.theGate.pending.first;
  World.backend.theCommits = <ReviewCommit>[
    ReviewCommit(
      commit: head.commit,
      subject: head.subject,
      author: '$author <agent@example.org>',
      committer: 'A Person <person@example.org>',
      trailers: <String>[first, second],
      // As git keeps it: the trailer lines are the message's last block.
      message: '${head.subject}\n\n$first\n$second\n',
    ),
  ];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine ranks the waiting push with a CI definition, the change and a generated file
Future<void> theMachineRanksTheWaitingPushWithACiDefinitionTheChangeAndAGeneratedFile(WidgetTester tester) async {
  // In the machine's order, as Review answers it: dangerous first, the volume last.
  World.backend.theRanking = const <ReviewFile>[
    ReviewFile(
      path: '.github/workflows/ci.yml',
      status: 'M',
      added: 1,
      removed: 0,
      rank: 'DANGEROUS',
      reason: 'a CI definition, which runs with the credentials of CI',
    ),
    ReviewFile(path: 'lib/money.dart', status: 'M', added: 1, removed: 1, rank: 'ORDINARY', reason: ''),
    ReviewFile(
      path: 'lib/money.g.dart',
      status: 'M',
      added: 40,
      removed: 38,
      rank: 'GENERATED',
      reason: 'generated: it says so in its header',
    ),
  ];
}

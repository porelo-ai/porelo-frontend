import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/following.dart';

/// Usage: the history of {'checkout'} was rewritten
Future<void> theHistoryOfWasRewritten(WidgetTester tester, String name) => theProjectFollows(
  tester,
  name,
  Followed(
    name: name,
    url: 'git@example.org:$name.git',
    commit: '4f2a9c1e0b77',
    outcome: 'REWRITTEN',
    refused: 'b71d03aa9e2c',
    detail: 'b71d03aa9e2c is signed and is not a descendant of 4f2a9c1e0b77, which is in force',
    needsAPerson: true,
  ),
);

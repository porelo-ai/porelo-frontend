import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/following.dart';

/// Usage: the repository of {'checkout'} cannot be reached for now
Future<void> theRepositoryOfCannotBeReachedForNow(WidgetTester tester, String name) =>
    theProjectFollows(
      tester,
      name,
      Followed(
        name: name,
        url: 'git@example.org:$name.git',
        commit: '4f2a9c1e0b77',
        outcome: 'UNREACHABLE',
        detail: 'connection timed out',
      ),
    );

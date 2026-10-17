import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/following.dart';

/// Usage: the repository of {'checkout'} needs a credential from a shut store
Future<void> theRepositoryOfNeedsACredentialFromAShutStore(WidgetTester tester, String name) =>
    theProjectFollows(
      tester,
      name,
      Followed(
        name: name,
        url: 'git@example.org:$name.git',
        commit: '4f2a9c1e0b77',
        outcome: 'VAULT_LOCKED',
        needsAPerson: true,
      ),
    );

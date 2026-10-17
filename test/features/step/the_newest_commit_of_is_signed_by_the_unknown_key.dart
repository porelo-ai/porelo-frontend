import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/following.dart';

/// Usage: the newest commit of {'checkout'} is signed by the unknown key {'SHA256:9xQeTbL1'}
Future<void> theNewestCommitOfIsSignedByTheUnknownKey(
        WidgetTester tester, String name, String signer) =>
    theProjectFollows(
      tester,
      name,
      Followed(
        name: name,
        url: 'git@example.org:$name.git',
        commit: '4f2a9c1e0b77',
        outcome: 'UNKNOWN_KEY',
        refused: 'b71d03aa9e2c',
        signer: signer,
        detail: 'a good signature by a key that is not pinned here',
        needsAPerson: true,
      ),
    );

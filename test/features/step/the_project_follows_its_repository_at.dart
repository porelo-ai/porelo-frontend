import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/following.dart';

/// Usage: the project {'checkout'} follows its repository at {'4f2a9c1e0b77'}
Future<void> theProjectFollowsItsRepositoryAt(WidgetTester tester, String name, String commit) => theProjectFollows(
  tester,
  name,
  Followed(name: name, url: 'git@example.org:$name.git', commit: commit, outcome: 'APPLIED'),
);

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/following.dart';

/// Usage: the machine follows the project {'api'} from {'git@github.com:acme/api.git'}
Future<void> theMachineFollowsTheProjectFrom(WidgetTester tester, String name, String url) =>
    theProjectFollows(tester, name, Followed(name: name, url: url, commit: 'c0ffee1d2e3f', outcome: 'APPLIED'));

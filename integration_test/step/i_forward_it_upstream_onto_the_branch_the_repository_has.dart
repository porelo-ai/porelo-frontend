import 'package:flutter_test/flutter_test.dart';

import '../support/forwarding.dart';
import '../support/rehearsal.dart';

/// Usage: I forward it upstream onto the branch the repository has
Future<void> iForwardItUpstreamOntoTheBranchTheRepositoryHas(WidgetTester tester) =>
    pictured(tester, () => forwardUpstream(tester, Forwarding.existing, typed: false));

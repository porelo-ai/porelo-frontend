import 'package:flutter_test/flutter_test.dart';

import '../support/forwarding.dart';
import '../support/rehearsal.dart';

/// Usage: I forward it upstream onto a new branch I type
Future<void> iForwardItUpstreamOntoANewBranchIType(WidgetTester tester) => pictured(tester, () async {
  expect(await theHeadAtGitHub(Forwarding.typed), isNull, reason: 'GitHub has no ${Forwarding.typed} before');
  await forwardUpstream(tester, Forwarding.typed, typed: true);
});

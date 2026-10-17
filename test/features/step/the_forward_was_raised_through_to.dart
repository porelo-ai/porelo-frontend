import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forward was raised through {'porelo-the-build-machine'} to {'/run/user/1001/porelo/porelod.sock'}
Future<void> theForwardWasRaisedThroughTo(WidgetTester tester, String alias, String socket) async {
  // Through the Host entry, so as the work user with the wizard's key — never as root.
  final command = World.forwardsAsked.last;
  expect(command.last, alias);
  expect(command.join(' '), contains(':$socket'));
  expect(command.join(' '), isNot(contains('root@')));
}

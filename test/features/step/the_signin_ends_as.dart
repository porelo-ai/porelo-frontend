import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the sign-in ends as {'SIGNED_IN'}
///
/// The final reply of the wait asked last, or `cut`: the connection gone before it.
Future<void> theSigninEndsAs(WidgetTester tester, String end) async {
  final backend = World.backend;
  final waiting = backend.signInWait;
  expect(waiting, isNotNull, reason: 'nothing waits on a sign-in');
  final agent = backend.signInWaits.last;
  if (end == 'cut') {
    waiting!.addError(const VarlinkDisconnected('the stream ended without a final reply'));
  } else {
    backend.signInOf[agent] = AgentSignIn(agent: agent, provider: 'a-provider', state: end);
    waiting!.add(SignInWaited(state: end));
  }
  // Not waited on: a wait the window left has no listener to deliver the end to.
  unawaited(waiting.close());
  await World.settle(tester);
}

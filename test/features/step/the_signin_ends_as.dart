import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the sign-in ends as {'SIGNED_IN'}
///
/// `SIGNED_IN` ends it stored; `cut` ends the wait with a lost connection; anything else ends it not stored, with
/// that as its reason.
Future<void> theSigninEndsAs(WidgetTester tester, String end) async {
  final backend = World.backend;
  final waiting = backend.signInWait;
  expect(waiting, isNotNull, reason: 'nothing waits on a sign-in');
  final agent = backend.signInWaits.last;
  if (end == 'cut') {
    waiting!.addError(const VarlinkDisconnected('the connection closed before the call was answered'));
  } else {
    final stored = end == 'SIGNED_IN';
    backend.signInOf[agent] = AgentSignIn(
      agent: agent,
      state: stored
          ? 'SIGNED_IN'
          : (const <String>{'VAULT_LOCKED', 'CANNOT_SAY'}.contains(end) ? end : 'NOT_SIGNED_IN'),
    );
    waiting!.add(SignInWaited(stored: stored, reason: stored ? '' : end));
  }
  // Not waited on: a wait the window left has no listener to deliver the end to.
  unawaited(waiting.close());
  await World.settle(tester);
}

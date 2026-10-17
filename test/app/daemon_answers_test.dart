import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

/// Asking whether a WSL distribution's daemon answers, before it is connected to.
///
/// The harm: a daemon that accepted and never answered left the connection open each time it was
/// asked, a relay process and a socket per look.
void main() {
  test('a daemon that never answers is said as not answering, and its connection is closed', () async {
    final incoming = StreamController<List<int>>();
    final outgoing = StreamController<List<int>>();
    addTearDown(() async {
      await incoming.close();
      await outgoing.close();
    });
    outgoing.stream.listen((_) {});
    var closed = 0;

    final answered = await Machines.daemonAnswers(
      const Machine(name: 'ubuntu', socketPath: '', kind: 'wsl', distribution: 'Ubuntu'),
      within: const Duration(milliseconds: 50),
      open: () async =>
          VarlinkConnection.over(incoming: incoming.stream, outgoing: outgoing.sink, destroy: () => closed++),
    );

    expect(answered, isFalse);
    expect(closed, 1);
  });
}

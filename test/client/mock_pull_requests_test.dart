// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The stand-in's host forge pull request and its done task, over a real socket, as the window is shown them.
void main() {
  late MockDaemon daemon;
  late MockMachine machine;

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  Future<void> machineIn(String situation) async {
    daemon = MockDaemon();
    await daemon.start();
    machine = MockMachine(daemon, situation: situation, pace: Duration.zero);
    addTearDown(() async {
      await machine.close();
      await daemon.stop();
    });
  }

  // Harm: the window cannot be shown a pull request that waits for a merge and then ends, or a task that said done,
  // so neither is ever seen working before a real host.
  test('one pull request of a carried project waits, and ends when it is merged; a task said done', () async {
    await machineIn('pull-request');
    final client = await connect();
    final checkout = (await client.projects()).firstWhere((project) => project.name == 'checkout');
    expect(checkout.repositoryStates.where((each) => each.carriedHere == true).map((each) => each.name), <String>[
      'checkout',
    ]);
    expect((await client.pullRequests('checkout')).open.single.number, 1);

    final seen = <PullRequestsSeen>[];
    final watching = client.watchPullRequests('checkout').listen(seen.add);
    addTearDown(watching.cancel);
    await _until(() => seen.isNotEmpty);
    final open = seen.single.open.single;
    expect(open.repository, 'checkout');
    expect(open.trailers, isNotNull);

    machine.mergePullRequest();
    await _until(() => seen.length == 2);
    expect(seen.last.open, isEmpty);
    expect(seen.last.ended.single.number, 1);
    expect(seen.last.ended.single.state, 'merged');
    expect((await client.pullRequests('checkout')).open, isEmpty);

    expect((await client.tasks()).where((task) => task.activity == Activity.done), hasLength(1));
  });

  // Harm: every other situation shows a pull request nobody asked for.
  test('another situation has none open', () async {
    await machineIn('work');
    expect((await (await connect()).pullRequests('checkout')).open, isEmpty);
  });
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

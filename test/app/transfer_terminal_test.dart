import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/project_transfers.dart';
import 'package:porelo_frontend/src/app/transfer_terminal.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/transfer_selection.dart';

class _Channel extends SessionChannel {
  final outputController = StreamController<List<int>>();
  final exit = Completer<int>();
  bool closed = false;
  @override
  Stream<List<int>> get output => outputController.stream;
  @override
  Future<int> get ended => exit.future;
  @override
  Future<void> close() async {
    closed = true;
    if (!exit.isCompleted) exit.complete(129);
  }

  @override
  void send(String input) => throw UnimplementedError();
  @override
  void resize({required int columns, required int rows}) {}
}

void main() {
  // Harm: local validation or a failed pty spawn is treated as a submitted host write.
  test('a missing secrets file or a failed terminal spawn never marks submission', () async {
    for (final file in [null, '/data/secrets.kdbx']) {
      var submitted = false;
      final runner = TransferTerminal(
        secretsFile: file,
        openTerminal: (_, _, {columns = 80, rows = 24}) => throw StateError('local launch failure'),
      );
      await expectLater(
        runner.run(
          selection(),
          ProjectTransfer.push,
          onSubmitted: () {
            submitted = true;
          },
        ),
        throwsA(anything),
      );
      expect(submitted, isFalse);
    }
  });

  // Harm: the application marks a write submitted before local checks, or exposes private shell channels.
  test('a started terminal stays pending and only public host output reaches progress', () async {
    final child = _Channel();
    final commands = <List<String>>[];
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (exe, args, {columns = 80, rows = 24}) {
        commands.add([exe, ...args]);
        return child;
      },
    );
    var submits = 0;
    final lines = <String>[];
    final pending = runner.run(
      selection(),
      ProjectTransfer.pull,
      onSubmitted: () {
        submits++;
      },
      onLine: lines.add,
    );
    expect(submits, 0);
    child.outputController.add(utf8.encode('$projectTransferSubmitted\r\n${projectTransferOutput}host refusal\r\n'));
    await child.outputController.close();
    child.exit.complete(65);
    expect((await pending).exitCode, 65);
    expect(submits, 1);
    expect(lines, ['host refusal']);
    expect(child.closed, isTrue);
    expect(commands.single.last, contains('porelo-host-push --pull example api'));
  });

  // Harm: lost output before confirmed submission blocks a transfer that never started.
  test('losing the terminal before its submission marker stays retryable', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (_, _, {columns = 80, rows = 24}) => child,
    );
    final transfers = ProjectTransfers(source: runner);
    addTearDown(transfers.dispose);
    final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    child.outputController.addError(StateError('lost output'));
    final answer = await pending;
    expect(answer.state, TransferState.unavailable);
    expect(transfers.unavailable(selection()), isNull);
    expect(child.closed, isTrue);
    await child.outputController.close();
    if (!child.exit.isCompleted) child.exit.complete(255);
  });

  // Harm: echoed or private terminal output becomes retained progress or answer text.
  test('only script-marked public lines reach progress', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (_, _, {columns = 80, rows = 24}) => child,
    );
    final lines = <String>[];
    final pending = runner.run(selection(), ProjectTransfer.push, onSubmitted: () {}, onLine: lines.add);
    child.outputController.add(
      utf8.encode(
        'unmarked terminal input\n'
        '$projectTransferSubmitted\n'
        '${projectTransferOutput}host answer\n'
        'unmarked after submission\n',
      ),
    );
    await child.outputController.close();
    child.exit.complete(0);
    await pending;
    expect(lines, ['host answer']);
  });

  // Harm: child exec failures and canceled prompts block a project that never sent anything.
  test('a terminal ending without submission remains retryable', () async {
    for (final code in [1, 126, 127, 129, 130, 143]) {
      final child = _Channel();
      final runner = TransferTerminal(
        secretsFile: '/data/secrets.kdbx',
        openTerminal: (_, _, {columns = 80, rows = 24}) => child,
      );
      final transfers = ProjectTransfers(source: runner);
      addTearDown(transfers.dispose);
      final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
      await child.outputController.close();
      child.exit.complete(code);
      expect((await pending).state, TransferState.unavailable);
      expect(transfers.unavailable(selection()), isNull);
    }
  });

  // Harm: an unresponsive child leaves the terminal future and project busy forever.
  testWidgets('terminal cleanup has a bound when the child never reports exit', (tester) async {
    final child = _HungChannel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      deadline: const Duration(seconds: 1),
      openTerminal: (_, _, {columns = 80, rows = 24}) => child,
    );
    var done = false;
    final pending = runner
        .run(selection(), ProjectTransfer.push, onSubmitted: () {})
        .then<void>(
          (_) {
            done = true;
          },
          onError: (Object _) {
            done = true;
          },
        );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
    expect(done, isTrue);
    await pending;
    unawaited(child.outputController.close());
  });

  // Harm: a hung child leaves submission stuck after the controller deadline.
  testWidgets('bounded terminal cleanup permits reconciliation after a lost submitted result', (tester) async {
    final child = _HungChannel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      deadline: const Duration(seconds: 1),
      openTerminal: (_, _, {columns = 80, rows = 24}) => child,
    );
    final transfers = ProjectTransfers(source: runner, answerWithin: const Duration(seconds: 2));
    addTearDown(transfers.dispose);
    final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    child.outputController.add(utf8.encode('$projectTransferSubmitted\n'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect((await pending).state, TransferState.unconfirmed);
    await expectLater(transfers.reconcile(selection(), () async {}), throwsStateError);
    await tester.pump(const Duration(seconds: 2));
    await transfers.reconcile(selection(), () async {});
    expect(transfers.unavailable(selection()), isNull);
    unawaited(child.outputController.close());
  });

  // Harm: a rendering Error leaves the owned terminal and SSH process running.
  test('a progress Error closes its owned terminal', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (_, _, {columns = 80, rows = 24}) => child,
    );
    final pending = runner.run(
      selection(),
      ProjectTransfer.push,
      onSubmitted: () {},
      onLine: (_) => throw StateError('render'),
    );
    final checked = expectLater(pending, throwsStateError);
    child.outputController.add(utf8.encode('$projectTransferSubmitted\n${projectTransferOutput}public\n'));
    await checked;
    expect(child.closed, isTrue);
    await child.outputController.close();
    if (!child.exit.isCompleted) child.exit.complete(0);
  });
}

class _HungChannel extends _Channel {
  @override
  Future<void> close() async {
    closed = true;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/project_transfers.dart';
import 'package:porelo_frontend/src/app/transfer_terminal.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/transfer_selection.dart';

class _Channel extends DrainingSessionChannel {
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
    unawaited(outputController.close());
  }

  @override
  Future<void> terminate() => close();

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
        openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => throw StateError('local launch failure'),
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
      openTerminal: (exe, args, {columns = 80, rows = 24, echo = true}) {
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

  // Harm: a read error hides a submitted marker and permits a duplicate transfer.
  test('losing terminal output leaves submission uncertain', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
    );
    final transfers = ProjectTransfers(source: runner);
    addTearDown(transfers.dispose);
    final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    child.outputController.addError(StateError('lost output'));
    final answer = await pending;
    expect(answer.state, TransferState.unconfirmed);
    expect(transfers.unavailable(selection()), isNotNull);
    expect(child.closed, isTrue);
    await child.outputController.close();
    if (!child.exit.isCompleted) child.exit.complete(255);
  });

  // Harm: echoed or private terminal output becomes retained progress or answer text.
  test('only script-marked public lines reach progress', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
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
        openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
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

  // Harm: a deadline discards a queued submission and permits the host write twice.
  test('deadline drains submission until both the child and output end', () async {
    final child = _HungChannel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      deadline: Duration.zero,
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
    );
    final transfers = ProjectTransfers(source: runner);
    addTearDown(transfers.dispose);
    var done = false;
    final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {}).then((answer) {
      done = true;
      return answer;
    });
    await child.closing.future;
    expect(child.closed, isTrue, reason: 'stop the child before draining its output');
    child.outputController.add(utf8.encode(projectTransferSubmitted.substring(0, 10)));
    child.exit.complete(129);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse, reason: 'an exit code does not mean buffered output has drained');
    child.outputController.add(utf8.encode('${projectTransferSubmitted.substring(10)}\n'));
    await child.outputController.close();
    expect((await pending).state, TransferState.unconfirmed);
    expect(transfers.unavailable(selection()), isNotNull, reason: 'a submitted write must never become retryable');
    await transfers.reconcile(selection(), () async {});
    expect(transfers.unavailable(selection()), isNull);
  });

  // Harm: a canceled password prompt is called submitted although SSH never started.
  test('a deadline before submission returns a confirmed not-sent result', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      deadline: Duration.zero,
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
    );
    var submits = 0;
    final result = await runner.run(selection(), ProjectTransfer.push, onSubmitted: () => submits++);
    expect(child.closed, isTrue);
    expect(result.notSubmitted, isTrue);
    expect(submits, 0);
  });

  // Harm: a failed drain hides a possible submission and permits a duplicate write.
  test('a drain failure without a marker blocks replay', () async {
    final child = _FailedDrainChannel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      deadline: Duration.zero,
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
    );
    final transfers = ProjectTransfers(source: runner);
    addTearDown(transfers.dispose);
    final result = await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    expect(result.state, TransferState.unconfirmed);
    expect(transfers.unavailable(selection()), isNotNull);
    expect(
      (await transfers.start(selection(), ProjectTransfer.push, refresh: () async {})).state,
      TransferState.unavailable,
    );
  });

  // Harm: a reader that never finishes loses evidence of submission and permits replay.
  test('a drain bound without EOF leaves the transfer unconfirmed', () async {
    for (final code in <int?>[137, -1, null]) {
      final child = _HungChannel();
      final runner = TransferTerminal(
        secretsFile: '/data/secrets.kdbx',
        deadline: Duration.zero,
        drainWithin: Duration.zero,
        openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
      );
      addTearDown(() async {
        if (!child.exit.isCompleted) child.exit.complete(137);
        await child.outputController.close();
      });
      final transfers = ProjectTransfers(source: runner);
      addTearDown(transfers.dispose);
      final answer = await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
      expect(child.closed, isTrue);
      expect(answer.state, TransferState.unconfirmed);
      expect(transfers.unavailable(selection()), isNotNull);
      await expectLater(transfers.reconcile(selection(), () async {}), throwsStateError);
      if (code == null) {
        child.exit.completeError(StateError('unknown exit'));
      } else {
        child.exit.complete(code);
      }
      await Future<void>.delayed(Duration.zero);
      if (code == null || code < 0) {
        await expectLater(transfers.reconcile(selection(), () async {}), throwsStateError);
      } else {
        await transfers.reconcile(selection(), () async {});
        expect(transfers.unavailable(selection()), isNull);
      }
    }
  });

  // Harm: an unknown child status is taken as proof that SSH can no longer start.
  test('EOF with an unknown child exit stays unconfirmed', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
    );
    final transfers = ProjectTransfers(source: runner);
    addTearDown(transfers.dispose);
    final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    await child.outputController.close();
    child.exit.complete(-1);
    expect((await pending).state, TransferState.unconfirmed);
    await expectLater(transfers.reconcile(selection(), () async {}), throwsStateError);
  });

  // Harm: a rendering error hides an incomplete termination and allows a second write.
  test('a callback error cannot release the pending child guard after a drain bound', () async {
    final child = _HungChannel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      drainWithin: Duration.zero,
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
    );
    addTearDown(() async {
      child.exit.complete(137);
      await child.outputController.close();
    });
    final transfers = ProjectTransfers(source: runner);
    addTearDown(transfers.dispose);
    final pending = transfers.start(
      selection(),
      ProjectTransfer.push,
      refresh: () async {},
      onProgress: (_) => throw StateError('render'),
    );
    child.outputController.add(utf8.encode('$projectTransferSubmitted\n${projectTransferOutput}public\n'));
    expect((await pending).state, TransferState.unconfirmed);
    await expectLater(transfers.reconcile(selection(), () async {}), throwsStateError);
  });

  // Harm: entering a password after the deadline starts a transfer declared not sent.
  test(
    'a deadline kills a real password prompt before its SSH step',
    () async {
      late Pty child;
      final prompt = Completer<void>();
      final raw = StringBuffer();
      final runner = TransferTerminal(
        secretsFile: '/data/secrets.kdbx',
        deadline: const Duration(seconds: 1),
        openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) {
          child = Pty.start('/bin/sh', [
            '-c',
            "printf 'password prompt\\n'; read line; printf '%s\\n' '$projectTransferSubmitted'",
          ], echo: echo);
          child.output.transform(utf8.decoder).listen((text) {
            raw.write(text);
            if (!prompt.isCompleted && raw.toString().contains('password prompt')) prompt.complete();
          });
          return child;
        },
      );
      final transfers = ProjectTransfers(source: runner);
      addTearDown(transfers.dispose);
      final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
      await prompt.future.timeout(const Duration(seconds: 5));
      final answer = await pending;
      child.send('late input\n');
      expect(await child.ended, 137);
      expect(raw.toString(), isNot(contains(projectTransferSubmitted)));
      expect(answer.state, TransferState.unavailable);
      expect(transfers.unavailable(selection()), isNull);
    },
    tags: ['linux'],
    skip: !Platform.isLinux,
  ); // Linux: real PTY and shell waiting for terminal input.

  // Harm: typing before the terminal script starts echoes a password into the interface.
  test(
    'a transfer PTY suppresses input before the child can disable echo',
    () async {
      final raw = StringBuffer();
      final lines = <String>[];
      final runner = TransferTerminal(
        secretsFile: '/data/secrets.kdbx',
        openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) {
          final child = Pty.start('/bin/sh', [
            '-c',
            "IFS= read -r early; stty -echo; printf '%s\\n' '${projectTransferOutput}accepted'",
          ], echo: echo);
          child.output.transform(utf8.decoder).listen(raw.write);
          child.send('synthetic early input\n');
          return child;
        },
      );
      final answer = await runner.run(selection(), ProjectTransfer.push, onSubmitted: () {}, onLine: lines.add);
      expect(answer.exitCode, 0);
      expect(lines, ['accepted']);
      expect(
        raw.toString().contains('synthetic early input'),
        isFalse,
        reason: 'kernel echo must be off before the child reads any input',
      );
    },
    tags: ['linux'],
    skip: !Platform.isLinux,
  ); // Linux: real PTY, shell and stty.

  // Harm: a rendering Error leaves the owned terminal and SSH process running.
  test('a progress Error closes its owned terminal', () async {
    final child = _Channel();
    final runner = TransferTerminal(
      secretsFile: '/data/secrets.kdbx',
      openTerminal: (_, _, {columns = 80, rows = 24, echo = true}) => child,
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
  final closing = Completer<void>();
  @override
  Future<void> close() async {
    closed = true;
    if (!closing.isCompleted) closing.complete();
  }
}

class _FailedDrainChannel extends _Channel {
  @override
  Future<void> terminate() async {
    await close();
    throw TimeoutException('reader did not drain');
  }
}

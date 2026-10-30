import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/project_transfers.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/transfer_selection.dart';

class _Terminal implements CentralTransferSource {
  final selections = <TransferSelection>[];
  final commands = <String>[];
  Object? before;
  Object? after;
  Completer<void>? prepare;
  Completer<void>? work;
  int code = 0;
  String words = 'approved main pushed';

  @override
  Future<TransferResult> run(
    TransferSelection selection,
    ProjectTransfer direction, {
    required void Function() onSubmitted,
    void Function(String)? onLine,
  }) async {
    selections.add(selection);
    if (before case final failure?) throw failure;
    await prepare?.future;
    onSubmitted();
    commands.add(projectTransferCommand(direction, selection.project, selection.repositories));
    await work?.future;
    if (after case final failure?) throw failure;
    onLine?.call(words);
    return TransferResult(code, code == 0 ? '' : 'host refused changed main');
  }
}

void main() {
  late _Terminal terminal;
  late ProjectTransfers transfers;
  setUp(() {
    terminal = _Terminal();
    transfers = ProjectTransfers(source: terminal);
  });
  tearDown(() {
    transfers.dispose();
    roles = const Roles();
  });

  // Harm: viewing a page or changing UI roles starts a central write or changes its target.
  test('only an explicit admitted action runs the captured host and repository command', () async {
    final repos = ['api'];
    final chosen = selection(repositories: repos);
    final commands = projectTransferCommands(transfers: transfers, selection: chosen, start: (_) {});
    expect(commands.every((command) => command.visible && command.available), isTrue);
    expect(terminal.selections, isEmpty);
    roles = Roles.fromArguments(const ['--roles', 'host-admin']);
    expect(commands.every((command) => command.visible), isTrue);
    repos[0] = 'other';
    var refreshed = 0;
    final answer = await transfers.start(
      chosen,
      ProjectTransfer.push,
      refresh: () async {
        refreshed++;
      },
    );
    expect(answer.state, TransferState.completed);
    expect(answer.words, terminal.words);
    expect(terminal.selections, [chosen]);
    expect(terminal.commands.single, 'exec "\${SHELL:-/bin/sh}" -lc \'porelo-host-push example api\'');
    expect(refreshed, 1);
  });

  // Harm: denied admission or another person's identity starts a central write.
  test('denied admission and a mismatched current person start no terminal', () async {
    for (final denied in [selection(allowed: false), selection(person: 'bob')]) {
      var starts = 0;
      final commands = projectTransferCommands(
        transfers: transfers,
        selection: denied,
        start: (_) {
          starts++;
        },
      );
      commands.first.run();
      expect(starts, 0);
      expect(commands.every((command) => !command.available), isTrue);
      expect(
        (await transfers.start(denied, ProjectTransfer.pull, refresh: () async {})).state,
        TransferState.unavailable,
      );
    }
    expect(terminal.selections, isEmpty);
  });

  // Harm: invalid public selections become host options or request credentials from an unnamed forge.
  test('missing forge and invalid project or repository names are unavailable before execution', () async {
    for (final chosen in [
      selection(forge: ''),
      selection(project: '../bad'),
      for (final bad in ['--check', '../api', 'api;touch file', 'a\nb']) selection(repositories: [bad]),
    ]) {
      expect(transfers.unavailable(chosen), isNotNull);
      expect(
        (await transfers.start(chosen, ProjectTransfer.push, refresh: () async {})).state,
        TransferState.unavailable,
      );
    }
    expect(terminal.selections, isEmpty);
  });

  // Harm: local validation, spawn failures or Errors lock retries although no host command started.
  test('all failures before submission remain sanitized and retryable', () async {
    for (final failure in [const FormatException('config'), const RemoteNotStarted(), UnimplementedError('private')]) {
      terminal.before = failure;
      final answer = await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
      expect(answer.state, TransferState.unavailable);
      expect(answer.words, isNot(contains('private')));
      expect(transfers.unavailable(selection()), isNull);
    }
    expect(terminal.commands, isEmpty);
    terminal.before = null;
    expect(
      (await transfers.start(selection(), ProjectTransfer.push, refresh: () async {})).state,
      TransferState.completed,
    );
  });

  // Harm: a missing local token is treated as a host operation or as success.
  test('a local terminal refusal is unavailable without blocking a retry', () async {
    final local = _LocalRefusal();
    transfers.dispose();
    transfers = ProjectTransfers(source: local);
    final answer = await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    expect(answer.state, TransferState.unavailable);
    expect(answer.words, 'The secrets file has no central token.');
    expect(transfers.unavailable(selection()), isNull);
  });

  // Harm: a late local preparation starts a transfer after the person has received a timeout.
  testWidgets('a preparation deadline prevents late submission and permits retry', (tester) async {
    transfers.dispose();
    transfers = ProjectTransfers(source: terminal, answerWithin: const Duration(seconds: 1));
    terminal.prepare = Completer<void>();
    final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    await tester.pump(const Duration(seconds: 1));
    expect((await pending).state, TransferState.unavailable);
    terminal.prepare!.complete();
    await tester.pump();
    expect(terminal.commands, isEmpty);
    expect(transfers.unavailable(selection()), isNull);
  });

  // Harm: duplicate explicit starts can push or pull the project twice.
  test('pending preparation blocks duplicate starts and captures pull selection', () async {
    terminal.prepare = Completer<void>();
    final chosen = selection();
    final pending = transfers.start(chosen, ProjectTransfer.pull, refresh: () async {});
    expect(
      (await transfers.start(chosen, ProjectTransfer.push, refresh: () async {})).state,
      TransferState.unavailable,
    );
    terminal.prepare!.complete();
    await pending;
    expect(terminal.selections, [chosen]);
    expect(terminal.commands.single, contains('porelo-host-push --pull example api'));
    expect(transfers.unavailable(chosen), isNull);
  });

  // Harm: a host refusal is mistaken for success or an uncertain write is silently replayed.
  test('refusal retains host words and loss needs a successful explicit reconciliation', () async {
    terminal.code = 65;
    var refreshes = 0;
    final chosen = selection();
    final refused = await transfers.start(
      chosen,
      ProjectTransfer.push,
      refresh: () async {
        refreshes++;
      },
    );
    expect(refused.state, TransferState.refused);
    expect(refused.words, contains('host refused changed main'));
    expect(refreshes, 0);
    terminal.code = 255;
    expect(
      (await transfers.start(chosen, ProjectTransfer.push, refresh: () async {})).state,
      TransferState.unconfirmed,
    );
    await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(terminal.commands.length, 2);
    await expectLater(
      transfers.reconcile(chosen, () async {
        throw StateError('unreadable');
      }),
      throwsStateError,
    );
    expect(transfers.unavailable(chosen), isNotNull);
    await transfers.reconcile(chosen, () async {});
    expect(transfers.unavailable(chosen), isNull);
  });

  // Harm: a local timeout is reconciled while the original host operation can still write.
  testWidgets('a timed out submission cannot be reconciled until it settles', (tester) async {
    transfers.dispose();
    transfers = ProjectTransfers(source: terminal, answerWithin: const Duration(seconds: 1));
    terminal.work = Completer<void>();
    final chosen = selection();
    final pending = transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect((await pending).state, TransferState.unconfirmed);
    await expectLater(transfers.reconcile(chosen, () async {}), throwsStateError);
    await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(terminal.commands.length, 1);
    terminal.work!.complete();
    await tester.pump();
    await transfers.reconcile(chosen, () async {});
    expect(transfers.unavailable(chosen), isNull);
  });

  // Harm: an Error after submission or in progress rendering allows replay or wedges the busy guard.
  test('post-submission errors stay uncertain and release busy state for reconciliation', () async {
    for (final callbackFails in [false, true]) {
      terminal.after = callbackFails ? null : StateError('private provider details');
      final chosen = selection();
      final answer = await transfers.start(
        chosen,
        ProjectTransfer.push,
        refresh: () async {},
        onProgress: callbackFails ? (_) => throw ArgumentError('private callback details') : null,
      );
      expect(answer.state, TransferState.unconfirmed);
      expect(answer.words, isNot(contains('private')));
      final calls = terminal.commands.length;
      await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
      expect(terminal.commands.length, calls);
      await transfers.reconcile(chosen, () async {});
      expect(transfers.unavailable(chosen), isNull);
    }
  });

  // Harm: a killed local SSH process is mistaken for a confirmed host refusal.
  test('negative and signal-derived exits stay unconfirmed and block replay', () async {
    for (final code in [-9, 129, 137, 143]) {
      terminal.code = code;
      final before = terminal.commands.length;
      final answer = await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
      expect(answer.state, TransferState.unconfirmed, reason: 'signal exit $code cannot confirm a host refusal');
      await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
      expect(terminal.commands.length, before + 1);
      await transfers.reconcile(selection(), () async {});
    }
  });
}

class _LocalRefusal implements CentralTransferSource {
  @override
  Future<TransferResult> run(
    TransferSelection selection,
    ProjectTransfer direction, {
    required void Function() onSubmitted,
    void Function(String)? onLine,
  }) async => const TransferResult(1, 'The secrets file has no central token.', notSubmitted: true);
}

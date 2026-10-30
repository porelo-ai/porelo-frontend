import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/project_transfers.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/transfer_selection.dart';

class _Vault implements CentralCredentialSource {
  final selections = <TransferSelection>[];
  bool failAfterUse = false;
  bool locked = false;
  String? supplied;
  String get token => String.fromCharCodes([115, 121, 110, 116, 104, 101, 116, 105, 99]);
  Completer<void>? wait;
  @override
  Future<T> withCredential<T>(TransferSelection selection, Future<T> Function(String) use) async {
    selections.add(selection);
    if (locked) throw const CentralCredentialUnavailable();
    await wait?.future;
    final answer = await use(supplied ?? token);
    if (failAfterUse) throw Exception('vault cleanup failed');
    return answer;
  }
}

class _Remote implements Remote {
  final requests = <({String host, String user, String command, String? input})>[];
  int code = 0;
  bool lost = false;
  Completer<void>? wait;
  String words = 'approved main pushed';
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    requests.add((host: host, user: user, command: command, input: input));
    await wait?.future;
    if (lost) throw Exception('transport lost');
    onLine?.call(words);
    return RemoteResult(code, code == 0 ? '' : 'host refused changed main');
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) => throw UnimplementedError();
}

void main() {
  late _Vault vault;
  late _Remote remote;
  late ProjectTransfers transfers;
  setUp(() {
    vault = _Vault();
    remote = _Remote();
    transfers = ProjectTransfers(credentials: vault, remoteFor: (_) => remote);
  });
  tearDown(() {
    transfers.dispose();
    roles = const Roles();
  });

  // Harm: opening a page, or a role switch, can send work without verified admission.
  test('only an explicit admitted action consumes a credential and runs the captured host command', () async {
    final repos = ['api'];
    final chosen = selection(repositories: repos);
    final commands = projectTransferCommands(transfers: transfers, selection: chosen, start: (_) {});
    expect(commands.every((command) => command.visible && command.available), isTrue);
    expect(vault.selections, isEmpty);
    expect(remote.requests, isEmpty);
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
    expect(answer.words, remote.words);
    expect(vault.selections, [chosen]);
    expect(remote.requests.single, (
      host: 'alpha',
      user: '',
      command: 'exec "\${SHELL:-/bin/sh}" -lc \'porelo-host-push example api\'',
      input: '${vault.token}\n',
    ));
    expect(refreshed, 1);
  });

  // Harm: denied admission or another person's identity can start a central write.
  test('denied admission and a mismatched current person start neither vault delivery nor SSH', () async {
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
      final answer = await transfers.start(denied, ProjectTransfer.pull, refresh: () async {});
      expect(answer.state, TransferState.unavailable);
    }
    expect(vault.selections, isEmpty);
    expect(remote.requests, isEmpty);
  });

  // Harm: a locked vault starts a tokenless host operation or exposes a secret input form.
  test('a locked or missing credential stops before host execution', () async {
    vault.locked = true;
    final answer = await transfers.start(selection(), ProjectTransfer.pull, refresh: () async {});
    expect(answer.state, TransferState.unavailable);
    expect(remote.requests, isEmpty);
  });

  // Harm: an empty or malformed credential starts an unintended tokenless command.
  test('empty and multiline vault credentials are refused before SSH', () async {
    for (final token in ['', 'line\nbreak', 'two words', 'bad\x00value']) {
      vault.supplied = token;
      final answer = await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
      expect(answer.state, TransferState.unavailable);
    }
    expect(remote.requests, isEmpty);
  });

  // Harm: a late vault response starts a transfer after its request timed out.
  testWidgets('a credential deadline prevents late delivery from starting SSH', (tester) async {
    transfers.dispose();
    transfers = ProjectTransfers(
      credentials: vault,
      remoteFor: (_) => remote,
      answerWithin: const Duration(seconds: 1),
    );
    vault.wait = Completer<void>();
    final pending = transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    await tester.pump(const Duration(seconds: 1));
    expect((await pending).state, TransferState.unavailable);
    vault.wait!.complete();
    await tester.pump();
    expect(remote.requests, isEmpty);
    expect(transfers.unavailable(selection()), isNull);
  });

  // Harm: duplicate starts or automatic replay can write the central state twice.
  test('a pending delivery blocks duplicate starts and captures pull selections', () async {
    vault.wait = Completer<void>();
    final chosen = selection();
    final pending = transfers.start(chosen, ProjectTransfer.pull, refresh: () async {});
    final duplicate = await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(duplicate.state, TransferState.unavailable);
    vault.wait!.complete();
    await pending;
    expect(vault.selections.length, 1);
    expect(remote.requests.single.command, contains('porelo-host-push --pull example api'));
    expect(transfers.unavailable(chosen), isNull);
  });

  // Harm: a refusal is misreported as success, or an uncertain write is silently replayed.
  test('refusal preserves host words and loss blocks retry until successful reconciliation', () async {
    remote.code = 65;
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
    remote.code = 255;
    final lost = await transfers.start(
      chosen,
      ProjectTransfer.push,
      refresh: () async {
        refreshes++;
      },
    );
    expect(lost.state, TransferState.unconfirmed);
    await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(remote.requests.length, 2);
    await expectLater(
      transfers.reconcile(chosen, () async {
        throw StateError('unreadable');
      }),
      throwsStateError,
    );
    expect(transfers.unavailable(chosen), isNotNull);
    await transfers.reconcile(chosen, () async {});
    expect(transfers.unavailable(chosen), isNull);
    expect(refreshes, 0);
  });

  // Harm: a transport exception or a hostile echoed response exposes the token.
  test('echoes and lost exceptions cannot disclose credentials', () async {
    remote.words = vault.token;
    final progress = <String>[];
    final answer = await transfers.start(
      selection(),
      ProjectTransfer.push,
      refresh: () async {},
      onProgress: progress.add,
    );
    expect(answer.words.contains(vault.token), isFalse);
    expect(progress, ['[redacted]']);
    remote.lost = true;
    final lost = await transfers.start(selection(), ProjectTransfer.push, refresh: () async {});
    expect(lost.state, TransferState.unconfirmed);
    expect(lost.words.contains(vault.token), isFalse);
  });

  // Harm: a local timeout is reconciled while the original host command can still write.
  testWidgets('a timed out submission cannot be reconciled while its command is still pending', (tester) async {
    transfers.dispose();
    transfers = ProjectTransfers(
      credentials: vault,
      remoteFor: (_) => remote,
      answerWithin: const Duration(seconds: 1),
    );
    remote.wait = Completer<void>();
    final chosen = selection();
    final pending = transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect((await pending).state, TransferState.unconfirmed);
    await expectLater(transfers.reconcile(chosen, () async {}), throwsA(isA<StateError>()));
    await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(remote.requests.length, 1);
    remote.wait!.complete();
    await tester.pump();
    await transfers.reconcile(chosen, () async {});
    expect(transfers.unavailable(chosen), isNull);
  });

  // Harm: a delivery provider failure after submission invites a duplicate write.
  test('credential cleanup failure after submission keeps the transfer uncertain', () async {
    vault.failAfterUse = true;
    final chosen = selection();
    final answer = await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(answer.state, TransferState.unconfirmed);
    await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(remote.requests.length, 1);
  });

  // Harm: a killed local SSH process is mistaken for a confirmed host refusal.
  test('a killed SSH client leaves an unconfirmed transfer and blocks replay', () async {
    remote.code = -9;
    final chosen = selection();
    final answer = await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(answer.state, TransferState.unconfirmed);
    expect(answer.words, contains('unconfirmed'));
    await transfers.start(chosen, ProjectTransfer.push, refresh: () async {});
    expect(remote.requests.length, 1);
  });

  // Harm: an untrusted selection becomes a host option or shell command.
  test('option names and paths are refused before credential delivery', () async {
    for (final bad in ['--check', '../api', 'api;touch file', 'a\nb']) {
      await expectLater(
        transfers.start(selection(repositories: [bad]), ProjectTransfer.push, refresh: () async {}),
        throwsFormatException,
      );
    }
    expect(vault.selections, isEmpty);
    expect(remote.requests, isEmpty);
  });
}

@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/vault_unlock.dart';

/// Which line opens or makes a machine's vault: a rented server's from the secrets file, any other's typed, and asked
/// again after a refused passphrase.
void main() {
  const server = Machine(
    name: 'checkout server',
    socketPath: '',
    kind: 'host',
    host: 'porelo@203.0.113.7',
    remoteSocket: '/run/user/1001/porelo/porelo.sock',
    hostProject: 'checkout',
  );
  const other = Machine(
    name: 'build',
    socketPath: '',
    host: 'person@198.51.100.2',
    remoteSocket: '/run/user/1000/porelo/porelo.sock',
  );

  // Harm: the person copying a passphrase this interface made and kept in the file, by hand.
  test('a rented server\'s vault opens from the secrets file, with the master password typed once', () {
    final line = unlockCommandFor(server, secretsFile: '/home/person/Porelo/secrets.kdbx')!;
    expect(line.first, '/usr/bin/env');
    expect(line.last, contains("'hosts/checkout/vault-passphrase'"));
    expect(line.last, contains("'/usr/bin/porelo vault unlock --passphrase-stdin'"));
  });

  test('without a secrets file, or for another machine, the passphrase is typed at the machine as before', () {
    expect(unlockCommandFor(server)!.last, contains('porelo vault unlock'));
    expect(unlockCommandFor(server)!.last, isNot(contains('--passphrase-stdin')));
    expect(
      unlockCommandFor(other, secretsFile: '/home/person/Porelo/secrets.kdbx')!.last,
      isNot(contains('--passphrase-stdin')),
    );
  });

  // Harm: a server's vault made with a passphrase the file never learns, which its setup then cannot open.
  test('a rented server\'s vault is never made here; another machine\'s is', () {
    expect(makeCommandFor(server), isNull);
    expect(makeCommandFor(other), isNotNull);
  });

  group('a refused passphrase', () {
    late Directory scratch;
    late File calls;

    setUp(() {
      scratch = Directory.systemTemp.createTempSync('vault-unlock-');
      calls = File('${scratch.path}/calls');
    });
    tearDown(() => scratch.deleteSync(recursive: true));

    Future<ProcessResult> unlock(List<int> exits) async {
      for (var i = 0; i < exits.length; i++) {
        File('${scratch.path}/exit-${i + 1}').writeAsStringSync('${exits[i]}');
      }
      final porelo = File('${scratch.path}/porelo')
        ..writeAsStringSync(r'''#!/bin/sh
  [ "$#" -eq 2 ] && [ "$1" = vault ] && [ "$2" = unlock ] || exit 64
  printf 'unlock\n' >> "$UNLOCK_CALLS"
  attempt=$(wc -l < "$UNLOCK_CALLS")
  code=$(cat "$UNLOCK_EXITS/exit-$attempt") || exit 65
  exit "$code"
  ''');
      expect((await Process.run('chmod', ['700', porelo.path])).exitCode, 0);
      final command = unlockCommandFor(Machine.local(environment: const {}))!;
      return Process.run(
        command.first,
        command.skip(1).toList(),
        environment: {
          'PATH': '${scratch.path}:/usr/bin:/bin',
          'UNLOCK_CALLS': calls.path,
          'UNLOCK_EXITS': scratch.path,
        },
      );
    }

    // Harm: one mistyped entry ends the terminal instead of allowing the vault to open.
    test('a refused passphrase followed by an accepted one opens on the second attempt', () async {
      final result = await unlock([70, 0]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(calls.readAsLinesSync(), ['unlock', 'unlock']);
    });

    // Harm: repeated refusals keep prompting without a bound or falsely report success.
    test('three refused passphrases end with the refusal and no fourth attempt', () async {
      final result = await unlock([70, 70, 70, 0]);
      expect(result.exitCode, 70);
      expect(calls.readAsLinesSync(), ['unlock', 'unlock', 'unlock']);
      expect('${result.stdout}${result.stderr}', contains('The passphrase was refused three times.'));
    });

    // Harm: retrying another failure repeats a command that cannot be repaired by a passphrase.
    for (final code in [0, 1, 64, 130, 255]) {
      test('exit $code ends at once with its own status', () async {
        final result = await unlock([code, 0]);
        expect(result.exitCode, code);
        expect(calls.readAsLinesSync(), ['unlock']);
        expect('${result.stdout}${result.stderr}', isNot(contains('refused')));
      });
    }

    test('ssh runs the same unlock command in a terminal on the machine', () {
      const machine = Machine(
        name: 'remote',
        socketPath: '/tmp/remote.sock',
        host: 'alice@vm',
        remoteSocket: '/run/porelo.sock',
      );
      final local = unlockCommandFor(Machine.local(environment: const {}))!;
      expect(unlockCommandFor(machine), [
        'ssh',
        '-t',
        'alice@vm',
        inTheLoginShell(local.map(quoteForAShell).join(' ')),
      ]);
    });

    test('a forwarded socket cannot unlock a vault on this computer', () {
      expect(unlockCommandFor(const Machine(name: 'forwarded', socketPath: '/tmp/forwarded.sock')), isNull);
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart' show HostIdentity;
import 'package:porelo_frontend/src/app/host_identity_export.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_host/porelo_host.dart' show poreloHostCommand;
import 'package:porelo_host/porelo_host.dart' as host show HostCardSsh;

import '../support/host_process.dart';

const _machine = Machine(name: 'orchard', socketPath: '', kind: 'host', host: '203.0.113.7', hostProject: 'orchard');

/// What the host's `identity export` prints; its private halves are stand-ins a test looks for.
final _exported = jsonEncode(<String, Object?>{
  'host': 'orchard',
  'organization': {'public': 'ssh-ed25519 AAAAorganization', 'private': 'SECRET-ORGANIZATION'},
  'repositories': const <Object>[],
  'ssh_host_keys': [
    {'type': 'ed25519', 'public': 'ssh-ed25519 AAAAhost', 'private': 'SECRET-HOST'},
  ],
});

void main() {
  late List<List<String>> started;
  late HostProcess process;

  setUp(() {
    started = [];
    process = HostProcess();
  });

  Future<HostIdentity> export({Duration limit = const Duration(seconds: 30)}) => exportHostIdentity(
    _machine,
    hostName: 'orchard',
    limit: limit,
    start: (program, arguments) async {
      started.add([program, ...arguments]);
      return process;
    },
  );

  // Harm: the identity is read through a login that is not the pinned root one, or reaches a file or an argument.
  test('reads the host identity as root over the pinned connection, in memory', () async {
    final exporting = export();
    process
      ..raw(_exported)
      ..end(0);
    final identity = await exporting;
    expect(identity.host, 'orchard');
    expect(jsonDecode(identity.json), jsonDecode(_exported));
    final command = started.single;
    expect(command, containsAllInOrder(['root@203.0.113.7', poreloHostCommand('identity export')]));
    expect(command, contains('BatchMode=yes'));
    expect(command.join(' '), isNot(contains('SECRET')));
  });

  // Harm: a host that prints without end fills this computer's memory, or one that hangs holds a give-back for ever.
  test('more than 256 KiB, or more than its limit, ends the read and refuses it', () async {
    final big = export();
    process.raw('x' * (256 * 1024 + 1));
    await expectLater(big, throwsA(isA<HostIdentityExportRefused>()));
    expect(process.killed, isTrue);

    process = HostProcess();
    final slow = export(limit: const Duration(milliseconds: 50));
    await expectLater(
      slow,
      throwsA(isA<HostIdentityExportRefused>().having((refused) => refused.words, 'words', contains('did not answer'))),
    );
    expect(process.killed, isTrue);
    process.end(143);
  });

  // Harm: a window that closed leaves its export's ssh and its limit's timer running behind it.
  test('an export the window ends stops at once, its process and its timer with it', () async {
    final closed = Completer<void>();
    final exporting = exportHostIdentity(
      _machine,
      hostName: 'orchard',
      cancelled: closed.future,
      start: (_, _) async => process,
    );
    await Future<void>.delayed(Duration.zero);
    closed.complete();
    await expectLater(exporting, throwsA(isA<HostIdentityExportRefused>()));
    expect(process.killed, isTrue);
    process.end(143);
  });

  // Harm: a hand-on to a host this computer holds no SSH configuration for starts an ssh that can reach nothing.
  test('a card host whose configuration is not here starts no ssh', () async {
    final card = Machine(
      name: 'build',
      socketPath: '',
      kind: 'host',
      host: 'build',
      hostCard: host.HostCardSsh(
        name: 'build',
        address: '203.0.113.9',
        sshPort: 22,
        hostKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl',
        login: 'hana',
        publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl',
      ),
    );
    await expectLater(exportHostIdentity(card, hostName: 'build'), throwsA(isA<HostIdentityExportRefused>()));
  });

  // Harm: a refusal says the identity, or another host's identity is kept under this one's name.
  for (final (name, out, code, said) in <(String, String, int, String)>[
    ('a refusal', '', 1, 'the vault on the host is shut'),
    ('another host', _exported.replaceFirst('"orchard"', '"lemon"'), 0, 'not the identity of orchard'),
    ('no JSON', 'SECRET-HOST', 0, 'not an identity'),
    ('a missing porelo-host', '', 127, 'not installed'),
  ]) {
    test('$name is refused, in words that never hold what the host printed', () async {
      final exporting = export();
      process
        ..raw(out)
        ..words('the vault on the host is shut')
        ..end(code);
      await expectLater(
        exporting,
        throwsA(
          isA<HostIdentityExportRefused>().having(
            (refused) => refused.words,
            'words',
            allOf(contains(said), isNot(contains('SECRET'))),
          ),
        ),
      );
    });
  }

  // Harm: the host's own refusal, printed just before it ended, is lost, or a byte that is no UTF-8 breaks the read
  // with an error nobody catches.
  for (final (name, said, expected) in <(String, List<int>, String)>[
    ('a refusal said as it ends', utf8.encode('the vault on the host is shut\n'), 'the vault on the host is shut'),
    ('a byte that is no text', [0x76, 0x61, 0xff, 0x75, 0x6c, 0x74, 0x0a], 'did not give its identity'),
  ]) {
    test('$name is kept as the refusal', () async {
      final late = _LateWords(said);
      final exporting = exportHostIdentity(_machine, hostName: 'orchard', start: (_, _) async => late);
      await expectLater(
        exporting,
        throwsA(isA<HostIdentityExportRefused>().having((refused) => refused.words, 'words', contains(expected))),
      );
    });
  }
}

/// A host command that has ended before its last words reach this computer.
class _LateWords extends Fake implements Process {
  _LateWords(this.said);

  final List<int> said;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>()..stream.listen((_) {}));
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr async* {
    // Later than the two seconds an ended command's output was once given, so only waiting for its words keeps them.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    yield said;
  }

  @override
  Future<int> get exitCode async => 1;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
  @override
  int get pid => 0;
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/host_access_adapters.dart';
import 'package:porelo_frontend/src/app/host_access_contract.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import '../support/host_registry.dart';

/// Core's `identity show --json` answer for alice, whose card key the agent holds.
Map<String, Object?> _shown({bool revoked = false, String? cardRefused, String agent = 'holds'}) => {
  'login': 'alice',
  'name': 'Alice',
  'email': 'alice@example.org',
  'fingerprint': adminFingerprint,
  'key': hostKey,
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "alice"\n',
  'agent': agent,
  'agent_holds_key': agent == 'holds',
  'revoked': revoked,
  'card_refused': cardRefused,
  'registry': <Object?>[],
  'forge': null,
  'pending': <Object?>[],
};

/// One process run, as the fake runner saw it.
typedef _Call = ({String program, List<String> arguments, Map<String, String> environment, List<int>? input});

/// A proof whose next reads answer what the test says.
class _Proof implements HostAdminProof {
  HostAdminIdentity? next = const HostAdminIdentity('alice', adminFingerprint);
  HostAdminIdentity? current;
  int reads = 0;

  @override
  Future<void> readAgain() async {
    reads++;
    current = next;
  }

  @override
  String? get whyNone => current == null ? 'Your key is revoked.' : null;
}

void main() {
  // Harm: a binary bundle reaches the host re-encoded as text, so the host refuses or misreads it.
  test('a program run with bytes gets them on stdin unchanged', () async {
    final bytes = [for (var each = 0; each < 256; each++) each];
    final blob = sha1.convert([...utf8.encode('blob ${bytes.length}\x00'), ...bytes]).toString();
    final ran = await runHereWithBytes('git', ['hash-object', '--stdin'], input: bytes);
    expect(ran.code, 0, reason: ran.err);
    expect(ran.out.trim(), blob);
  });

  group('the proven identity', () {
    late List<List<String>> asked;
    late Ran answer;
    late CoreHostAdminProof proof;
    setUp(() {
      asked = [];
      answer = (code: 0, out: jsonEncode(_shown()), err: '');
      proof = CoreHostAdminProof(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async {
          asked.add([program, ...arguments]);
          return answer;
        },
      );
    });

    // Harm: the host admin's right is taken from anything but Core's proven card.
    test('a usable card proves its login and fingerprint, read from Core', () async {
      await proof.readAgain();
      expect(asked, [
        ['porelo', 'identity', 'show', '--json'],
      ]);
      expect(proof.current()?.login, 'alice');
      expect(proof.current()?.fingerprint, adminFingerprint);
      expect(proof.whyNone, isNull);
    });

    // Harm: a revoked key, a refused card or a key the agent does not hold acts as a host admin.
    for (final (name, unusable) in [
      ('a revoked key', (code: 0, out: jsonEncode(_shown(revoked: true)), err: '')),
      ('a refused card', (code: 0, out: jsonEncode(_shown(cardRefused: 'bad signature')), err: '')),
      ('a key the agent does not hold', (code: 0, out: jsonEncode(_shown(agent: 'not-held')), err: '')),
      ('no card', (code: 65, out: jsonEncode({'reason': 'no-identity', 'words': 'No card is kept.'}), err: '')),
      ('an unreadable answer', (code: 0, out: 'not json', err: '')),
    ]) {
      test('$name proves nobody, even after a usable read, and says why', () async {
        await proof.readAgain();
        expect(proof.current(), isNotNull);
        answer = unusable;
        await proof.readAgain();
        expect(proof.current(), isNull);
        expect(proof.whyNone, isNotEmpty);
      });
    }
  });

  group('host access with a proof', () {
    late RegistryFixture fixture;
    late Settings settings;
    late _Proof proof;
    late HostAccess access;
    setUp(() async {
      fixture = RegistryFixture();
      settings = Settings(MemorySettingsStore());
      addTearDown(settings.dispose);
      await fixture.access(settings);
      addTearDown(fixture.registry.dispose);
      proof = _Proof();
      await proof.readAgain();
      access = HostAccess(
        registry: () => fixture.registry,
        settings: settings,
        identity: () => proof.current,
        proof: proof,
        transport: fixture,
      );
    });

    // Harm: a key revoked or taken out of the agent after the last read still files and delivers a host change.
    test('a side effect reads the identity again first, and a key unusable now changes nothing', () async {
      expect(access.unavailable('orchard'), isNull);
      proof.next = null;
      await expectLater(
        access.admit(
          host: 'orchard',
          person: 'bob',
          project: 'demo',
          accessRepository: 'git@example.org:team/demo-access.git',
        ),
        throwsA(isA<RegistryRefusal>().having((refused) => refused.words, 'words', contains('revoked'))),
      );
      expect(fixture.calls, isEmpty);
      expect(fixture.changes, isEmpty);
      expect(settings.hostRegistry('orchard'), isNull);
    });

    // Harm: before an address is chosen a change crashes, or is judged on another registry.
    test('without a chosen registry nothing is offered or filed', () async {
      final none = HostAccess(
        registry: () => null,
        settings: settings,
        identity: () => proof.current,
        proof: proof,
        transport: fixture,
      );
      expect(none.unavailable('orchard'), HostAccess.noRegistry);
      expect(none.notOnHostYet('orchard'), isFalse);
      await expectLater(
        none.admit(
          host: 'orchard',
          person: 'bob',
          project: 'demo',
          accessRepository: 'git@example.org:team/demo-access.git',
        ),
        throwsA(isA<RegistryRefusal>()),
      );
      expect(fixture.calls, isEmpty);
    });
  });

  group('the SSH registry transport', () {
    late RegistryFixture fixture;
    late Settings settings;
    late Directory home;
    late Map<String, String> environment;
    late String scratch;
    late List<_Call> calls;
    late List<Machine> watched;
    late Ran verified;
    late Ran taken;
    late int gitFails;
    late bool bundleSeenAtSend;
    late SshHostRegistryTransport transport;
    final bundleBytes = [0, 1, 2, 255, 254, 10, 13, 0x80];
    late String config;

    setUp(() async {
      fixture = RegistryFixture()
        ..hostCard = {
          'host': 'orchard',
          'address': '203.0.113.7',
          'ssh_port': 22,
          'ssh_host_key': hostKey,
          'services': {
            'forge': {'web_port': 3000, 'git_port': 3001},
            'matrix': {'port': 8448},
          },
          'signed_by': adminFingerprint,
        };
      settings = Settings(MemorySettingsStore());
      addTearDown(settings.dispose);
      await fixture.access(settings);
      addTearDown(fixture.registry.dispose);
      home = await Directory.systemTemp.createTemp('host-transport-');
      addTearDown(() => home.delete(recursive: true));
      environment = {'XDG_CONFIG_HOME': path.join(home.path, 'config'), 'APPDATA': path.join(home.path, 'config')};
      scratch = path.join(home.path, 'scratch');
      final card = HostCardSsh(
        name: 'orchard',
        address: '203.0.113.7',
        sshPort: 22,
        hostKey: hostKey,
        login: 'alice',
        publicKey: hostKey,
        webPort: 3000,
        gitPort: 3001,
        matrixPort: 8448,
      );
      config = card.configPath(environment: environment, windows: desk.isWindows);
      watched = [Machine.fromHostCard(card, socketPath: path.join(home.path, 'orchard.sock'), sshConfig: config)];
      calls = [];
      gitFails = 0;
      bundleSeenAtSend = false;
      verified = (
        code: 0,
        out: jsonEncode({
          'commit': registryAfter,
          'host_card': {'host': 'orchard', 'signed_by': adminFingerprint},
          'admins': <String, Object?>{},
          'projects': <Object?>[],
          'persons': <Object?>[],
        }),
        err: '',
      );
      taken = (
        code: 0,
        out:
            '${jsonEncode({'commit': registryAfter, 'pinned': adminFingerprint, 'projects': <String>[], 'dropped': <String>[], 'revoked': <String>[], 'refused': <String>[], 'unchanged': false})}\n',
        err: '',
      );
      transport = SshHostRegistryTransport(
        registry: () => fixture.registry,
        machines: () => watched,
        settings: settings,
        scratch: scratch,
        environment: environment,
        run: (program, arguments, {inDirectory, environment = const {}, input}) async {
          calls.add((program: program, arguments: arguments, environment: environment, input: null));
          if (program == 'git') {
            if (gitFails > 0 && arguments.contains('update-ref')) return (code: 128, out: '', err: 'nonexistent');
            if (arguments.contains('bundle')) {
              await File(arguments[arguments.indexOf('--quiet') + 1]).writeAsBytes(bundleBytes);
            }
            return (code: 0, out: '', err: '');
          }
          return verified;
        },
        send: (program, arguments, {required input}) async {
          calls.add((program: program, arguments: arguments, environment: const {}, input: input));
          bundleSeenAtSend = await Directory(scratch).list().length == 1;
          return taken;
        },
      );
    });

    Future<List<FileSystemEntity>> leftOver() async =>
        await Directory(scratch).exists() ? await Directory(scratch).list().toList() : const [];

    // Harm: another state than the exact revision reaches root, or reaches it unverified, through ambient SSH settings.
    test(
      'upload bundles the exact revision, has Core verify it, and gives it to root through the card config',
      () async {
        await transport.upload('orchard', registryAfter);

        final objects = path.join(fixture.folder, '.git', 'objects');
        const clean = {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0'};
        expect(calls, hasLength(5));
        final repository = calls[0].arguments.last;
        final folder = path.dirname(repository);
        expect(path.dirname(folder), scratch);
        final bundle = path.join(folder, 'registry.bundle');
        expect(calls[0].program, 'git');
        expect(calls[0].arguments, ['init', '--quiet', '--bare', path.join(folder, 'registry.git')]);
        expect(calls[0].environment, clean);
        expect(calls[1].arguments, ['--git-dir', repository, 'update-ref', 'refs/heads/main', registryAfter]);
        expect(calls[1].environment, {...clean, 'GIT_ALTERNATE_OBJECT_DIRECTORIES': objects});
        expect(calls[2].arguments, ['--git-dir', repository, 'bundle', 'create', '--quiet', bundle, 'refs/heads/main']);
        expect(calls[2].environment, {...clean, 'GIT_ALTERNATE_OBJECT_DIRECTORIES': objects});
        expect(calls[3].program, 'porelo');
        expect(calls[3].arguments, [
          'registry',
          'verify',
          '--repository',
          bundle,
          '--host',
          'orchard',
          '--pinned',
          adminFingerprint,
          '--json',
        ]);
        expect(calls[3].environment, isEmpty);
        expect(calls[4].program, 'ssh');
        expect(calls[4].arguments, [
          '-F',
          config,
          '-T',
          '-o',
          'BatchMode=yes',
          '-o',
          'ForwardAgent=no',
          '-o',
          'ControlMaster=no',
          '-o',
          'ControlPath=none',
          'root@orchard',
          '/usr/local/sbin/porelo-host-person registry --stdin',
        ]);
        expect(calls[4].input, bundleBytes, reason: 'the bundle goes on stdin byte for byte');
        expect(bundleSeenAtSend, isTrue);
        expect(await leftOver(), isEmpty, reason: 'the temporary folder is removed');
      },
    );

    // Harm: a state older than the one the host applied is judged from the root instead of from what it applied.
    test('the last applied revision is verified from', () async {
      await settings.rememberHostRegistry(
        HostRegistryProgress(
          change: HostRegistryChange(id: 'a' * 32, host: 'orchard', action: 'deliver'),
          revision: registryBefore,
          published: true,
          uploaded: true,
          confirmedRevision: registryBefore,
          lastAppliedRevision: registryBefore,
        ),
      );
      await transport.upload('orchard', registryAfter);
      final verify = calls.singleWhere((call) => call.program == 'porelo').arguments;
      expect(verify.sublist(verify.length - 3), ['--since', registryBefore, '--json']);
    });

    // Harm: a bundle Core refuses, or one of another state or host, reaches root.
    for (final (name, answer, words) in [
      (
        'Core refuses',
        (code: 65, out: '', err: 'porelo: commit 1234 changes hosts/orchard/card unsigned\n'),
        'unsigned',
      ),
      (
        'Core verified another commit',
        (
          code: 0,
          out: jsonEncode({
            'commit': registryBefore,
            'host_card': {'host': 'orchard'},
          }),
          err: '',
        ),
        'another registry state',
      ),
      (
        'Core verified another host',
        (
          code: 0,
          out: jsonEncode({
            'commit': registryAfter,
            'host_card': {'host': 'grove'},
          }),
          err: '',
        ),
        'another registry state',
      ),
    ]) {
      test('$name: nothing is sent and the folder is removed', () async {
        verified = answer;
        await expectLater(
          transport.upload('orchard', registryAfter),
          throwsA(isA<RegistryRefusal>().having((refused) => refused.words, 'words', contains(words))),
        );
        expect(calls.where((call) => call.program == 'ssh'), isEmpty);
        expect(await leftOver(), isEmpty);
      });
    }

    // Harm: a revision the checkout lacks is bundled from something else, or verified at all.
    test('a revision the checkout lacks is neither verified nor sent', () async {
      gitFails = 1;
      await expectLater(transport.upload('orchard', registryAfter), throwsA(isA<RegistryRefusal>()));
      expect(calls.where((call) => call.program != 'git'), isEmpty);
      expect(await leftOver(), isEmpty);
    });

    // Harm: the host's refusal, or an intake of another revision, reads as the revision taken.
    for (final (name, answer, words) in [
      (
        'the host refuses',
        (code: 65, out: '', err: 'porelo-host-person: only the pinned host admin may bring the host\'s registry\n'),
        'porelo-host-person: only the pinned host admin may bring',
      ),
      (
        'SSH cannot reach root',
        (code: 255, out: '', err: 'root@orchard: Permission denied (publickey).\n'),
        'Permission denied',
      ),
      (
        'the host took another revision',
        (
          code: 0,
          out: jsonEncode({
            'commit': registryBefore,
            'pinned': adminFingerprint,
            'projects': <String>[],
            'dropped': <String>[],
            'revoked': <String>[],
            'refused': <String>[],
            'unchanged': true,
          }),
          err: '',
        ),
        'another registry revision',
      ),
      ('the host answers no object', (code: 0, out: '[]', err: ''), 'incompletely'),
    ]) {
      test('$name: upload refuses with its words', () async {
        taken = answer;
        await expectLater(
          transport.upload('orchard', registryAfter),
          throwsA(isA<RegistryRefusal>().having((refused) => refused.words, 'words', contains(words))),
        );
        expect(await leftOver(), isEmpty);
      });
    }

    // Harm: root is reached through ~/.ssh/config or a config outside the card's own place.
    for (final (name, change) in [
      ('no card config is kept', () => watched = []),
      (
        'the card config lies elsewhere',
        () => watched = [
          Machine.fromHostCard(
            watched.single.hostCard!,
            socketPath: watched.single.socketPath,
            sshConfig: path.join(home.path, 'elsewhere', 'orchard.conf'),
          ),
        ],
      ),
    ]) {
      test('$name: nothing runs', () async {
        change();
        await expectLater(transport.upload('orchard', registryAfter), throwsA(isA<RegistryRefusal>()));
        expect(calls, isEmpty);
      });
    }

    // Harm: without a signed host card, Core is asked to verify against no pinned key.
    test('a host without a signed card in the registry is refused before anything runs', () async {
      fixture.hostCard = null;
      await fixture.registry.refresh();
      await expectLater(transport.upload('orchard', registryAfter), throwsA(isA<RegistryRefusal>()));
      expect(calls, isEmpty);
    });

    // Harm: a sync or status the host never answered is confirmed.
    test('status and sync are refused, running nothing, while the host serves no verb for them', () async {
      await expectLater(
        transport.status('orchard'),
        throwsA(isA<RegistryRefusal>().having((refused) => refused.words, 'words', SshHostRegistryTransport.noStatus)),
      );
      await expectLater(
        transport.sync('orchard', registryAfter),
        throwsA(isA<RegistryRefusal>().having((refused) => refused.words, 'words', SshHostRegistryTransport.noSync)),
      );
      expect(calls, isEmpty);
    });
  });
}

import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

/// A provider that counts what it was asked.
class CountingProvider implements HostProvider {
  RentedHost? rented;
  int created = 0;
  final released = <String>[];

  @override
  Future<RentedHost?> find(String tag) async => rented;

  @override
  Future<RentedHost> create(HostRequest request) async {
    created++;
    expect(request.tags, contains('porelo-project=demo'));
    return rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
  }

  @override
  Future<RentedHost> state(String id) async => rented!;

  @override
  Future<void> release(String id) async {
    released.add(id);
    rented = null;
  }
}

/// A host whose playbook says what [lines] holds, and which keeps every command and input it got.
class ScriptedRemote implements Remote {
  ScriptedRemote(this.lines, {this.playExit = 0, this.uid = '1007', this.uidExit = 0});

  final String uid;
  final int uidExit;

  List<String> lines;
  int playExit;
  final commands = <String>[];
  final inputs = <String>[];
  final users = <String>[];

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    commands.add(command);
    users.add(user);
    if (input != null) inputs.add(input);
    if (command == 'id -u') {
      onLine?.call(uid);
      return RemoteResult(uidExit, '');
    }
    if (command.contains('ansible-playbook')) {
      lines.forEach(onLine!);
      return RemoteResult(playExit, '');
    }
    return const RemoteResult(0, '');
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    commands.add('copy $from $to');
    users.add(user);
    return const RemoteResult(0, '');
  }
}

/// A host whose ssh answers [failures] first, or for ever, before it lets anybody in.
class FlakySsh extends ScriptedRemote {
  FlakySsh(this.failures, {this.forever = false}) : super(<String>[]);

  final List<RemoteResult> failures;
  final bool forever;
  int tries = 0;

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    if (command == 'true') {
      tries++;
      if (forever) return failures.first;
      if (tries <= failures.length) return failures[tries - 1];
    }
    return super.run(host, user, command, input: input, onLine: onLine);
  }
}

String line(Map<String, Object> fields) => jsonEncode(<String, Object>{'v': 1, ...fields});

void main() {
  const plan = HostPlan(project: 'demo', account: 'porelo', publicKey: 'ssh-ed25519 BBBB me', collection: 'c.tar.gz');
  final waits = <String>[
    line(<String, Object>{'play': 'first', 'task': 'base', 'state': 'started'}),
    line(<String, Object>{'play': 'first', 'task': 'base', 'state': 'ok'}),
    line(<String, Object>{
      'state': 'waiting',
      'needs': <String>['drive', 'vault-new'],
    }),
  ];
  final finishes = <String>[
    line(<String, Object>{'play': 'second', 'task': 'tasks', 'state': 'changed'}),
  ];

  // Prevents connecting to the wrong account or leaking unrelated provider facts.
  // Red: omit any destination field or add a provider fact to the final step.
  test('done up carries exactly the address account and account daemon socket', () async {
    final steps = <Step>[];
    final remote = ScriptedRemote(finishes);
    final run = HostRun(provider: CountingProvider(), remote: remote, emit: steps.add);
    expect(await run.up(plan), Exit.done);
    expect(jsonDecode(steps.last.toLine()), <String, Object>{
      'step': 'up',
      'state': 'done',
      'address': '203.0.113.7',
      'account': 'porelo',
      'socket': '/run/user/1007/porelo/porelod.sock',
    });
    final parsed = Step.fromLine(steps.last.toLine())!;
    expect(parsed.address, '203.0.113.7');
    expect(parsed.account, 'porelo');
    expect(parsed.socket, '/run/user/1007/porelo/porelod.sock');
    expect(remote.commands.last, 'id -u');
    expect(remote.users.last, 'porelo', reason: 'the socket belongs to the account, never root');
  });

  // Prevents an invalid or failed uid lookup from creating a usable-looking destination.
  // Red: accept arbitrary uid text, or ignore the lookup exit code.
  for (final uid in <String>['', '-1', '1007/other', '1007\n1008', '١٠٠٧']) {
    test('up refuses invalid uid $uid', () async {
      final steps = <Step>[];
      final run = HostRun(
        provider: CountingProvider(),
        remote: ScriptedRemote(finishes, uid: uid),
        emit: steps.add,
      );
      expect(await run.up(plan), Exit.refused);
      expect(steps.last.state, StepState.refused);
      expect(jsonDecode(steps.last.toLine()), isNot(contains('socket')));
    });
  }
  test('up refuses a failed uid lookup even with digits on stdout', () async {
    final run = HostRun(provider: CountingProvider(), remote: ScriptedRemote(finishes, uidExit: 1), emit: (_) {});
    expect(await run.up(plan), Exit.refused);
  });

  // Prevents an unsupported stop from exposing a destination or being treated as a sign-in action.
  // Red: attach address or account again to the waiting line.
  test('a waiting line carries needs without host facts', () async {
    final steps = <Step>[];
    final remote = ScriptedRemote(<String>[
      line(<String, Object>{
        'state': 'waiting',
        'needs': <String>['agent-login:pi'],
        'address': 'wrong',
        'account': 'root',
      }),
    ], playExit: 2);
    expect(await HostRun(provider: CountingProvider(), remote: remote, emit: steps.add).up(plan), Exit.waiting);
    expect(jsonDecode(steps.last.toLine()), <String, Object>{
      'step': 'person',
      'state': 'waiting',
      'needs': <String>['agent-login:pi'],
    });
  });

  test('up rents, trusts the provider\'s key, copies, installs and stops for the person with 75', () async {
    final provider = CountingProvider();
    final remote = ScriptedRemote(waits, playExit: 2);
    final trusted = <String>[];
    final steps = <Step>[];
    final run = HostRun(
      provider: provider,
      remote: remote,
      emit: steps.add,
      trust: (address, key) async => trusted.add('$address $key'),
    );

    final code = await run.up(plan);

    expect(code, Exit.waiting, reason: 'ansible-playbook ends with 2 at the stop; the line says it is the stop');
    expect(provider.created, 1);
    expect(trusted, <String>['203.0.113.7 ssh-ed25519 AAAA']);
    expect(steps.map((s) => '${s.step}:${s.state.name}'), <String>[
      'rent:started', 'rent:done', 'ssh:started', 'ssh:done', 'copy:started', 'copy:done',
      'ansible:started', 'ansible:done', 'base:started', 'base:done', 'person:waiting', //
    ]);
    expect(steps.last.needs, <String>['drive', 'vault-new']);
    expect(remote.commands.last, contains('-c local -i /var/tmp/porelo-host/inventory.yml porelo.host.up'));
    final inventory = jsonDecode(remote.inputs.single) as Map<String, Object?>;
    final vars = (inventory['all'] as Map)['vars'] as Map;
    expect(vars['porelo_host_account'], 'porelo');
    expect(vars['porelo_host_distribution'], 'snapshots', reason: 'no release of Porelo has `vault status` yet');
    expect(
      vars.containsKey('porelo_host_tresor'),
      isFalse,
      reason: 'a name not given is left out, for the role to say',
    );
  });

  test('a second up rents nothing, gives the answers on standard input only and goes on', () async {
    final provider = CountingProvider()
      ..rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
    final remote = ScriptedRemote(finishes);
    final steps = <Step>[];
    final run = HostRun(provider: provider, remote: remote, emit: steps.add);

    final code = await run.up(
      plan,
      answers: const Answers(
        driveEmail: 'me@example.org',
        drivePassword: 'drive-secret',
        driveCode: '123456',
        vaultPassphrase: 'vault-secret',
      ),
    );

    expect(code, Exit.done);
    expect(provider.created, 0, reason: 'the host is found again by its tag');
    expect(remote.inputs, containsAll(<String>['drive-secret\n123456\n', 'vault-secret\n']));
    for (final command in remote.commands) {
      expect(command, isNot(contains('secret')), reason: 'a secret never stands in a command line');
      expect(command, isNot(contains('123456')), reason: 'nor the one-time code, nor as --totp');
    }
    final login = remote.commands.indexWhere((c) => c.contains('tresorit-cli login'));
    expect(
      remote.commands[login],
      startsWith(r'XDG_RUNTIME_DIR=/run/user/$(id -u) tresorit-cli login '),
      reason: 'the client reaches the account\'s running daemon whatever the ssh session sets',
    );
    final vault = remote.commands.indexWhere((c) => c.contains('--passphrase-stdin'));
    expect(
      remote.commands[vault],
      startsWith(r'export XDG_RUNTIME_DIR=/run/user/$(id -u); '),
      reason: 'porelo reaches the account\'s own daemon whatever the ssh session sets',
    );
    final play = remote.commands.indexWhere((c) => c.contains('ansible-playbook'));
    expect(login < vault && vault < play, isTrue, reason: 'the drive, then the vault, then the plays');
    expect(remote.users[vault], 'porelo', reason: 'the vault is the account\'s own');
  });

  test('ssh is asked again for twenty minutes by default, a bare-metal host\'s first boot', () {
    final run = HostRun(provider: CountingProvider(), remote: ScriptedRemote(<String>[]), emit: (_) {});
    expect(run.sshWithin, const Duration(minutes: 20), reason: 'Elastic Metal answered ssh after about 13 minutes');
  });

  test('a host that does not answer ssh within its time is unreachable, with ssh\'s last words', () async {
    final down = FlakySsh(<RemoteResult>[const RemoteResult(255, 'Connection refused')], forever: true);
    final steps = <Step>[];
    final run = HostRun(
      provider: CountingProvider(),
      remote: down,
      emit: steps.add,
      sshEvery: const Duration(milliseconds: 5),
      sshWithin: const Duration(milliseconds: 60),
    );
    expect(await run.up(plan), Exit.unreachable);
    expect(down.tries, inInclusiveRange(3, 20), reason: 'asked again while the time lasts, and no longer');
    expect(steps.last.words, 'Connection refused');
  });

  test('ssh is asked again while a fresh host starts, but a wrong host key is refused at once', () async {
    final starting = FlakySsh(<RemoteResult>[
      const RemoteResult(255, 'kex_exchange_identification: read: Connection reset by peer'),
      const RemoteResult(255, 'Connection refused'),
    ]);
    final run = HostRun(provider: CountingProvider(), remote: starting, emit: (_) {}, sshEvery: Duration.zero);
    expect(await run.up(plan), Exit.done);
    expect(starting.tries, 3);

    final forged = FlakySsh(<RemoteResult>[
      const RemoteResult(255, 'WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!\nHost key verification failed.'),
    ], forever: true);
    final steps = <Step>[];
    final refused = HostRun(provider: CountingProvider(), remote: forged, emit: steps.add, sshEvery: Duration.zero);
    expect(await refused.up(plan), Exit.unreachable);
    expect(forged.tries, 1, reason: 'waiting cannot change a host key');
    expect(steps.map((s) => s.step), isNot(contains('copy')));
  });

  test('a provider\'s refusal ends up and down with a refused step and 65, never an exception', () async {
    final steps = <Step>[];
    final run = HostRun(provider: _RefusingProvider(), remote: ScriptedRemote(<String>[]), emit: steps.add);
    expect(await run.up(plan), Exit.refused);
    expect(steps.last.step, 'rent');
    expect(steps.last.state, StepState.refused);
    expect(steps.last.fix, 'fr-par-1 installs no Ubuntu 26.04 on EM-I220E-NVME');
  });

  test('a failed task is a refusal with its words, not a stop', () async {
    final remote = ScriptedRemote(<String>[
      line(<String, Object>{'play': 'first', 'task': 'base', 'state': 'failed', 'msg': 'no space left'}),
    ], playExit: 2);
    final steps = <Step>[];
    final run = HostRun(provider: CountingProvider(), remote: remote, emit: steps.add);

    expect(await run.up(plan), Exit.refused);
    expect(steps.last.state, StepState.refused);
    expect(steps.last.fix, 'no space left');
  });

  test('a line that is not the callback\'s is not relayed', () async {
    final remote = ScriptedRemote(<String>['PLAY [first] ****', '{"v": 2, "state": "ok"}', ...finishes]);
    final steps = <Step>[];
    await HostRun(provider: CountingProvider(), remote: remote, emit: steps.add).up(plan);
    expect(steps.map((s) => s.step), isNot(contains('PLAY [first] ****')));
    expect(steps.where((s) => s.step == 'play'), isEmpty);
  });

  // Prevents forgetting a still-billed machine when teardown found a different project.
  // Red: omit the released address, or attach an address when no host was found.
  test('down names exactly the host given back and distinguishes nothing found', () async {
    final provider = CountingProvider()
      ..rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
    final steps = <Step>[];
    final run = HostRun(provider: provider, remote: ScriptedRemote(finishes), emit: steps.add);
    expect(await run.down(plan), Exit.done);
    expect(provider.released, <String>['h1']);
    expect(jsonDecode(steps.last.toLine()), <String, Object>{
      'step': 'give-back',
      'state': 'done',
      'address': '203.0.113.7',
    });
    steps.clear();
    expect(await run.down(plan), Exit.done);
    expect(jsonDecode(steps.last.toLine()), <String, Object>{
      'step': 'give-back',
      'state': 'done',
      'words': 'no host carries the project tag',
    });
    expect(provider.released, <String>['h1'], reason: 'nothing else was given back');
  });

  test('down plays down first and only then gives the host back', () async {
    final provider = CountingProvider()
      ..rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
    final remote = ScriptedRemote(finishes);
    final run = HostRun(provider: provider, remote: remote, emit: (_) {});

    expect(await run.down(plan), Exit.done);
    expect(remote.commands.single, contains('porelo.host.down'));
    expect(provider.released, <String>['h1']);
  });

  group('a down whose play does not finish', () {
    const copyFailed = "the Matrix room's copy failed; the host is kept so its conversation is not lost";
    late CountingProvider provider;
    late ScriptedRemote remote;
    setUp(() {
      provider = CountingProvider()
        ..rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
      remote = ScriptedRemote(<String>[
        line(<String, Object>{'play': 'down', 'task': 'copy', 'state': 'failed', 'msg': copyFailed}),
      ], playExit: 2);
    });

    test('keeps the host, says it is kept and names both ways out', () async {
      final steps = <Step>[];
      final run = HostRun(provider: provider, remote: remote, emit: steps.add);

      expect(await run.down(plan), Exit.refused);
      expect(provider.released, isEmpty, reason: 'a host whose last copy failed still holds the only copy');
      expect(steps.firstWhere((s) => s.step == 'copy').fix, copyFailed);
      expect(steps.last.step, 'give-back');
      expect(steps.last.state, StepState.refused);
      expect(steps.last.words, 'h1 is kept and still billed, since its down play did not finish');
      expect(steps.last.fix, "run 'down' again, or 'down --give-back-anyway' to give it back knowingly");
    });

    test('gives it back when told to anyway, and says what went with it', () async {
      final steps = <Step>[];
      final run = HostRun(provider: provider, remote: remote, emit: steps.add);

      expect(await run.down(plan, giveBackAnyway: true), Exit.refused, reason: 'the failed step is still reported');
      expect(provider.released, <String>['h1']);
      expect(steps.last.step, 'give-back');
      expect(steps.last.state, StepState.done);
      expect(steps.last.words, 'given back knowingly although its down play did not finish: what it held is gone');
    });

    test('that cannot reach the host keeps it too, unless told to anyway', () async {
      provider.rented = const RentedHost(id: 'h1', address: null, hostKey: null, ready: true);
      final steps = <Step>[];

      expect(await HostRun(provider: provider, remote: remote, emit: steps.add).down(plan), Exit.unreachable);
      expect(provider.released, isEmpty);
      expect(steps.last.state, StepState.refused);

      expect(
        await HostRun(provider: provider, remote: remote, emit: steps.add).down(plan, giveBackAnyway: true),
        Exit.unreachable,
      );
      expect(provider.released, <String>['h1']);
      expect(steps.last.state, StepState.done);
    });
  });

  test('a down whose play finishes gives the host back, told to anyway or not', () async {
    for (final anyway in <bool>[false, true]) {
      final provider = CountingProvider()
        ..rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
      final steps = <Step>[];
      final run = HostRun(provider: provider, remote: ScriptedRemote(finishes), emit: steps.add);

      expect(await run.down(plan, giveBackAnyway: anyway), Exit.done);
      expect(provider.released, <String>['h1']);
      expect(steps.last.words, isNull, reason: 'nothing was at risk, so nothing is said of it');
    }
  });

  test('a new host gets a host key made here: its private half in cloud-init, its public half in a tag', () async {
    HostRequest? asked;
    final provider = _AskingProvider((request) => asked = request);
    final remote = ScriptedRemote(finishes);
    final run = HostRun(
      provider: provider,
      remote: remote,
      emit: (_) {},
      hostKeys: () async =>
          ('-----BEGIN OPENSSH PRIVATE KEY-----\nPRIVATE\n-----END OPENSSH PRIVATE KEY-----\n', 'ssh-ed25519 HOSTPUB'),
    );

    await run.up(plan);

    expect(asked!.tags, containsAll(<String>['porelo-project=demo', 'porelo-host-key=HOSTPUB']));
    expect(asked!.userData, contains('ssh_genkeytypes: [ed25519]'));
    expect(asked!.userData, contains('    PRIVATE\n'));
    expect(asked!.userData, contains('ed25519_public: ssh-ed25519 HOSTPUB'));
    for (final command in remote.commands) {
      expect(command, isNot(contains('PRIVATE')), reason: 'the private half goes to the provider only');
    }
  });
}

/// A provider that keeps what it was asked to rent, and rents it ready.
class _AskingProvider implements HostProvider {
  _AskingProvider(this.asked);

  final void Function(HostRequest request) asked;
  RentedHost? rented;

  @override
  Future<RentedHost?> find(String tag) async => rented;

  @override
  Future<RentedHost> create(HostRequest request) async {
    asked(request);
    return rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 HOSTPUB', ready: true);
  }

  @override
  Future<RentedHost> state(String id) async => rented!;

  @override
  Future<void> release(String id) async {}
}

/// A provider that refuses as Scaleway's adapter does, with its own words.
class _RefusingProvider implements HostProvider {
  @override
  Future<RentedHost?> find(String tag) async => null;

  @override
  Future<RentedHost> create(HostRequest request) async =>
      throw const ProviderFailed('fr-par-1 installs no Ubuntu 26.04 on EM-I220E-NVME');

  @override
  Future<RentedHost> state(String id) => throw UnimplementedError();

  @override
  Future<void> release(String id) => throw const ProviderFailed('the key may not give back h1: denied');
}

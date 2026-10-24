import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
  late HostPlan plan;
  late Directory scratch;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-run-');
    final collection = File('${scratch.path}/c.tar.gz');
    await collection.writeAsString('test collection');
    plan = HostPlan(
      project: 'demo',
      account: 'porelo',
      publicKey: 'ssh-ed25519 BBBB me',
      collection: collection.path,
      collectionSha256: sha256.convert(await collection.readAsBytes()).toString(),
    );
  });
  tearDown(() => scratch.delete(recursive: true));
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

  // Harm: malformed callback data crashes provisioning while a rented host keeps billing.
  test('malformed relayed fields are dropped and a taskless plan is relayed', () async {
    final planned = [
      {'task': 'base', 'text': 'Prepare the account', 'seconds': 25},
      {'task': 'optional', 'text': 'Copy existing files', 'seconds': 10, 'when': true},
    ];
    final lines = <String>[
      line({'state': 'plan', 'steps': planned}),
      for (final field in ['msg', 'task', 'play', 'text', 'seconds', 'steps', 'needs'])
        line({'state': 'started', 'task': 'broken-$field', field: false}),
      line({
        'state': 'plan',
        'steps': [
          {'task': 'bad', 'text': 4},
        ],
      }),
      line({'state': 'started', 'task': 'base', 'text': 'Prepare the account', 'seconds': 25}),
      line({'state': 'ok', 'task': 'base'}),
    ];
    final steps = <Step>[];
    final result = await HostRun(provider: CountingProvider(), remote: ScriptedRemote(lines), emit: steps.add).up(plan);
    expect(result, Exit.done);
    expect(steps.where((step) => step.step.startsWith('broken-')), isEmpty);
    final plans = steps
        .map((step) => jsonDecode(step.toLine()) as Map)
        .where((step) => step['state'] == 'plan')
        .toList();
    expect(plans, hasLength(2));
    expect((plans.first['steps'] as List).map((step) => (step as Map)['task']), ['rent', 'ssh', 'copy', 'ansible']);
    expect((plans.last['steps'] as List).skip(4), planned);
    expect(steps.first.toLine(), contains('"state":"plan"'));
    final base = jsonDecode(steps.firstWhere((step) => step.step == 'base').toLine()) as Map;
    expect(base['text'], 'Prepare the account');
    expect(base['seconds'], 25);
  });

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

  // Harm: a terminal reaches a different account or an untrusted address from callback data.
  test('a waiting line carries needs and the trusted host destination', () async {
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
      'address': '203.0.113.7',
      'account': 'porelo',
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
      'plan:plan', 'rent:started', 'rent:done', 'ssh:started', 'ssh:done', 'copy:started', 'copy:done',
      'ansible:started', 'ansible:done', 'base:started', 'base:done', 'person:waiting', //
    ]);
    expect(steps.last.needs, <String>['drive', 'vault-new']);
    expect(remote.commands.last, contains('-c local -i /var/tmp/porelo-host/inventory.yml porelo.host.up'));
    final inventory = jsonDecode(remote.inputs.first) as Map<String, Object?>;
    final vars = (inventory['all'] as Map)['vars'] as Map;
    expect(vars['porelo_host_account'], 'porelo');
    expect(vars['porelo_host_distribution'], 'snapshots', reason: 'no release of Porelo has `vault status` yet');
    expect(
      vars.containsKey('porelo_host_tresor'),
      isFalse,
      reason: 'a name not given is left out, for the role to say',
    );
  });

  // Harm: a secret passes through provisioning instead of staying in the host terminal.
  test('both up runs write only the exact nonsecret inventory and digest to remote stdin', () async {
    final provider = CountingProvider();
    final remote = ScriptedRemote(waits, playExit: 2);
    final steps = <Step>[];
    final run = HostRun(provider: provider, remote: remote, emit: steps.add);
    expect(await run.up(plan), Exit.waiting);
    remote.lines = finishes;
    remote.playExit = 0;
    expect(await run.up(plan), Exit.done);
    expect(provider.created, 1, reason: 'the second up finds the same host');
    final inventory = const JsonEncoder.withIndent('  ').convert({
      'all': {
        'hosts': {'localhost': <String, Object>{}},
        'vars': {
          'porelo_host_inventory_version': 1,
          'porelo_host_account': 'porelo',
          'porelo_host_authorized_key': 'ssh-ed25519 BBBB me',
          'porelo_host_project': 'demo',
          'porelo_host_distribution': 'snapshots',
        },
      },
    });
    final digest = '${plan.collectionSha256}  /var/tmp/porelo-host/collection.tar.gz\n';
    expect(remote.inputs, [
      inventory,
      digest,
      inventory,
      digest,
    ], reason: 'only the inventory and digest on either run');
    expect(
      remote.commands.where((c) => c.contains('tresorit-cli login') || c.contains('porelo vault')),
      isEmpty,
      reason: 'up never runs a command taking a password, code or passphrase',
    );
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
      'text': 'Give the project server back',
      'seconds': 30,
      'address': '203.0.113.7',
    });
    steps.clear();
    expect(await run.down(plan), Exit.done);
    expect(jsonDecode(steps.last.toLine()), <String, Object>{
      'step': 'give-back',
      'state': 'done',
      'words': 'no host carries the project tag',
      'text': 'Give the project server back',
      'seconds': 30,
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

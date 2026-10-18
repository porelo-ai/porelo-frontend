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
  ScriptedRemote(this.lines, {this.playExit = 0});

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
    expect(vars['porelo_host_distribution'], 'releases');
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
        vaultPassphrase: 'vault-secret',
      ),
    );

    expect(code, Exit.done);
    expect(provider.created, 0, reason: 'the host is found again by its tag');
    expect(remote.inputs, containsAll(<String>['drive-secret\n', 'vault-secret\n']));
    for (final command in remote.commands) {
      expect(command, isNot(contains('secret')), reason: 'a secret never stands in a command line');
    }
    final login = remote.commands.indexWhere((c) => c.contains('tresorit-cli login'));
    final vault = remote.commands.indexWhere((c) => c.contains('--passphrase-stdin'));
    final play = remote.commands.indexWhere((c) => c.contains('ansible-playbook'));
    expect(login < vault && vault < play, isTrue, reason: 'the drive, then the vault, then the plays');
    expect(remote.users[vault], 'porelo', reason: 'the vault is the account\'s own');
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

  test('down plays down first and only then gives the host back', () async {
    final provider = CountingProvider()
      ..rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
    final remote = ScriptedRemote(finishes);
    final run = HostRun(provider: provider, remote: remote, emit: (_) {});

    expect(await run.down(plan), Exit.done);
    expect(remote.commands.single, contains('porelo.host.down'));
    expect(provider.released, <String>['h1']);
  });

  test('a down whose play fails gives nothing back', () async {
    final provider = CountingProvider()
      ..rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: 'ssh-ed25519 AAAA', ready: true);
    final remote = ScriptedRemote(<String>[
      line(<String, Object>{'play': 'down', 'task': 'copy', 'state': 'failed', 'msg': 'the store refused'}),
    ], playExit: 2);
    final run = HostRun(provider: provider, remote: remote, emit: (_) {});

    expect(await run.down(plan), Exit.refused);
    expect(provider.released, isEmpty, reason: 'a host whose last copy failed still holds the only copy');
  });
}

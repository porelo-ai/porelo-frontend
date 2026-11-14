// Linux only: HostRun protects its state directory with chmod.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'server_contract_test.dart' show sshKey, hostValues;

/// A provider that counts what it was asked.
class CountingProvider implements HostProvider {
  RentedHost? rented;
  int created = 0;
  final found = <String>[];
  final released = <String>[];

  @override
  Future<RentedHost?> find(String tag) async {
    found.add(tag);
    return rented;
  }

  @override
  Future<RentedHost> create(HostRequest request) async {
    created++;
    return rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: sshKey, ready: true);
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
  String status = '{"persons": []}';
  RemoteResult statusResult = const RemoteResult(0, '');
  final purgeResults = <String, RemoteResult>{};
  final purgeOutput = <String, List<String>>{};

  /// Each command run, with what it was given on standard input, in order.
  final runs = <({String command, String input})>[];

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
    runs.add((command: command, input: input ?? ''));
    if (command == 'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host org status --json') {
      const LineSplitter().convert(status).forEach((line) => onLine?.call(line));
      return statusResult;
    }
    if (command.startsWith(
      'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge ',
    )) {
      final login = command.split(' ').last;
      for (final line in purgeOutput[login] ?? const <String>[]) {
        onLine?.call(line);
      }
      return purgeResults[login] ?? const RemoteResult(0, '');
    }
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

class _Preparation implements ServerPreparation {
  int calls = 0;
  Map<String, Object>? receivedInventory;
  HostPreparationSettings? receivedSettings;
  Map<String, Object?>? result;
  Exception? refused;
  @override
  Future<PreparedHost> prepare({
    required Remote remote,
    required String name,
    required String address,
    required List<String> adminSigners,
    required String adminLogin,
    required String adminKey,
    Map<String, Object> inventory = const {},
    HostPreparationSettings settings = const HostPreparationSettings(),
  }) async {
    calls++;
    receivedInventory = inventory;
    receivedSettings = settings;
    if (refused != null) throw refused!;
    expect(name, 'orchard');
    expect(address, '203.0.113.7');
    expect(adminSigners, [sshKey]);
    expect((adminLogin, adminKey), ('alice', sshKey));
    return PreparedHost.read(result ?? hostValues(), hostName: name, localServices: settings.localServices);
  }
}

void main() {
  late Directory scratch;
  late CountingProvider provider;
  late ScriptedRemote remote;
  late List<Step> steps;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-run-');
    provider = CountingProvider();
    remote = ScriptedRemote([]);
    steps = [];
  });
  tearDown(() => scratch.delete(recursive: true));
  HostRun runner({ServerPreparation? preparation, ScriptedRemote? transport}) => HostRun(
    provider: provider,
    remote: transport ?? remote,
    emit: steps.add,
    preparation: preparation,
    hostKeys: () async => ('fixture-host-private', sshKey),
    environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
  );
  const plan = HostPlan(
    adminLogin: 'alice',
    hostName: 'orchard',
    loginUser: 'root',
    publicKey: sshKey,
    adminSigners: [sshKey],
  );

  // Harm: teardown must remove only explicitly confirmed accounts before the play can release their server.
  test('only named logins are purged as root before the down play', () async {
    provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
    remote.status = jsonEncode({
      'persons': [membership('unseen', admin: true)],
    });
    final run = HostRun(
      provider: provider,
      remote: remote,
      emit: steps.add,
      environment: {'XDG_STATE_HOME': scratch.path},
      trust: (address, key) async {
        expect((address, key), ('192.0.2.7', sshKey));
        expect(remote.commands, isEmpty);
        remote.commands.add('trust');
      },
    );
    expect(await run.down(plan, purge: ['alice', 'bob', 'alice']), Exit.done);
    final purges = remote.commands
        .where(
          (command) => command.startsWith(
            'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge ',
          ),
        )
        .toList();
    expect(purges, [
      'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge alice',
      'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge bob',
    ]);
    expect(remote.commands.first, 'trust');
    expect(
      remote.commands.indexOf(purges.last),
      lessThan(remote.commands.indexWhere((command) => command.contains('ansible-playbook'))),
    );
    expect(remote.users.toSet(), {'root'});
    expect(remote.commands.any((command) => command.contains('unseen')), isFalse);
    expect(provider.released, ['h1']);
  });

  // Harm: a partial purge must not continue deleting accounts or give back the only copy of their data.
  for (final failure in ['stderr', 'stdout', 'ssh']) {
    // Harm: discarding a purge refusal's diagnostics hides why deleting an account could not complete.
    test('a failed purge on $failure keeps its explanation and stops teardown', () async {
      provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
      remote.purgeResults['alice'] = RemoteResult(
        failure == 'ssh' ? 255 : 65,
        failure == 'stdout' ? '' : 'alice still has an unreviewed task',
      );
      if (failure == 'stdout') remote.purgeOutput['alice'] = ['alice still has an unreviewed task'];
      expect(await runner().down(plan, purge: ['alice', 'bob']), failure == 'ssh' ? Exit.unreachable : Exit.refused);
      expect(remote.commands, [
        'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host person purge alice',
      ]);
      expect(steps.last.state, StepState.refused);
      expect(steps.last.words, contains('alice'));
      expect(steps.last.words, contains('unreviewed task'));
      expect(provider.released, isEmpty);
      expect(provider.rented, isNotNull);
    });
  }

  // Harm: the helper refuses anyone through sudo, so a non-root login would stop half way or claim to have read nobody.
  test('a non-root login neither purges nor reads holders, and reaches nothing', () async {
    provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
    const project = HostPlan(project: 'garden', account: 'worker', publicKey: '', loginUser: 'ubuntu');
    expect(await runner().down(project, purge: ['alice']), isNot(Exit.done));
    expect(await runner().memberships(project), isNot(Exit.done));
    expect(remote.commands, isEmpty);
    expect(provider.released, isEmpty);
  });

  // Harm: an unaddressed or unpinned rental cannot safely receive a destructive purge or be released.
  for (final missing in ['address', 'key']) {
    test('a purge keeps the rental when its $missing is absent', () async {
      provider.rented = RentedHost(
        id: 'h1',
        address: missing == 'address' ? null : '192.0.2.7',
        hostKey: missing == 'key' ? null : sshKey,
        ready: true,
      );
      final run = HostRun(
        provider: provider,
        remote: remote,
        emit: steps.add,
        environment: {'XDG_STATE_HOME': scratch.path},
        trust: (_, _) async {},
      );
      expect(await run.down(plan, purge: ['alice']), missing == 'address' ? Exit.unreachable : Exit.refused);
      expect(remote.commands, isEmpty);
      expect(provider.released, isEmpty);
      expect(provider.rented, isNotNull);
    });
  }

  // Harm: an unconnected server's holders must be read from its pinned rental without renting or changing it.
  test('memberships use the provider pin and the plan login without any teardown', () async {
    provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
    remote.status = jsonEncode({
      'persons': [
        membership('alice', admin: true),
        membership(
          'bob',
          projects: [
            {'project': 'garden', 'role': 'member'},
          ],
        ),
        membership('retired', state: 'purged'),
      ],
    });
    final pins = <(String, String)>[];
    final run = HostRun(
      provider: provider,
      remote: remote,
      emit: steps.add,
      trust: (address, key) async {
        expect(remote.commands, isEmpty);
        pins.add((address, key));
      },
    );
    const project = HostPlan(project: 'garden', account: 'worker', publicKey: '', loginUser: 'root');
    expect(await run.memberships(project), Exit.done);
    expect(pins, [('192.0.2.7', sshKey)]);
    expect(provider.found, [HostPlan.tagFor('garden')]);
    expect(remote.users, ['root']);
    expect(remote.commands, [
      'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host org status --json',
    ]);
    final status = Step.fromLine(steps.last.toLine())!;
    expect((status.step, status.state), ('org-status', StepState.done));
    final holders = HostMembership.readStatus(status.words!);
    expect(holders.map((holder) => holder.login), ['alice', 'bob']);
    expect(holders.last.projects.single, (project: 'garden', role: 'member'));
    expect(provider.created, 0);
    expect(provider.released, isEmpty);
  });

  // Harm: locked, pending or purged accounts that still hold memberships must not escape the loss confirmation.
  test('membership holders are selected by their holdings in every known state', () {
    const states = ['active', 'locked', 'pending', 'purged', 'named'];
    final holders = HostMembership.readStatus(
      jsonEncode({
        'persons': [
          for (final state in states) ...[
            membership('$state-admin', state: state, admin: true),
            membership(
              '$state-member',
              state: state,
              projects: [
                {'project': 'garden', 'role': 'member'},
              ],
            ),
            membership('$state-empty', state: state),
          ],
        ],
      }),
    );
    expect(holders.map((holder) => holder.login), [
      for (final state in states) ...['$state-admin', '$state-member'],
    ]);
  });

  // Harm: an unreadable membership registry must keep its explanation instead of appearing empty.
  test('a refused status retains a reason written on standard output', () async {
    provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
    remote.statusResult = const RemoteResult(65, '');
    remote.status = 'alice cannot read the membership registry';
    expect(await runner().memberships(plan), Exit.refused);
    expect(steps.last.words, contains('alice'));
    expect(steps.last.words, contains('registry'));
    expect(provider.released, isEmpty);
  });

  // Harm: malformed or incomplete status must never authorize teardown as if no memberships existed.
  final malformed = <Object?>[
    null,
    [],
    {},
    {'persons': null},
    {'persons': <String, Object?>{}},
    {
      'persons': [null],
    },
    {
      'persons': [
        {'login': 'alice'},
      ],
    },
    for (final field in ['login', 'state', 'host_admin', 'projects'])
      {
        'persons': [
          {...membership('alice'), field: null},
        ],
      },
    {
      'persons': [
        {...membership('alice'), 'state': 'unknown'},
      ],
    },
    {
      'persons': [
        {...membership('alice'), 'host_admin': 'false'},
      ],
    },
    {
      'persons': [
        membership('alice', projects: [null]),
      ],
    },
    {
      'persons': [
        membership(
          'alice',
          projects: [
            {'project': 'garden'},
          ],
        ),
      ],
    },
    {
      'persons': [
        membership(
          'alice',
          projects: [
            {'project': '', 'role': 'member'},
          ],
        ),
      ],
    },
    {
      'persons': [
        membership(
          'alice',
          projects: [
            {'project': 'garden', 'role': 1},
          ],
        ),
      ],
    },
    {
      'persons': [
        {...membership('alice'), 'purge_on': 1},
      ],
    },
    {
      'persons': [membership('alice'), membership('alice', admin: true)],
    },
    {
      'persons': [membership('alice;id', admin: true)],
    },
    {
      'persons': [membership('alice', admin: true), <String, Object?>{}],
    },
  ];
  for (var i = 0; i < malformed.length + 1; i++) {
    test('malformed membership status $i refuses without changing the server', () async {
      provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
      remote.status = i == malformed.length ? 'not JSON' : jsonEncode(malformed[i]);
      expect(await runner().memberships(plan), Exit.refused);
      expect(steps.last.state, StepState.refused);
      expect(steps.where((step) => step.step == 'org-status' && step.state == StepState.done), isEmpty);
      expect(provider.released, isEmpty);
      expect(remote.commands, [
        'env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /usr/sbin/porelo-host org status --json',
      ]);
    });
  }

  // Harm: missing connection details or root access must keep the rental rather than imply it has no holders.
  for (final failure in ['missing', 'address', 'key', 'ssh', 'root']) {
    test('membership read refuses safely for $failure', () async {
      provider.rented = failure == 'missing'
          ? null
          : RentedHost(
              id: 'h1',
              address: failure == 'address' ? null : '192.0.2.7',
              hostKey: failure == 'key' ? null : sshKey,
              ready: true,
            );
      remote.statusResult = RemoteResult(
        failure == 'ssh'
            ? 255
            : failure == 'root'
            ? 1
            : 0,
        'Permission denied',
      );
      final run = HostRun(provider: provider, remote: remote, emit: steps.add, trust: (_, _) async {});
      expect(
        await run.memberships(plan),
        failure == 'missing' || failure == 'address' || failure == 'ssh' ? Exit.unreachable : Exit.refused,
      );
      expect(steps.last.state, StepState.refused);
      expect(provider.released, isEmpty);
      expect(provider.created, 0);
    });
  }

  // Harm: a host whose setup stopped before installing porelo-host is refused with env's last line as its reason,
  // which on uutils env names an option fault, and nothing says porelo-host is missing.
  test('a membership read of a host without porelo-host says it is not installed there', () async {
    provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
    remote.statusResult = const RemoteResult(
      127,
      "env: '/usr/sbin/porelo-host': No such file or directory\nenv: use -[v]S to pass options in shebang lines\n",
    );
    final run = HostRun(provider: provider, remote: remote, emit: steps.add, trust: (_, _) async {});
    expect(await run.memberships(plan), Exit.refused);
    expect(steps.last.state, StepState.refused);
    expect(steps.last.fix, contains('porelo-host is not installed on 192.0.2.7'));
    expect(steps.where((step) => '${step.words}'.contains('-[v]S')), isEmpty);
    expect(provider.released, isEmpty);
  });

  // Harm: retrying a refused existing root login can lock out the administrator.
  // Rental retries still allow cloud-init to finish installing its key.
  for (final given in [true, false]) {
    test('SSH retries only for rentals given=$given', () async {
      final transport = _LoginRefusal();
      final setup = _Preparation();
      final run = HostRun(
        provider: given ? GivenMachine(address: '203.0.113.7', hostKey: sshKey) : provider,
        remote: transport,
        preparation: setup,
        hostKeys: () async => ('fixture-host-private', sshKey),
        sshEvery: Duration.zero,
        emit: steps.add,
        environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
      );
      expect(await run.up(plan), given ? Exit.unreachable : Exit.done);
      expect(transport.logins, given ? 1 : 2);
      expect(setup.calls, given ? 0 : 1);
      if (given) expect(steps.last.words, 'Permission denied (publickey).');
    });
  }

  group('a login that answers and exits non-zero', () {
    HostRun running(Remote transport) => HostRun(
      provider: GivenMachine(address: '203.0.113.7', hostKey: sshKey),
      remote: transport,
      preparation: _Preparation(),
      hostKeys: () async => ('fixture-host-private', sshKey),
      sshEvery: Duration.zero,
      emit: steps.add,
      environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
    );

    // Harm: the foo test's refusal, with an empty reason and "could not be reached" for a host that answered.
    test('a cloud image closing root names the command to run, and what it said', () async {
      final transport = _Answering(142, 'Please login as the user "ubuntu" rather than the user "root".');
      await running(transport).up(plan);
      final last = steps.last;
      expect(last.step, 'ssh');
      expect(last.state, StepState.refused);
      expect(last.fix, contains(rootStillClosed));
      expect(last.fix, isNot(contains('could not be reached')));
      expect(last.words, contains('rather than the user "root"'));
      expect(last.words, contains('142'));
    });

    test('any other answer keeps its words and its code, and does not say unreachable', () async {
      await running(_Answering(1, 'Something on the login said no.')).up(plan);
      expect(steps.last.fix, isNot(contains('could not be reached')));
      expect(steps.last.words, contains('Something on the login said no.'));
      expect(steps.last.words, contains('exit code 1'));
    });

    test('no reason is ever empty', () async {
      await running(_Answering(1, '')).up(plan);
      expect(steps.last.fix, isNotEmpty);
      expect(steps.last.words, contains('exit code 1'));
    });
  });

  // Harm: a person who gave their own machine reads that a server is being rented, and fears a bill.
  test('a given machine is not said to be rented', () async {
    final run = HostRun(
      provider: GivenMachine(address: '203.0.113.7', hostKey: sshKey),
      remote: _LoginRefusal(),
      preparation: _Preparation(),
      hostKeys: () async => ('fixture-host-private', sshKey),
      sshEvery: Duration.zero,
      emit: steps.add,
      environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
    );
    await run.up(plan);
    final words = steps.map((step) => step.toLine()).join();
    expect(words, contains('"rent"'));
    expect(words.toLowerCase(), isNot(contains('rent the')));
  });

  // Harm: missing runner limits exhaust a small host, and wrong forwards misdirect its services.
  test('preparation receives version two inventory and chosen local forwards', () async {
    final setup = _Preparation();
    const choices = HostPreparationSettings(
      forgeRunnerCapacity: 1,
      forgeJobCpus: 1,
      forgeJobMemory: '768m',
      forgeWebPort: 3100,
      forgeGitPort: 3101,
      matrixPort: 8548,
    );
    expect(
      await runner(preparation: setup).up(
        const HostPlan(
          hostName: 'orchard',
          loginUser: 'root',
          publicKey: sshKey,
          adminSigners: [sshKey],
          adminLogin: 'alice',
          preparationSettings: choices,
        ),
      ),
      Exit.done,
    );
    expect(setup.receivedInventory, containsPair('porelo_host_inventory_version', 2));
    expect(setup.receivedInventory, containsPair('forge_runner_capacity', 1));
    expect(setup.receivedInventory, containsPair('forge_job_cpus', 1));
    expect(setup.receivedInventory, containsPair('forge_job_memory', '768m'));
    expect(setup.receivedSettings!.localServices, choices.localServices);
    expect(steps.last.host!.services, choices.localServices);
    expect(setup.receivedInventory!.keys.toSet(), {
      'porelo_host_inventory_version',
      'porelo_host_name',
      'porelo_host_network',
      'porelo_host_distribution',
      'porelo_host_forge',
      'porelo_host_kvm',
      'forge_runner_capacity',
      'forge_job_cpus',
      'forge_job_memory',
    });
  });

  // Harm: an unavailable or unsigned setup must not rent or run an obsolete playbook.
  test('missing served setup contract refuses before rent', () async {
    expect(await runner().up(plan), Exit.refused);
    expect(provider.created, 0);
    expect(remote.commands, isEmpty);
  });
  test('missing verified admin signers refuse before rent', () async {
    expect(
      await runner(preparation: _Preparation())
          .up(const HostPlan(hostName: 'orchard', loginUser: 'root', publicKey: sshKey)),
      Exit.refused,
    );
    expect(provider.created, 0);
    expect(remote.commands, isEmpty);
  });
  // Harm: preparation cannot pin the verified host admin if it receives no proven login.
  test('missing host admin login refuses before rent', () async {
    expect(
      await runner(preparation: _Preparation())
          .up(const HostPlan(hostName: 'orchard', loginUser: 'root', publicKey: sshKey, adminSigners: [sshKey])),
      Exit.refused,
    );
    expect(provider.created, 0);
  });

  // Harm: setup again must reuse the same rental rather than create another billed machine.
  test('a checked SSH setup completes and reuses its existing rental', () async {
    final setup = _Preparation();
    final run = runner(preparation: setup);
    expect(await run.up(plan), Exit.done);
    expect(await run.up(plan), Exit.done);
    expect(provider.created, 1);
    expect(setup.calls, 2);
    expect(steps.where((s) => s.state == StepState.host), hasLength(2));
  });
  // Harm: setup again must not turn a missing saved rental into another paid server.
  test('a missing existing rental refuses without creating a replacement', () async {
    final setup = _Preparation();
    expect(
      await runner(preparation: setup).up(
        const HostPlan(
          hostName: 'orchard',
          loginUser: 'root',
          publicKey: sshKey,
          adminSigners: [sshKey],
          adminLogin: 'alice',
          existingRentalTag: 'porelo-project=demo',
        ),
      ),
      Exit.refused,
    );
    expect(provider.created, 0);
    expect(setup.calls, 0);
    expect(HostPlan.lockNameForTag('porelo-project=demo'), 'demo');
  });

  // Harm: a completion from a different server must not be accepted as this host's card.
  test('a completion naming another host is refused', () async {
    final setup = _Preparation()..result = {...hostValues(), 'name': 'elsewhere'};
    expect(await runner(preparation: setup).up(plan), Exit.refused);
    expect(steps.where((s) => s.state == StepState.host), isEmpty);
    expect(provider.released, isEmpty);
  });
  // Harm: explicit loss confirmation must stop billing even when SSH teardown cannot run.
  test('loss-confirmed signed-state give-back releases without SSH teardown', () async {
    provider.rented = const RentedHost(id: 'h1', address: '192.0.2.7', hostKey: sshKey, ready: true);
    remote.playExit = 65;
    expect(await runner().down(plan, giveBackAnyway: true), Exit.done);
    expect(provider.released, ['h1']);
    expect(remote.commands, isEmpty);
    expect(steps.any((step) => step.state == StepState.refused), isFalse);
  });

  // Harm: a failed backup must not delete the only remaining copy of server data.
  // Harm: what a person must be told after a success stops at the first reader, which skips a state it does not know.
  test('a note from the play goes out as a note, and ends nothing', () async {
    provider.rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: sshKey, ready: true);
    final said = ScriptedRemote([
      jsonEncode({'v': 1, 'play': 'down', 'task': 'a task', 'state': 'ok', 'msg': ''}),
      jsonEncode({'v': 1, 'state': 'note', 'msg': 'The firewall stays on.'}),
    ]);
    final run = HostRun(
      provider: provider,
      remote: said,
      emit: steps.add,
      environment: {'XDG_STATE_HOME': scratch.path},
      trust: (_, _) async {},
    );
    expect(await run.down(plan), Exit.done);
    final notes = steps.where((step) => step.state == StepState.note).toList();
    expect(notes.single.words, 'The firewall stays on.');
    expect(Step.fromLine(notes.single.toLine())?.state, StepState.note);
    expect(provider.released, ['h1']);
  });

  // Harm: the last thing a machine says, as it stays with a person after a failed play, never arrives.
  test('a note after a failed task still goes out', () async {
    provider.rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: sshKey, ready: true);
    final said = ScriptedRemote([
      jsonEncode({'v': 1, 'play': 'down', 'task': 'a task', 'state': 'failed', 'msg': 'it failed'}),
      jsonEncode({'v': 1, 'state': 'note', 'msg': 'The firewall stays on.'}),
      'not a line of the collection',
      jsonEncode({'v': 1, 'state': 'waiting', 'needs': 3}),
    ], playExit: 2);
    final run = HostRun(
      provider: provider,
      remote: said,
      emit: steps.add,
      environment: {'XDG_STATE_HOME': scratch.path},
      trust: (_, _) async {},
    );
    expect(await run.down(plan), Exit.refused);
    expect(steps.where((step) => step.state == StepState.note).single.words, 'The firewall stays on.');
    expect(steps.where((step) => step.state == StepState.refused).first.fix, 'it failed');
    expect(provider.released, isEmpty);
  });

  test('failed down play retains the billed host', () async {
    provider.rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: sshKey, ready: true);
    remote.playExit = 65;
    expect(await runner().down(plan), Exit.refused);
    expect(provider.released, isEmpty);
    expect(provider.rented, isNotNull);
  });
  // Harm: an adapter error can contain secrets that must not reach protocol output.
  test('setup dependency diagnostics stay out of the public protocol', () async {
    final setup = _Preparation()..refused = const FormatException('sensitive-fixture');
    expect(await runner(preparation: setup).up(plan), Exit.refused);
    expect(steps.map((step) => step.toLine()).join(), isNot(contains('sensitive-fixture')));
    expect(provider.released, isEmpty);
  });
  // Harm: normal give-back cannot be blocked by a removed setup-only key parameter.
  test('normal give-back needs no setup public key', () async {
    provider.rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: sshKey, ready: true);
    const down = HostPlan(hostName: 'orchard', loginUser: 'root', publicKey: '');
    expect(await runner().down(down), Exit.done);
    expect(provider.released, ['h1']);
  });
  // Harm: an SSH host-key mismatch must stop before any setup protocol runs.
  test('a changed SSH host key prevents preparation', () async {
    final setup = _Preparation();
    final run = runner(preparation: setup, transport: _WrongKey());
    expect(await run.up(plan), Exit.unreachable);
    expect(setup.calls, 0);
    expect(provider.released, isEmpty);
  });

  // Harm: a person reads ssh's own line, with nothing saying that an install changes the key or what next.
  test('a refused key says what happened and what to do, with ssh\'s line below', () async {
    final run = HostRun(
      provider: GivenMachine(address: '203.0.113.7', hostKey: sshKey),
      remote: _WrongKey(),
      emit: steps.add,
      preparation: _Preparation(),
      hostKeys: () async => ('fixture-host-private', sshKey),
      environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
    );
    await run.up(plan);
    final said = steps.lastWhere((step) => step.state == StepState.refused);
    expect(said.fix, startsWith(hostKeyNotFiled));
    expect(said.fix, contains('changed nothing'));
    expect(said.words, contains('Host key verification failed'));
  });
}

Map<String, Object?> membership(
  String login, {
  bool admin = false,
  String state = 'active',
  List<Object?> projects = const [],
}) => {'login': login, 'state': state, 'host_admin': admin, 'projects': projects};

class _WrongKey extends ScriptedRemote {
  _WrongKey() : super([]);
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async => const RemoteResult(255, 'Host key verification failed');
}

class _LoginRefusal extends ScriptedRemote {
  _LoginRefusal() : super([]);
  int logins = 0;
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    if (command == 'true' && ++logins == 1) return const RemoteResult(255, 'Permission denied (publickey).');
    return super.run(host, user, command, input: input, onLine: onLine);
  }
}

/// A login that succeeds and then exits [code], saying [said] on standard output.
class _Answering implements Remote {
  _Answering(this.code, this.said);

  final int code;
  final String said;

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    if (said.isNotEmpty) onLine?.call(said);
    return RemoteResult(code, '');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

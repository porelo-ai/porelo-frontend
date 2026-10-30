// Linux only: HostRun protects its state directory with chmod.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'server_contract_test.dart' show sshKey, hostValues;

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
  const recovery = HostPlan(project: 'demo', account: 'worker', publicKey: '', recoveryOnly: true);

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
  // Harm: obsolete teardown credentials must not run before legacy rental give-back.
  test('legacy give-back requires explicit loss confirmation and never opens SSH', () async {
    provider.rented = const RentedHost(id: 'h1', address: '203.0.113.7', hostKey: sshKey, ready: true);
    expect(await runner().down(recovery), Exit.refused);
    expect(provider.released, isEmpty);
    expect(await runner().down(recovery, giveBackAnyway: true), Exit.done);
    expect(provider.released, ['h1']);
    expect(await provider.find(recovery.tag), isNull);
    expect(remote.commands, isEmpty);
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
}

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

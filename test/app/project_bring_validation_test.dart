import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_bring.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/signed_host_actions.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/signed_host.dart';
import '../support/host_admin.dart' show personKey;
import '../support/project_access.dart';

import 'package:porelo_frontend/src/app/project_access.dart';

void main() {
  late Settings settings;
  late Machines machines;
  late SignedHostFake service;
  setUp(() {
    settings = Settings(MemorySettingsStore());
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    service = SignedHostFake();
  });
  tearDown(() {
    machines.dispose();
    settings.dispose();
  });

  // Harm: an absent signer or refused admission must never cause a host mutation.
  for (final admitted in [false, true]) {
    test('${admitted ? 'missing signers' : 'refused admission'} prevents connection and registration', () async {
      service.state = VerifiedHostProject(
        project: 'demo',
        host: service.state.host,
        revision: service.state.revision,
        adminSigners: admitted ? [] : service.state.adminSigners,
        admitted: admitted,
      );
      final action = ProjectBring(project: 'demo', machines: machines, settings: settings, actions: service);
      addTearDown(action.dispose);
      await action.bring();
      expect(service.calls, ['verify demo register']);
      expect(action.brought, isFalse);
      expect(settings.projectHost('demo'), isNull);
    });
  }

  // Harm: a retained Register callback must not bypass revoked host admission.
  test('a stale registry register callback cannot publish or upload', () async {
    final fixture = ProjectAccessFixture();
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    final action = ProjectBring(
      project: 'demo',
      machines: machines,
      settings: settings,
      actions: RegistryProjectRegistration(access),
    );
    addTearDown(action.dispose);
    final retained = action.bring;
    fixture.registrySource.admitted = false;
    await fixture.registry.refresh();
    await retained();
    expect(fixture.calls, isEmpty);
    expect(action.brought, isFalse);
    expect(action.problem, isNotNull);
    expect(settings.projectHost('demo'), isNull);
  });

  // Harm: delivery recovery must not create another access change or accept a wrong project.
  test('registry registration retries its published revision and saves only confirmed association', () async {
    final fixture = ProjectAccessFixture()..fail = 'upload';
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    final action = ProjectBring(
      project: 'demo',
      machines: machines,
      settings: settings,
      actions: RegistryProjectRegistration(access),
    );
    addTearDown(action.dispose);
    await action.bring();
    expect(action.brought, isFalse);
    expect(settings.projectHost('demo'), isNull);
    fixture.fail = null;
    await action.bring();
    expect(action.brought, isTrue);
    expect(fixture.filed.length, 1);
    expect(settings.projectHost('demo'), 'orchard');
  });

  // Harm: Retry in the person dialog must finish local registration without another commit.
  test('direct registration retry records the host and avoids duplicate registration', () async {
    final fixture = ProjectAccessFixture()..fail = 'upload';
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    await expectLater(access.register(), throwsFormatException);
    fixture.fail = null;
    await access.retry();
    expect(settings.projectHost('demo'), 'orchard');
    await access.register();
    expect(fixture.filed.length, 1);
  });

  // Harm: a wrong or refused host revision cannot become saved access to a project.
  for (final fails in [false, true]) {
    test('${fails ? 'refused registration' : 'a different revision'} keeps the project association absent', () async {
      if (fails) {
        service.refused = const FormatException('The signed state was refused.');
      } else {
        service.observed = 'b' * 40;
      }
      final action = ProjectBring(project: 'demo', machines: machines, settings: settings, actions: service);
      addTearDown(action.dispose);
      await action.bring();
      expect(action.brought, isFalse);
      expect(settings.projectHost('demo'), isNull);
      expect(machines.all.where((m) => m.kind == 'host'), isEmpty);
    });
  }

  // Harm: a dependency exception can contain a credential and must not become interface text.
  test('dependency diagnostics are not copied into registration errors', () async {
    service.refused = const FormatException('sensitive-fixture');
    final action = ProjectBring(project: 'demo', machines: machines, settings: settings, actions: service);
    addTearDown(action.dispose);
    await action.bring();
    expect(action.problem, isNot(contains('sensitive-fixture')));
    expect(settings.projectHost('demo'), isNull);
  });

  // Harm: the removal must retain one verified SSH path for both registering and joining.
  test('setup registration and joining use the accepted host and admin signer set through SSH', () async {
    final scratch = await Directory.systemTemp.createTemp('verified-round-trip-');
    addTearDown(() => scratch.delete(recursive: true));
    final steps = <Step>[];
    final ssh = _Ssh();
    final setup = HostRun(
      provider: GivenMachine(address: service.state.host.address, hostKey: service.state.host.sshHostKey),
      remote: ssh,
      emit: steps.add,
      preparation: _Setup(service),
      hostKeys: () async => ('fixture-host-private', personKey),
      environment: {'XDG_STATE_HOME': scratch.path},
    );
    expect(
      await setup.up(
        const HostPlan(
          adminLogin: 'alice',
          hostName: 'orchard',
          loginUser: 'root',
          publicKey: personKey,
          adminSigners: [personKey],
        ),
      ),
      Exit.done,
    );
    expect(ssh.commands, ['true']);
    expect(steps.singleWhere((step) => step.state == StepState.host).host?.values, service.state.host.values);
    final bring = ProjectBring(project: 'demo', machines: machines, settings: settings, actions: service);
    final join = ProjectJoin(project: 'demo', machines: machines, settings: settings, actions: service);
    addTearDown(bring.dispose);
    addTearDown(join.dispose);
    await bring.bring();
    await join.join();
    expect(bring.brought && join.joined, isTrue);
    expect(settings.projectHost('demo'), 'orchard');
    expect(service.calls, [
      'verify demo register',
      'ssh orchard',
      'verify demo register',
      'register demo',
      'verify demo join',
      'ssh orchard',
      'join demo',
    ]);
    expect(
      machines.all.where((m) => m.kind == 'host').single.identity,
      isEmpty,
      reason: 'the connection uses the person agent rather than a private key file',
    );
  }, tags: ['linux']); // HostRun protects the lifecycle directory with chmod.
}

class _Setup implements ServerPreparation {
  _Setup(this.service);
  final SignedHostFake service;
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
    expect(adminSigners, service.state.adminSigners);
    expect((name, address), (service.state.host.name, service.state.host.address));
    return service.state.host;
  }
}

class _Ssh implements Remote {
  final commands = <String>[];
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    commands.add(command);
    return const RemoteResult(0, '');
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) =>
      throw StateError('The replacement contract must not upload an old installer.');
}

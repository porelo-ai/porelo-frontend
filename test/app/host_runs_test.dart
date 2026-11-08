import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/host_admin.dart';
import '../support/host_process.dart';
import '../support/host_rental.dart';
import '../support/host_organization.dart';
import '../support/signed_host.dart';

void main() {
  late Settings settings;
  late Machines machines;
  late HostRuns runs;
  setUp(() async {
    settings = Settings(MemorySettingsStore());
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    runs = HostRuns(machines, hostAccess: access, environment: {'XDG_STATE_HOME': Directory.systemTemp.path});
  });
  tearDown(() {
    runs.dispose();
    machines.dispose();
    settings.dispose();
  });

  // Harm: an unready host is named on its card, or a card names local forward ports the host never listens on.
  test('the card takes the real values, and only once up has ended confirmed', () async {
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final readied = <String>[];
    final owner = HostRuns(
      machines,
      hostAccess: access,
      onReady: (host) async {
        readied.add(host);
      },
    );
    addTearDown(owner.dispose);
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = owner.start(project: 'orchard', record: signedSetup, session: session, settings: settings);
    process.line(const Step('up', StepState.done, address: '203.0.113.7'));
    process.line(
      Step(
        'host',
        StepState.host,
        host: PreparedHost.read(
          {
            'name': 'orchard',
            'address': '203.0.113.7',
            'ssh_host_key': hostKey,
            'services': {
              'forge': {'web_port': 3100, 'git_port': 2222},
            },
          },
          hostName: 'orchard',
          localServices: const HostPreparationSettings(forgeWebPort: 4000).localServices,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(fixture.writes, isEmpty, reason: 'a host line before process exit is not ready');
    process.end(0);
    await run.finished;
    expect(run.ready, isTrue);
    final write = fixture.writes.single;
    expect(write.change, OrganizationChange.changeHost);
    expect(write.base, fixture.revision);
    expect(write.input, {
      'host': 'orchard',
      'address': '203.0.113.7',
      'port': '22',
      'hostKey': hostKey,
      'webPort': '3100',
      'gitPort': '2222',
    });
    expect(readied, ['orchard'], reason: 'the token goes right after up, once');
    // Harm: the machine makes the person's account only on its first follow, within five minutes, and until then a
    // turned-away login read as a refusal in red.
    expect(machines.tunnels.awaitsAdmission('orchard'), isTrue, reason: 'a machine just prepared is waited for');
  });

  /// A run whose `up` ends as [up] says and whose give-back ends as [givenBack] says.
  Future<(HostPreparation, List<List<String>>, List<String>)> stopped(
    HostFixture fixture, {
    required void Function(HostProcess process) up,
    bool givenBack = true,
    HostUpRecord? record,
  }) async {
    final access = await fixture.access(settings);
    final said = <String>[];
    final owner = HostRuns(machines, hostAccess: access, say: said.add);
    addTearDown(owner.dispose);
    final started = <List<String>>[];
    final session = HostSession(
      executable: 'fake',
      arguments: const ['--host-name', 'orchard'],
      start: (_, arguments) async {
        started.add(arguments);
        final process = HostProcess();
        if (arguments.first == 'down') {
          if (givenBack) process.line(const Step('give-back', StepState.done, address: '203.0.113.7'));
          process.end(givenBack ? 0 : 65);
        } else {
          up(process);
        }
        return process;
      },
    );
    final run = owner.start(project: 'orchard', record: record ?? signedSetup, session: session, settings: settings);
    await run.finished;
    return (run, started, said);
  }

  void confirmedUp(HostProcess process) => process
    ..line(const Step('up', StepState.done, address: '203.0.113.7'))
    ..line(Step('host', StepState.host, host: PreparedHost.read(sshCompletion())))
    ..end(0);

  // Harm: a stopped setup leaves a billed server nobody was told of.
  test("up's stop keeps the server, and it is said", () async {
    final (run, started, said) = await stopped(
      HostFixture(),
      up: (process) => process
        ..line(const Step('forge', StepState.refused, fix: 'the forge did not start'))
        ..end(65),
    );
    expect(started.map((arguments) => arguments.first), ['up'], reason: 'nothing is given back unasked');
    expect(run.ready, isFalse);
    expect(settings.hostUp('orchard'), isNotNull);
    expect(said.single, allOf(contains('the forge did not start'), isNot(contains('was given back'))));
  });

  // Harm: a setup taken up again hands the host a pin from before, with a removed admin's key among those it trusts.
  test('a setup taken up again hands on the pin of that moment', () async {
    final fixture = HostFixture()..keys = const [HostAdminKey(login: 'alice', key: backupKey)];
    await stopped(
      fixture,
      record: const HostUpRecord(
        scalewayProject: 'provider',
        host: 'orchard',
        hostName: 'orchard',
        publicKey: '/keys/person.pub',
        machineFile: '/kept/orchard.yml',
      ),
      up: (process) {
        expect(fixture.machineFiles.values.single, contains(backupKey), reason: 'written before up reads it');
        process
          ..line(const Step('forge', StepState.refused, fix: 'stop'))
          ..end(65);
      },
    );
  });

  // Harm: a person's own machine, named to prepare it, has its setup torn down because a step stopped.
  test("up's stop leaves a machine the person gave as it is, and says so", () async {
    final (run, started, said) = await stopped(
      HostFixture(),
      record: HostUpRecord(
        givenAddress: '203.0.113.9',
        givenHostKey: hostKey,
        host: 'orchard',
        hostName: 'orchard',
        publicKey: '/keys/person.pub',
      ),
      up: (process) => process
        ..line(const Step('forge', StepState.refused, fix: 'the forge did not start'))
        ..end(65),
    );
    expect(started.map((arguments) => arguments.first), ['up']);
    expect(run.ready, isFalse);
    expect(said.single, allOf(contains('the forge did not start'), isNot(contains('given back'))));
  });

  // Harm: a server runs on with a card that does not name it, so nobody can ever connect to it.
  test('a card that cannot be written keeps the server, with the words why', () async {
    final fixture = HostFixture()..writeRefusal = 'the organization moved on';
    final (run, started, said) = await stopped(fixture, up: confirmedUp);
    expect(started.map((arguments) => arguments.first), ['up'], reason: 'nothing is given back unasked');
    expect(run.ready, isFalse);
    expect(settings.hostUp('orchard'), isNotNull);
    expect(said.single, allOf(contains('the organization moved on'), isNot(contains('was given back'))));
  });

  // Harm: setup run again on a working server stops once and takes everything on it away.
  test('a stop while setting a ready server up again gives nothing back', () async {
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final owner = HostRuns(machines, hostAccess: access);
    addTearDown(owner.dispose);
    var runsOfUp = 0;
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, arguments) async {
        expect(arguments.first, 'up', reason: 'nothing but up may run');
        final process = HostProcess();
        runsOfUp++ == 0 ? confirmedUp(process) : (process..line(const Step('forge', StepState.refused))).end(65);
        return process;
      },
    );
    final run = owner.start(project: 'orchard', record: signedSetup, session: session, settings: settings);
    await run.finished;
    expect(run.ready, isTrue);
    await owner.again('orchard');
    expect(runsOfUp, 2);
    expect(settings.hostUp('orchard'), isNotNull);
  });

  // Harm: incomplete or refused setup cannot become a usable server or lose recovery.
  for (final outcome in ['confirmed', 'missing card', 'refused', 'wrong host']) {
    test('$outcome setup retains recovery until SSH completion is confirmed', () async {
      final process = HostProcess();
      final run = runs.start(
        project: 'orchard',
        record: signedSetup,
        session: HostSession(
          executable: 'fake',
          arguments: const [],
          start: (_, _) async {
            expect(
              settings.hostUp('orchard')?.preparing,
              isTrue,
              reason: 'recovery must be durable before a command can rent',
            );
            return process;
          },
        ),
      );
      process.line(Step('up', outcome == 'refused' ? StepState.refused : StepState.done, address: '203.0.113.7'));
      if (outcome != 'missing card') {
        final values = hostValues();
        if (outcome == 'wrong host') values['name'] = 'elsewhere';
        process.line(Step('host', StepState.host, host: PreparedHost.read(values)));
      }
      process.end(0);
      await run.finished;
      final success = outcome == 'confirmed';
      expect(run.ready, success);
      expect(settings.hostUp('orchard')?.preparing, !success);
      expect(machines.all.where((m) => m.hostProject == 'orchard').length, success ? 1 : 0);
    });
  }
}

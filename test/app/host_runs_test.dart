import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart'
    show
        HostIdentity,
        HostIdentityExists,
        HostIdentityFailure,
        HostIdentityPublic,
        HostIdentityUnknown,
        HostIdentityUnreached,
        HostIdentityUnsupported,
        HostIdentityVaultShut;
import 'package:porelo_frontend/src/app/fleet_backend.dart' show KeepsHostIdentities;
import 'package:porelo_frontend/src/app/host_identity_export.dart' show HostIdentityExportRefused;
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

/// A setup whose `up` is handed the organization's machine file.
const _withMachineFile = HostUpRecord(
  scalewayProject: 'provider',
  host: 'orchard',
  hostName: 'orchard',
  publicKey: '/keys/person.pub',
  machineFile: '/kept/orchard.yml',
);

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

  // Harm: the identity of a server this window never connected to as a machine is never kept, and is lost with it.
  group('a server this window never connected to', () {
    late Directory scratch;
    late List<List<String>> started;
    late HostRuns owner;
    late _Identities keeper;
    late Map<String, String> environment;

    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('porelo-export-');
      started = [];
      keeper = _Identities();
      // Each system's own configuration and state directories, so the test reads the same on Linux and Windows.
      final separator = Platform.pathSeparator;
      environment = {
        'HOME': scratch.path,
        'XDG_CONFIG_HOME': '${scratch.path}${separator}config',
        'XDG_STATE_HOME': '${scratch.path}${separator}state',
        'APPDATA': '${scratch.path}${separator}config',
        'LOCALAPPDATA': '${scratch.path}${separator}state',
      };
      owner = HostRuns(
        machines,
        environment: environment,
        identities: () async => keeper,
        startExport: (program, arguments) async {
          started.add([program, ...arguments]);
          final process = HostProcess();
          scheduleMicrotask(() => process.end(1));
          return process;
        },
      );
    });
    tearDown(() async {
      owner.dispose();
      await scratch.delete(recursive: true);
    });

    test('is read as root as porelo-host reached it, by the key its record holds', () async {
      await settings.rememberHostUp(
        'orchard',
        const HostUpRecord(
          host: 'orchard',
          hostName: 'orchard',
          publicKey: '/keys/person.pub',
          givenAddress: '203.0.113.7',
          givenHostKey: hostKey,
        ).withPreparedHost(PreparedHost.read(sshCompletion())),
      );
      await owner.keepIdentity('orchard');
      final command = started.single;
      expect(command, containsAllInOrder(['HostName=203.0.113.7', 'User=root', 'orchard']));
      expect(command, contains('-F'));
      expect(command, isNot(contains('/dev/null')));
      expect(command, contains('StrictHostKeyChecking=yes'));
    });

    // Harm: a computer whose configuration directory cannot be named refuses a server its record pins.
    test('is read by its record where this computer names no configuration directory', () async {
      await settings.rememberHostUp(
        'orchard',
        const HostUpRecord(
          host: 'orchard',
          hostName: 'orchard',
          publicKey: '/keys/person.pub',
          givenAddress: '203.0.113.7',
          givenHostKey: hostKey,
        ).withPreparedHost(PreparedHost.read(sshCompletion())),
      );
      final bare = HostRuns(
        machines,
        environment: const {},
        identities: () async => keeper,
        startExport: (program, arguments) async {
          started.add([program, ...arguments]);
          final process = HostProcess();
          scheduleMicrotask(() => process.end(1));
          return process;
        },
      );
      addTearDown(bare.dispose);
      await bare.keepIdentity('orchard');
      expect(started.single, containsAllInOrder(['HostName=203.0.113.7', 'User=root', 'orchard']));
    });

    test('a card host is read as root through its card, on a connection of its own', () async {
      final config = File(poreloHostSshConfig('orchard', environment: environment));
      await config.parent.create(recursive: true);
      await config.writeAsString('Host orchard\n');
      await owner.keepIdentity('orchard');
      final command = started.single;
      expect(command, containsAllInOrder(['-F', config.path, 'ControlPath=none', 'ProxyCommand=none', 'root@orchard']));
    });
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

  // Harm: the protocol stays empty while the organization, read for this start a moment ago, is read twice more
  // before the machine's command starts; each read may wait up to a minute on the forge.
  test('a start the caller has just read the organization for starts up without reading it again', () async {
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final owner = HostRuns(machines, hostAccess: access);
    addTearDown(owner.dispose);
    await access.machineFile('orchard');
    final before = fixture.reads;
    int? readsAtUp;
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async {
        readsAtUp = fixture.reads - before;
        return HostProcess()..end(65);
      },
    );
    final run = owner.start(
      project: 'orchard',
      record: _withMachineFile,
      session: session,
      settings: settings,
      organizationReadJustNow: true,
    );
    await run.finished;
    expect(readsAtUp, 0, reason: 'the read the caller made a moment ago stands for this start');
  });

  // Harm: a protocol whose command has not said its first line yet stays black and empty, and reads as stuck.
  test('a start waits for its first line until the command says one', () async {
    final process = HostProcess();
    final started = Completer<Process>();
    final run = runs.start(
      project: 'orchard',
      record: signedSetup,
      session: HostSession(executable: 'fake', arguments: const [], start: (_, _) => started.future),
    );
    expect(run.waitsForFirstLine, isTrue, reason: 'nothing was said while the window reads and writes before up');
    await Future<void>.delayed(Duration.zero);
    started.complete(process);
    await Future<void>.delayed(Duration.zero);
    expect(run.waitsForFirstLine, isTrue, reason: 'a started command that said nothing has no line yet');
    process.line(const Step('rent', StepState.started, text: 'Take the server as given'));
    await Future<void>.delayed(Duration.zero);
    expect(run.waitsForFirstLine, isFalse);
    process.end(65);
    await run.finished;
    expect(run.waitsForFirstLine, isFalse, reason: 'an ended run waits for nothing');
  });

  // Harm: a setup taken up again waits on two reads of the organization where one proves the same.
  test('a setup taken up again reads the organization once before up', () async {
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final owner = HostRuns(machines, hostAccess: access);
    addTearDown(owner.dispose);
    final before = fixture.reads;
    int? readsAtUp;
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async {
        readsAtUp = fixture.reads - before;
        return HostProcess()..end(65);
      },
    );
    await owner.start(project: 'orchard', record: _withMachineFile, session: session, settings: settings).finished;
    expect(readsAtUp, 1, reason: 'writing the machine file reads the organization, and that read is the check');
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

  group('a given server whose identity the vault keeps', () {
    const given = HostUpRecord(
      host: 'orchard',
      hostName: 'orchard',
      publicKey: '/keys/person.pub',
      givenAddress: '203.0.113.7',
      givenHostKey: hostKey,
    );
    late _Identities keeper;
    late HostRuns owner;
    late List<List<String>> started;
    late List<String> handed;

    setUp(() async {
      keeper = _Identities();
      owner = HostRuns(
        machines,
        hostAccess: await HostFixture().access(settings),
        identities: () async => keeper,
        exportIdentity: (_) async => _identity,
      );
      started = [];
      handed = [];
    });
    tearDown(() => owner.dispose());

    HostSession session(void Function(HostProcess process) up) => HostSession(
      executable: 'fake',
      arguments: const ['--host-name', 'orchard'],
      start: (_, arguments) async {
        started.add(arguments);
        final process = _Taking(handed);
        up(process);
        return process;
      },
    );

    void refused(HostProcess process) => (process..line(const Step('forge', StepState.refused, fix: 'stop'))).end(65);

    // Harm: the next setup or give-back pins the key given for the first login, which the server no longer answers
    // with, and every later login to it is refused, or goes to a machine that took its old key.
    test("a server set up with its identity is set up again and given back by the identity's key", () async {
      const identityKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
      keeper.kept['orchard'] = HostIdentity.read(<String, dynamic>{
        ..._identity.wire,
        'ssh_host_keys': [
          <String, dynamic>{'type': 'ed25519', 'public': '$identityKey root@orchard', 'private': 'SECRET-HOST'},
        ],
      });
      final run = owner.start(
        project: 'orchard',
        record: given,
        session: HostSession(
          executable: 'fake',
          arguments: given.arguments('orchard'),
          start: (_, arguments) async {
            started.add(arguments);
            final process = _Taking(handed);
            process
              ..line(const Step('up', StepState.done, address: '203.0.113.7'))
              ..line(
                Step(
                  'host',
                  StepState.host,
                  host: PreparedHost.read({...sshCompletion(), 'ssh_host_key': identityKey}),
                ),
              )
              ..end(0);
            return process;
          },
        ),
        settings: settings,
      );
      await run.finished;
      expect(run.ready, isTrue, reason: '${run.problem}');
      await owner.keepingSettled;
      final kept = settings.hostUp('orchard')!;
      expect(kept.giveBackArguments('orchard'), containsAllInOrder(['--host-key', identityKey]));
      expect(kept.arguments('orchard'), containsAllInOrder(['--host-key', identityKey]));
      await owner.again('orchard');
      expect(started, hasLength(2));
      expect(started.last, containsAllInOrder(['--host-key', identityKey]));
      expect(started.last, isNot(contains(hostKey)));
    });

    // Harm: a host set up anew under keys the forge does not know, while the vault kept the ones it does; or the
    // identity in an argument, where any process on this computer reads it.
    test('reaches the command on its standard input alone, at start, resume and again', () async {
      keeper.kept['orchard'] = _identity;
      var ups = 0;
      final run = owner.start(
        project: 'orchard',
        record: given,
        session: session((process) => ups++ == 0 ? refused(process) : confirmedUp(process)),
        settings: settings,
      );
      await run.finished;
      await owner.resume(run);
      expect(run.ready, isTrue, reason: '${run.problem}');
      await owner.again('orchard');
      expect(started, hasLength(3));
      for (final arguments in started) {
        expect(arguments, contains('--identity-stdin'));
        expect(arguments.join(' '), isNot(contains('SECRET')));
      }
      expect(handed, List.filled(3, _identity.json));
    });

    // Harm: a first setup waits on a standard input nobody writes, or is handed something.
    test('with none kept, the command starts without it and its input closes empty', () async {
      final run = owner.start(project: 'orchard', record: given, session: session(confirmedUp), settings: settings);
      await run.finished;
      expect(started.single, isNot(contains('--identity-stdin')));
      expect(handed, ['']);
    });

    // Harm: a start refused for its identity is kept as a setup under way, and the next window says it was
    // interrupted; or the refusal shows nowhere once its words scrolled by.
    test('a start refused for its identity leaves no setup under way, and says why on the run', () async {
      keeper.failure = const HostIdentityVaultShut();
      final run = owner.start(project: 'orchard', record: given, session: session(confirmedUp), settings: settings);
      await run.finished;
      expect(started, isEmpty);
      expect(settings.hostUp('orchard')?.preparing ?? false, isFalse);
      expect(run.session.state, HostRunState.refused);
      expect(run.session.fix, contains('Porelo-Vault is shut'));
      final next = HostRuns(machines, hostAccess: await HostFixture().access(settings));
      addTearDown(next.dispose);
      expect(next.of('orchard'), isNull, reason: 'nothing to take up again after a restart');
    });

    // Harm: a daemon connection that cannot open throws past the start, which then hangs half begun.
    test('a vault that cannot be opened at all is not reached, and nothing starts', () async {
      final unopened = HostRuns(
        machines,
        hostAccess: await HostFixture().access(settings),
        identities: () async => throw StateError('the connection is closed'),
      );
      addTearDown(unopened.dispose);
      final run = unopened.start(project: 'orchard', record: given, session: session(confirmedUp), settings: settings);
      await run.finished;
      expect(started, isEmpty);
      expect(run.problem, contains('did not answer'));
    });

    // Harm: a vault that could not be asked is taken for one that keeps nothing, and the host is set up anew.
    for (final failure in const <HostIdentityFailure>[
      HostIdentityVaultShut(),
      HostIdentityUnsupported(),
      HostIdentityUnreached('gone'),
    ]) {
      test('${failure.runtimeType} keeps the command from starting, and says why', () async {
        keeper.failure = failure;
        final run = owner.start(project: 'orchard', record: given, session: session(confirmedUp), settings: settings);
        await run.finished;
        expect(started, isEmpty);
        expect(run.problem, contains(failure.words));
      });
    }
  });

  group("a server's identity kept in this computer's vault", () {
    const given = HostUpRecord(
      host: 'orchard',
      hostName: 'orchard',
      publicKey: '/keys/person.pub',
      givenAddress: '203.0.113.7',
      givenHostKey: hostKey,
    );
    late _Identities keeper;
    late HostRuns owner;
    late List<String> exported;
    late Future<HostIdentity> Function(String host) export;

    setUp(() async {
      keeper = _Identities();
      exported = [];
      export = (host) async => _identity;
      owner = HostRuns(
        machines,
        hostAccess: await HostFixture().access(settings),
        identities: () async => keeper,
        exportIdentity: (host) {
          exported.add(host);
          return export(host);
        },
      );
    });
    tearDown(() => owner.dispose());

    Future<void> setUpDone() async {
      final run = owner.start(
        project: 'orchard',
        record: given,
        session: HostSession(
          executable: 'fake',
          arguments: const ['--host-name', 'orchard'],
          start: (_, _) async {
            final process = HostProcess();
            confirmedUp(process);
            return process;
          },
        ),
        settings: settings,
      );
      await run.finished;
      expect(run.ready, isTrue, reason: '${run.problem}');
      await owner.keepingSettled;
    }

    // Harm: a row that says the identity is not kept vanishes while the keeping asked again still runs, and says
    // nothing if that one fails too.
    for (final (name, fails) in [('kept', false), ('failing again', true)]) {
      test('a row not kept stays, busy, while it is kept again, until that keeping is $name', () async {
        keeper.keepFailure = const HostIdentityVaultShut();
        await owner.keepIdentity('orchard');
        expect(owner.identitiesNotKept.map((each) => each.host), ['orchard']);
        if (!fails) keeper.keepFailure = null;
        final held = Completer<HostIdentity>();
        export = (_) => held.future;
        final again = owner.keepIdentity('orchard');
        await Future<void>.delayed(Duration.zero);
        expect(owner.identitiesNotKept.map((each) => each.host), ['orchard'], reason: 'the row stays');
        expect(owner.keepingIdentities, ['orchard'], reason: 'marked busy');
        held.complete(_identity);
        await again;
        expect(owner.identitiesNotKept.map((each) => each.host), fails ? ['orchard'] : isEmpty);
      });
    }

    // Harm: a replace the person asked for while a keeping ran is dropped, and the other identity stays kept.
    test('a replace asked while a keeping runs follows it, and replaces', () async {
      final held = Completer<HostIdentity>();
      export = (_) => held.future;
      final first = owner.keepIdentity('orchard');
      final replacing = owner.keepIdentity('orchard', replace: true);
      held.complete(_identity);
      await first;
      export = (_) async => _identity;
      await replacing;
      expect(keeper.keeps, [('orchard', false), ('orchard', true)]);
    });

    // Harm: a server given back keeps its row in Needs you, which offers to keep an identity that is gone.
    test('a server given back leaves no keeping row', () async {
      await setUpDone();
      keeper.keepFailure = const HostIdentityVaultShut();
      await owner.keepIdentity('orchard');
      expect(owner.identitiesNotKept, isNotEmpty);
      final givenBack = HostProcess()
        ..line(const Step('give-back', StepState.done))
        ..end(0);
      final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => givenBack);
      addTearDown(session.dispose);
      await session.down();
      await owner.confirmDown('orchard', session);
      expect(owner.identitiesNotKept, isEmpty);
      expect(owner.keepingOf('orchard'), isNull);
    });

    // Harm: the window closes while a keeping runs, and the server's keys never reach the vault.
    test('leaving waits for a keeping that runs', () async {
      final held = Completer<HostIdentity>();
      export = (_) => held.future;
      final keeping = owner.keepIdentity('orchard');
      var left = false;
      final leaving = owner.leave().then((_) => left = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(left, isFalse);
      held.complete(_identity);
      await keeping;
      await leaving;
      expect(keeper.kept['orchard'], isNotNull);
    });

    // Harm: a keeping started while the window closes is cut off, or outlives the window and its vault.
    test('no keeping starts once leaving began, or after the end', () async {
      await owner.leave();
      expect(await owner.keepIdentity('orchard'), isNull);
      expect(exported, isEmpty);
    });

    // Harm: a server's keys exist only on the server, and are lost with it; the central forge keeps keys nobody has.
    test('an up that ended done keeps the identity the server holds', () async {
      await setUpDone();
      expect(exported, ['orchard']);
      expect(keeper.kept['orchard']?.json, _identity.json);
      expect(keeper.keeps, [('orchard', false)]);
      expect(owner.keepingOf('orchard')?.state, IdentityKeepingState.kept);
      expect(owner.identitiesNotKept, isEmpty);
    });

    // Harm: a stored identity is overwritten unasked, or one that could not be kept is never said.
    test('another identity kept already raises a row, and only replacing asked for replaces it', () async {
      keeper.keepFailure = const HostIdentityExists('orchard');
      await setUpDone();
      expect(owner.keepingOf('orchard')?.state, IdentityKeepingState.conflict);
      expect(owner.identitiesNotKept.single.host, 'orchard');
      expect(keeper.keeps, [('orchard', false)]);
      keeper.keepFailure = null;
      expect((await owner.keepIdentity('orchard', replace: true))?.state, IdentityKeepingState.kept);
      expect(keeper.keeps, [('orchard', false), ('orchard', true)]);
      expect(owner.identitiesNotKept, isEmpty);
    });

    // Harm: a host that could not be read, or a shut vault, is taken for a kept identity.
    for (final vault in [false, true]) {
      test(
        '${vault ? 'a shut vault' : 'a refused export'} raises a row with why; keeping it again clears it',
        () async {
          if (vault) {
            keeper.keepFailure = const HostIdentityVaultShut();
          } else {
            export = (_) async => throw const HostIdentityExportRefused('orchard did not answer within 30 seconds.');
          }
          await setUpDone();
          final row = owner.identitiesNotKept.single;
          expect(row.state, IdentityKeepingState.refused);
          expect(row.why, vault ? contains('shut') : contains('did not answer'));
          keeper.keepFailure = null;
          export = (_) async => _identity;
          await owner.keepIdentity('orchard');
          expect(owner.identitiesNotKept, isEmpty);
        },
      );
    }

    // Harm: give-up is offered for a host this computer keeps nothing of, while its vault is shut, or while a setup or
    // a keeping of it runs and would write the identity again.
    test('giving a host up is offered only where the vault keeps its identity and nothing of it runs', () async {
      expect(owner.whyNotGiveUp('orchard'), contains('not read yet'));
      keeper.failure = const HostIdentityVaultShut();
      await owner.readIdentitiesHere();
      expect(owner.whyNotGiveUp('orchard'), contains('shut'));
      keeper.failure = null;
      keeper.kept['orchard'] = _identity;
      await owner.readIdentitiesHere();
      expect(owner.identitiesHere, ['orchard']);
      expect(owner.whyNotGiveUp('orchard'), isNull);
      expect(owner.whyNotGiveUp('lemon'), 'your Porelo-Vault keeps no identity of lemon');
      final held = Completer<HostIdentity>();
      export = (_) => held.future;
      final keeping = owner.keepIdentity('orchard');
      await Future<void>.delayed(Duration.zero);
      expect(owner.whyNotGiveUp('orchard'), contains('being kept'));
      held.complete(_identity);
      await keeping;
      final process = HostProcess();
      final run = owner.start(
        project: 'orchard',
        record: given,
        session: HostSession(
          executable: 'fake',
          arguments: const ['--host-name', 'orchard'],
          start: (_, _) async => process,
        ),
        settings: settings,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(owner.whyNotGiveUp('orchard'), contains('setup is running'));
      confirmedUp(process);
      await run.finished;
      await owner.keepingSettled;
    });

    // Harm: a second give-up starts while the first still waits for its result, or a host given up keeps its row
    // offering to keep an identity that is gone.
    test('a give-up running is said, and one that ended all gone leaves no keeping row', () async {
      keeper.kept['orchard'] = _identity;
      await owner.readIdentitiesHere();
      keeper.keepFailure = const HostIdentityVaultShut();
      await owner.keepIdentity('orchard');
      expect(owner.identitiesNotKept, isNotEmpty);
      expect(owner.beginGiveUp('orchard'), isTrue);
      expect(owner.beginGiveUp('orchard'), isFalse, reason: 'one at a time');
      expect(owner.whyNotGiveUp('orchard'), 'it is being given up now');
      keeper.kept.remove('orchard');
      await owner.endGiveUp('orchard', allGone: true);
      expect(owner.whyNotGiveUp('orchard'), 'your Porelo-Vault keeps no identity of orchard');
      expect(owner.identitiesNotKept, isEmpty);
      expect(owner.keepingOf('orchard'), isNull);
    });

    test('a give-up that did not end all gone keeps the row', () async {
      keeper.keepFailure = const HostIdentityVaultShut();
      await owner.keepIdentity('orchard');
      expect(owner.beginGiveUp('orchard'), isTrue);
      await owner.endGiveUp('orchard', allGone: false);
      expect(owner.identitiesNotKept, isNotEmpty);
      expect(owner.beginGiveUp('orchard'), isTrue, reason: 'it may be run again');
    });

    // Harm: an older read answers last and the list shows hosts given up, or misses one just kept.
    test('an older read of the kept identities never overwrites a newer one', () async {
      final slow = Completer<List<String>>();
      keeper.answers.add(slow.future);
      final older = owner.readIdentitiesHere();
      keeper.kept['orchard'] = _identity;
      await owner.readIdentitiesHere();
      expect(owner.identitiesHere, ['orchard']);
      slow.complete(const []);
      await older;
      expect(owner.identitiesHere, ['orchard']);
    });

    // Harm: closing the window cuts a keeping short, and the server's keys never reach the vault.
    test('leaving waits for a keeping that runs', () async {
      final held = Completer<HostIdentity>();
      export = (_) => held.future;
      final keeping = owner.keepIdentity('orchard');
      await Future<void>.delayed(Duration.zero);
      expect(owner.keepingIdentities, ['orchard']);
      var left = false;
      unawaited(owner.leave().then((_) => left = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(left, isFalse);
      held.complete(_identity);
      await keeping;
      await Future<void>.delayed(Duration.zero);
      expect(left, isTrue);
      expect(owner.keepingIdentities, isEmpty);
    });
  });
}

/// A host's identity as the vault hands it on; its private halves are stand-ins a test looks for.
final _identity = HostIdentity.read(<String, dynamic>{
  'host': 'orchard',
  'organization': <String, dynamic>{'public': 'ssh-ed25519 AAAAorganization', 'private': 'SECRET-ORGANIZATION'},
  'repositories': const <Object>[],
  'ssh_host_keys': <Map<String, dynamic>>[
    <String, dynamic>{'type': 'ed25519', 'public': 'ssh-ed25519 AAAAhost', 'private': 'SECRET-HOST'},
  ],
});

/// This computer's vault, keeping what the test puts in it, or failing as it says.
class _Identities implements KeepsHostIdentities {
  final kept = <String, HostIdentity>{};
  HostIdentityFailure? failure;

  /// A failure of keeping alone, as a vault that keeps another identity answers.
  HostIdentityFailure? keepFailure;

  /// Answers for the next lists asked for, each in its turn, before the kept hosts are listed.
  final answers = <Future<List<String>>>[];

  /// Each keeping asked for, by host and whether it replaces.
  final keeps = <(String, bool)>[];

  HostIdentity _of(String host) {
    if (failure case final failed?) throw failed;
    return kept[host] ?? (throw HostIdentityUnknown(host));
  }

  @override
  Future<HostIdentity> hostIdentityRead(String host) async => _of(host);

  @override
  Future<HostIdentityPublic> hostIdentityPublic(String host) async => HostIdentityPublic.read(_of(host).wire);

  @override
  Future<void> hostIdentityKeep(String host, HostIdentity identity, {bool replace = false}) async {
    keeps.add((host, replace));
    if (failure ?? keepFailure case final failed?) throw failed;
    kept[host] = identity;
  }

  @override
  Future<List<String>> hostIdentities() async {
    if (failure case final failed?) throw failed;
    if (answers.isNotEmpty) return answers.removeAt(0);
    return kept.keys.toList();
  }
}

/// A host command whose standard input is kept, as one text, once it is closed.
class _Taking extends HostProcess {
  _Taking(this.handed) {
    final input = StreamController<List<int>>();
    _taken = IOSink(input.sink);
    unawaited(input.stream.expand((chunk) => chunk).toList().then((bytes) => handed.add(utf8.decode(bytes))));
  }

  final List<String> handed;
  late final IOSink _taken;

  @override
  IOSink get stdin => _taken;
}

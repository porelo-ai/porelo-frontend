// Linux only: the replacement lock guard runs a Dart child using POSIX file locks and chmod.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_process.dart';
import '../support/host_rental.dart';
import '../support/host_admin.dart';

class _Tunnels extends Tunnels {
  final requested = <Machine>[];
  @override
  Future<bool> raiseFor(Machine machine) async {
    requested.add(machine);
    return true;
  }
}

class _RestoredRuns extends HostRuns {
  _RestoredRuns(super.machines, {super.setupAgain, super.environment});
  final commands = <List<String>>[];
  @override
  HostSession sessionFor(String project, HostUpRecord record) => HostSession(
    executable: 'fake',
    arguments: record.giveBackArguments(project),
    start: (_, arguments) async {
      commands.add(arguments);
      final process = HostProcess();
      process.end(65);
      return process;
    },
  );
}

Future<({Settings settings, Machines machines, HostRuns runs, _Tunnels tunnels})> _restore({
  Future<HostUpRecord> Function(String, HostUpRecord)? setupAgain,
}) async {
  final settings = Settings(
    MemorySettingsStore({
      'hostUps': {'demo': legacyRental()},
      'machines': [
        const Machine(
          name: 'demo server',
          kind: 'host',
          hostProject: 'demo',
          host: 'worker@203.0.113.7',
          remoteSocket: '/run/user/1007/porelo/porelod.sock',
          socketPath: '/unused',
          identity: '/keys/old-private',
        ).stored,
      ],
    }),
  );

  await settings.load();
  final tunnels = _Tunnels();
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);

  await machines.load();
  final runs = _RestoredRuns(
    machines,
    setupAgain: setupAgain,
    environment: {'XDG_STATE_HOME': Directory.systemTemp.path},
  );

  await runs.of('demo')!.checked.timeout(const Duration(seconds: 5));

  return (settings: settings, machines: machines, runs: runs, tunnels: tunnels);
}

void main() {
  setUp(() {
    roles = Roles.fromArguments(const ['--roles', 'host-admin']);
  });
  tearDown(() {
    roles = const Roles();
  });
  void dispose(({Settings settings, Machines machines, HostRuns runs, _Tunnels tunnels}) state) {
    state.runs.dispose();
    state.machines.dispose();
    state.settings.dispose();
    state.tunnels.dispose();
  }

  // Harm: give-back in another process must not release a server during replacement setup.
  test('replacement setup holds the original rental lock against a competing process', () async {
    final scratch = await Directory.systemTemp.createTemp('replacement-lock-');
    addTearDown(() => scratch.delete(recursive: true));
    int? competingExit;
    final state = await _restore(
      setupAgain: (_, existing) async {
        final sdk = Platform.environment['FLUTTER_ROOT']!;
        final child = await Process.run(
          '$sdk/bin/cache/dart-sdk/bin/dart',
          [
            '--packages=${Directory.current.path}/.dart_tool/package_config.json',
            'packages/porelo_host/test/support/host_lock_process.dart',
            scratch.path,
            'contender',
            'down',
            'demo',
            'go',
          ],
          environment: {'XDG_STATE_HOME': Directory.systemTemp.path},
        );
        competingExit = child.exitCode;
        return existing;
      },
    );
    addTearDown(() => dispose(state));
    await state.runs.again('demo');
    expect(
      competingExit,
      host.Exit.waiting,
      reason: 'the provider must remain locked for the whole replacement callback',
    );
    expect(await File('${scratch.path}/contender-find').exists(), isFalse);
    expect(state.settings.hostUp('demo')!.legacy, isTrue);
  });

  // Harm: restarting must not resume obsolete setup or connect with its old credentials.
  testWidgets('an old rental stays listed without resuming its old command', (tester) async {
    final state = (await tester.runAsync(_restore))!;
    addTearDown(() => dispose(state));
    await tester.runAsync(() => state.runs.resume(state.runs.of('demo')!));

    expect(
      state.tunnels.requested.where((m) => m.kind == 'host'),
      isEmpty,
      reason: 'restoring the machine must not open its obsolete credentials',
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MachinesPage(
            machines: state.machines,
            hostRuns: state.runs,
            onAdd: () {},
            onDetails: (_) {},
            onForget: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('demo server'), findsWidgets, reason: 'the paid server must remain visible');
    final run = state.runs.of('demo')!;
    expect(hostRecoveryCommands(run: run, goOn: () {}, takeDown: () {}).map((c) => c.id), [
      'host.again',
      'host.takeDown',
    ]);
    expect(state.settings.hostUp('demo'), isNotNull);
    expect((state.runs as _RestoredRuns).commands, isEmpty, reason: 'Go on must never invoke legacy up');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: failed or interrupted give-back must not lose the only record of a billed server.
  for (final confirmed in [false, true]) {
    testWidgets('${confirmed ? 'confirmed' : 'refused'} give-back ${confirmed ? 'clears' : 'keeps'} the rental', (
      tester,
    ) async {
      final state = (await tester.runAsync(_restore))!;
      addTearDown(() => dispose(state));
      final before = state.settings.hostUp('demo')!.stored;
      final process = HostProcess();
      final commands = <List<String>>[];
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HostDialog(
            project: 'demo',
            machines: state.machines,
            settings: state.settings,
            hostRuns: state.runs,
            takeDownOnly: true,
            start: (_, arguments) async {
              commands.add(arguments);
              return process;
            },
          ),
        ),
      );
      expect(commands, isEmpty, reason: 'opening give-back cannot delete a rental');
      await tester.tap(find.byKey(const Key('host-confirm-down')));
      await World.settle(tester);
      process.line(host.Step('give-back', confirmed ? host.StepState.done : host.StepState.refused));
      process.end(confirmed ? 0 : 65);
      await World.settle(tester);
      expect(commands.single, containsAllInOrder(['down', '--project', 'demo']));
      expect(commands.single, contains('--legacy-rental'));
      expect(commands.single, contains('--give-back-anyway'));
      expect(commands.single, isNot(contains('--identity')));
      if (confirmed) {
        expect(state.settings.hostUp('demo'), isNull);
        expect(state.machines.all.where((m) => m.hostProject == 'demo'), isEmpty);
      } else {
        expect(state.settings.hostUp('demo')!.stored, before);
        expect(state.machines.all.where((m) => m.hostProject == 'demo'), hasLength(1));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: setup again must target the existing rental and retain recovery until completion.
  test('setup again passes the existing rental without replacing recovery while pending', () async {
    final done = Completer<void>();
    HostUpRecord? passed;
    final entered = Completer<void>();
    final state = await _restore(
      setupAgain: (project, record) async {
        expect(project, 'demo');
        passed = record;
        entered.complete();
        await done.future;
        return HostUpRecord(
          scalewayProject: 'provider',
          host: 'demo',
          hostName: 'orchard',
          rentalTag: record.rentalTagFor(project),
          publicKey: '/keys/person.pub',
          preparedHost: host.PreparedHost.read(hostValues()),
        );
      },
    );
    addTearDown(() => dispose(state));
    final before = state.settings.hostUp('demo')!.stored;
    final attempt = state.runs.again('demo');
    await entered.future;
    expect(passed?.scalewayProject, 'provider');
    expect(state.settings.hostUp('demo')!.stored, before);
    done.complete();
    await attempt;
    expect(state.settings.hostUp('demo')!.legacy, isFalse);
    expect(state.settings.hostUp('demo')!.rentalTag, 'porelo-project=demo');
  });

  // Harm: a failed replacement must not erase the existing rental or switch to another provider tag.
  test('a refused replacement retains the original rental identity', () async {
    final state = await _restore(
      setupAgain: (_, _) async => HostUpRecord(
        scalewayProject: 'provider',
        host: 'demo',
        hostName: 'orchard',
        publicKey: '/keys/person.pub',
        rentalTag: 'porelo-host=another',
        preparedHost: host.PreparedHost.read(hostValues()),
      ),
    );
    addTearDown(() => dispose(state));
    final before = state.settings.hostUp('demo')!.stored;
    await state.runs.again('demo');
    expect(state.settings.hostUp('demo')!.stored, before);
    expect(state.runs.of('demo')!.legacy, isTrue);
  });

  // Harm: an unconfirmed command exit must not be interpreted as provider deletion.
  test('exit zero without the provider give-back line retains recovery', () async {
    final state = await _restore();
    addTearDown(() => dispose(state));
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    addTearDown(session.dispose);
    final pending = session.down();
    process.end(0);
    await pending;
    await state.runs.confirmDown('demo', session);
    expect(state.settings.hostUp('demo'), isNotNull);
  });
}

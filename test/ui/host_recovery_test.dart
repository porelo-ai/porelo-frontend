@TestOn('linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/host_stop_dialog.dart';
import 'package:porelo_frontend/src/ui/leaving.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

const _record = HostUpRecord(
  scalewayProject: 'provider',
  account: 'worker',
  tresor: 'drive',
  identity: '/keys/private',
  publicKey: '/keys/public',
  folder: null,
  collection: '',
  signingKey: '',
  vpnPeerPublicKey: '',
  vpnPeerAddress: '',
);

// The fixture must use the SDK paired with the engine rather than dart from PATH.
final _cache = File(Platform.resolvedExecutable).parent.parent.parent.parent;
final _dart = '${_cache.path}/dart-sdk/bin/dart';

Future<Process> _child(String phase, String lock) =>
    Process.start(_dart, ['test/support/locked_host.dart', phase, lock]);

Future<void> _until(HostRuns runs, bool Function() condition) async {
  if (condition()) return;
  final done = Completer<void>();
  void changed() {
    if (condition() && !done.isCompleted) done.complete();
  }

  runs.addListener(changed);
  try {
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    runs.removeListener(changed);
  }
}

void main() {
  late Directory scratch;
  late Settings settings;
  late Machines machines;
  final owners = <HostRuns>[];
  final children = <Process>[];
  late Map<String, String> environment;
  String getLock() => poreloHostProjectLock('demo', environment: environment);

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-recovery-');
    environment = {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path};
    settings = Settings(MemorySettingsStore());
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
  });
  tearDown(() async {
    for (final owner in owners) {
      owner.dispose();
    }
    owners.clear();
    for (final child in children) {
      child.kill();
      await child.exitCode.timeout(const Duration(seconds: 5));
    }
    children.clear();
    machines.dispose();
    settings.dispose();
    await scratch.delete(recursive: true);
  });

  Future<_RestoredRuns> restored(StartHostCommand start, {_ProbeGate? gate}) async {
    await settings.rememberHostUp('demo', _record.withPreparation(DateTime.utc(2000)));
    final runs = _RestoredRuns(machines, environment, start, gate);
    owners.add(runs);
    return runs;
  }

  // Harm: a forgotten interrupted preparation keeps billing without a reachable way to resume it.
  testWidgets('Needs you resumes the interrupted server from its own row', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final commands = <List<String>>[];
    final process = HostProcess();
    final runs = (await tester.runAsync(
      () => restored((_, args) async {
        commands.add(List.of(args));
        return process;
      }),
    ))!;
    await tester.runAsync(() => runs.of('demo')!.checked);
    final attention = Attention(machines)..hostRuns = runs;
    addTearDown(attention.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttentionView(
            attention: attention,
            onDecide: (_, _, {required allow}) {},
            onReview: (_) {},
            actionsFor: (_) => [],
          ),
        ),
      ),
    );
    expect(
      attention.openRows.where((row) => row.kind == AttentionKind.host),
      hasLength(1),
      reason: 'the rented server must be reachable from Needs you',
    );
    final row = find.byKey(
      ValueKey('attention-row ${attention.openRows.firstWhere((row) => row.kind == AttentionKind.host).id}'),
    );
    final goOn = find.descendant(of: row, matching: find.text('Go on'));
    expect(goOn, findsOneWidget, reason: 'recovery must act directly on the interrupted server');
    await tester.tap(goOn);
    await World.settle(tester);
    expect(commands, [
      ['up', ...hostArguments(_record, 'demo')],
    ], reason: 'Go on must reuse the kept server identity');
    expect(
      attention.openRows.where((row) => row.kind == AttentionKind.host),
      isEmpty,
      reason: 'resuming resolves the interrupted recovery row',
    );
    expect(
      attention.recentlyResolved.where((row) => row.row.kind == AttentionKind.host),
      hasLength(1),
      reason: 'the resolved row must retain the billed server identity',
    );
    process.line(const Step('person', StepState.waiting, needs: ['drive']));
    process.end(75);
    await World.settle(tester);
    await runs.of('demo')!.finished;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final phase in ['rent', 'play']) {
    // Harm: Leave can orphan a renting command or terminate setup already modifying the server.
    testWidgets('Leave ${phase == 'rent' ? 'during' : 'after'} rent respects the up process lifetime', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final runs = HostRuns(machines, environment: environment);
      owners.add(runs);
      late Process child;
      var exited = false;
      final run = (await tester.runAsync(
        () async => runs.start(
          project: 'demo',
          record: _record,
          session: HostSession(
            executable: 'stand-in',
            arguments: const [],
            start: (_, _) async {
              child = await _child(phase, getLock());
              children.add(child);
              unawaited(child.exitCode.then((_) => exited = true));
              return child;
            },
          ),
        ),
      ))!;
      await tester.runAsync(() => _until(runs, () => run.session.steps.any((step) => step.step == phase)));
      late Future<bool> closing;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  closing = confirmQuit(
                    context,
                    running: [],
                    waiting: 0,
                    preparing: ['demo'],
                    continuingSetup: phase == 'play' ? ['demo'] : [],
                    onLeave: runs.leave,
                  );
                },
                child: const Text('Close'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Close'));
      await World.settle(tester);
      await tester.tap(find.text('Leave'));
      await tester.runAsync(() async {
        await child.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => -1);
      });
      await World.settle(tester);
      expect(exited, phase == 'rent', reason: 'only an up before its rent completion may be terminated');
      expect(await closing, isTrue, reason: 'Leave stays allowed in either setup phase');
      if (phase == 'play') child.kill();
      await tester.runAsync(() => run.finished);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: closing after an ignored termination request leaves setup renting unseen in the background.
  testWidgets('Leave keeps the window open when a renting process does not exit', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final runs = HostRuns(machines, environment: environment);
    owners.add(runs);
    final process = _UnstoppableProcess();
    final run = runs.start(
      project: 'demo',
      record: _record,
      session: HostSession(executable: 'stand-in', arguments: const [], start: (_, _) async => process),
    );
    await World.settle(tester);
    late Future<bool> closing;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                closing = confirmQuit(context, running: [], waiting: 0, preparing: ['demo'], onLeave: runs.leave);
                unawaited(closing.then((_) => closed = true));
              },
              child: const Text('Close'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Close'));
    await World.settle(tester);
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await World.settle(tester);
    expect(closed, isFalse, reason: 'dismissal must not abandon the exit check after Leave was chosen');
    await tester.pump(const Duration(seconds: 3));
    await World.settle(tester);
    expect(closed, isFalse, reason: 'an unconfirmed exit must keep the interface open');
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'the failed termination needs an answer in its own place');
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Leave')).onPressed,
      isNotNull,
      reason: 'a failed exit must allow another explicit attempt',
    );
    process.end(65);
    await World.settle(tester);
    await run.finished;
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    expect(await closing, isFalse, reason: 'Cancel must leave recovery available');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: misreading another process as interrupted can start a second setup while the first modifies the server.
  testWidgets('startup finds another process and polls without starting up or asking for a host stop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Process holder;
    await tester.runAsync(() async {
      holder = await _child('hold', getLock());
      children.add(holder);
      expect(
        await holder.stdout.transform(utf8.decoder).transform(const LineSplitter()).first,
        'locked',
        reason: 'the other process must confirm its real exclusive lock before restoration',
      );
    });
    var starts = 0;
    final runs = (await tester.runAsync(
      () => restored((_, _) async {
        starts++;
        return HostProcess()..end(65);
      }),
    ))!;
    await tester.runAsync(() => runs.of('demo')!.checked);
    final run = runs.of('demo')!;
    final attention = Attention(machines)..hostRuns = runs;
    addTearDown(attention.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: runs,
            builder: (_, _) =>
                MachinesPage(machines: machines, hostRuns: runs, onAdd: () {}, onDetails: (_) {}, onForget: (_) {}),
          ),
        ),
      ),
    );
    expect(run.running, isTrue, reason: 'the lock belongs to a setup still running in another process');
    expect(run.interrupted, isFalse, reason: 'a held lock must not offer interrupted recovery');
    expect(run.waiting, isFalse, reason: 'a lock refusal must never ask for a host login stop');
    expect(
      attention.openRows.where((row) => row.kind == AttentionKind.host),
      isEmpty,
      reason: 'running setup needs no person to resume it',
    );
    expect(find.byType(HostStopDialog), findsNothing, reason: 'restoration must never open a host stop');
    // Harm: a greyed button's reason under the buttons reads as an instruction; it is said on hovering it alone.
    await tester.tap(find.byTooltip('Show more').first);
    await World.settle(tester);
    expect(find.textContaining('Take it down: '), findsNothing, reason: 'no line under the buttons says why');
    expect(
      find.byTooltip('the host command is still running'),
      findsWidgets,
      reason: 'the reason is the greyed button\'s tooltip',
    );
    await tester.runAsync(() => runs.resume(run));
    expect(starts, 0, reason: 'neither the startup probe nor Go on may start up while another process owns the lock');
    await tester.runAsync(() async {
      await holder.stdin.close();
      await holder.exitCode;
    });
    await tester.runAsync(() => _until(runs, () => run.interrupted));
    await World.settle(tester);
    expect(run.interrupted, isTrue, reason: 'the next free-lock poll restores interrupted recovery');
    expect(run.running, isFalse, reason: 'a released lock no longer indicates a running setup');
    expect(starts, 0, reason: 'polling never resumes setup on its own');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a probe overlapping Process.start can refuse the only resume or release the new setup lock.
  test('a concurrent probe and Go on start exactly one up after closing the probe file', () async {
    final gate = _ProbeGate();
    var starts = 0;
    final runs = await restored((_, _) async {
      starts++;
      expect(gate.closed, isTrue, reason: 'the only probe descriptor must close before Process.start');
      final child = await _child('rent', getLock());
      children.add(child);
      return child;
    }, gate: gate);
    await gate.locked.future.timeout(const Duration(seconds: 5));
    final run = runs.of('demo')!;
    final first = runs.resume(run);
    final second = runs.resume(run);
    await Future<void>.delayed(Duration.zero);
    expect(starts, 0, reason: 'Go on must wait while the existing probe owns its descriptor');
    gate.release.complete();
    await _until(runs, () => run.session.steps.isNotEmpty);
    expect(starts, 1, reason: 'simultaneous clicks must share a single up attempt');
    expect(
      run.session.steps.any((step) => step.step == 'lock' && step.state == StepState.refused),
      isFalse,
      reason: 'the probe must not cause the up it precedes to refuse its lock',
    );
    expect(
      run.session.steps.any((step) => step.step == 'rent' && step.state == StepState.started),
      isTrue,
      reason: 'the only up must actually acquire the lock and begin setup',
    );
    children.single.kill();
    await Future.wait([first, second]);
    expect(gate.opens, 1, reason: 'one startup probe must open exactly one descriptor');
    expect(gate.closes, 1, reason: 'the same descriptor must close exactly once');
  });

  // Harm: contention found by Go on can be mistaken for a login stop and leave running setup unmanaged.
  test('Go on lock refusal is polled as running from before', () async {
    final process = HostProcess();
    var starts = 0;
    final runs = await restored((_, _) async {
      starts++;
      return process;
    });
    await runs.of('demo')!.checked;
    final holder = await _child('hold', getLock());
    children.add(holder);
    expect(
      await holder.stdout.transform(utf8.decoder).transform(const LineSplitter()).first,
      'locked',
      reason: 'another process takes the lock after the free startup check',
    );
    final run = runs.of('demo')!;
    final resume = runs.resume(run);
    process.line(const Step('lock', StepState.refused));
    process.end(75);
    await resume;
    expect(run.running, isTrue, reason: 'lock contention means setup continues elsewhere');
    expect(run.interrupted || run.waiting, isFalse, reason: 'no recovery or host stop is offered for a running setup');
    expect(starts, 1, reason: 'lock contention must not restart the command on its own');
    await holder.stdin.close();
    await holder.exitCode;
    await _until(runs, () => run.interrupted);
    expect(run.running, isFalse, reason: 'polling must observe that the other command has exited');
    expect(starts, 1, reason: 'a released lock must never resume setup automatically');
  });
}

class _RestoredRuns extends HostRuns {
  _RestoredRuns(super.machines, Map<String, String> environment, this.startCommand, this.gate)
    : super(environment: environment);
  final StartHostCommand startCommand;
  final _ProbeGate? gate;
  @override
  HostSession sessionFor(String project, HostUpRecord record) =>
      HostSession(executable: 'stand-in', arguments: hostArguments(record, project), start: startCommand);
  @override
  Future<RandomAccessFile> openProjectLock(File file) async {
    final handle = await super.openProjectLock(file);
    final delay = gate;
    if (delay == null) return handle;
    delay.opens++;
    return _DelayedLock(handle, delay);
  }
}

class _ProbeGate {
  final locked = Completer<void>();
  final release = Completer<void>();
  bool closed = false;
  int opens = 0;
  int closes = 0;
}

class _DelayedLock extends Fake implements RandomAccessFile {
  _DelayedLock(this.handle, this.gate);
  final RandomAccessFile handle;
  final _ProbeGate gate;
  @override
  Future<RandomAccessFile> lock([FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) async {
    await handle.lock(mode, start, end);
    gate.locked.complete();
    await gate.release.future;
    return this;
  }

  @override
  Future<void> close() async {
    await handle.close();
    gate.closed = true;
    gate.closes++;
  }
}

class _UnstoppableProcess extends HostProcess {
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => false;
}

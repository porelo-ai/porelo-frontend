import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart' show OrganizationRefused;
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_process.dart';
import '../support/host_organization.dart';
import '../support/host_rental.dart';
import '../support/signed_host.dart';

Future<Ran> _noKeyScan(
  String program,
  List<String> arguments, {
  String? inDirectory,
  Map<String, String> environment = const {},
  String? input,
}) async => (code: 70, out: '', err: '');

Future<void> _chooseMachine(WidgetTester tester, String name) async {
  final field = find.byKey(const Key('preparation-machine-name'));
  await tester.ensureVisible(field);
  await World.settle(tester);
  await tester.tap(field);
  await World.settle(tester);
  await tester.tap(find.text(name).last);
  await World.settle(tester);
}

void main() {
  // Harm: returning a machine destroys commits that have not reached the central forge without a second decision.
  // Harm: after a failed return, a host that stalls on the new read of its status leaves no way to force it back.
  testWidgets('a stalling read after a failed return keeps the way to go on without a backup', (tester) async {
    var reads = 0;
    final stalls = Completer<HostProgress>();
    final state = await openTakeDown(
      tester,
      readHostProgress: (_) => ++reads == 1 ? Future.value(_centralProgress({'state': 'up-to-date'})) : stalls.future,
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.end(65);
    await World.settle(tester);
    answerHolders(state.processes.last, []);
    await World.settle(tester);
    expect(reads, 2);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('host-force-down'))).onPressed, isNotNull);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a project the machine holds unpushed commits of has no repository rows, and is given back as if safe.
  testWidgets('a held project blocks the give-back and is named', (tester) async {
    final state = await openTakeDown(
      tester,
      readHostProgress: (_) async => HostProgress.read(
        jsonEncode({
          'projects': [
            {'project': 'demo', 'state': 'held', 'why': 'core', 'repositories': <Object?>[]},
          ],
        }),
      ),
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
    expect(find.textContaining('demo: holds commits not yet pushed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('give-back waits for fresh central status and requires explicit acceptance of the named loss', (
    tester,
  ) async {
    final answer = Completer<HostProgress>();
    final asked = <String>[];
    final state = await openTakeDown(
      tester,
      readHostProgress: (host) {
        asked.add(host);
        return answer.future;
      },
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    final confirm = find.byKey(const Key('host-confirm-down'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.byKey(const Key('host-give-back-anyway')), findsNothing);
    expect(asked, ['orchard']);
    answer.complete(_centralProgress({'state': 'ahead', 'commits': 2}));
    await World.settle(tester);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.textContaining('demo/core'), findsOneWidget);
    expect(find.textContaining('2 commits ahead of central'), findsOneWidget);
    expect(find.textContaining('will be lost'), findsOneWidget);
    expect(find.byKey(const Key('host-force-down')), findsNothing);
    expect(state.commands, hasLength(1), reason: 'reading status must not give the machine back');
    await tester.tap(find.byKey(const Key('host-give-back-anyway')));
    await World.settle(tester);
    expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard'), '--give-back-anyway']);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(state.settings.hostUp('orchard'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a missing, unknown or unsafe central state silently permits destructive give-back.
  for (final (label, central) in <(String, Map<String, Object?>?)>[
    ('missing', null),
    ('moved', {'state': 'moved-on'}),
    ('no read key', {'state': 'cannot-say', 'why': 'no-read-key'}),
    ('unreachable', {'state': 'cannot-say', 'why': 'unreachable'}),
    ('no main', {'state': 'cannot-say', 'why': 'no-central-main'}),
    ('unknown state', {'state': 'later-state'}),
    ('unknown reason', {'state': 'cannot-say', 'why': 'later-reason'}),
    ('malformed', {'state': 'ahead', 'commits': '2'}),
  ]) {
    testWidgets('$label central status blocks ordinary give-back and names the repository', (tester) async {
      final state = await openTakeDown(tester, readHostProgress: (_) async => _centralProgress(central));
      answerHolders(state.processes.single, []);
      await World.settle(tester);
      expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
      expect(find.textContaining('demo/core'), findsOneWidget);
      expect(find.byKey(const Key('host-give-back-anyway')), findsOneWidget);
      expect(state.commands, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: an unreachable host is taken as an empty host with no work to lose.
  for (final failure in ['disconnected', 'refused', 'stalled', 'incomplete']) {
    testWidgets('$failure host status blocks give-back without trapping the rental', (tester) async {
      final pending = Completer<HostProgress>();
      final state = await openTakeDown(
        tester,
        readHostProgress: switch (failure) {
          'disconnected' => null,
          'refused' => (_) async => throw const OrganizationRefused('The machine did not answer.'),
          'incomplete' => (_) async => HostProgress.read('{}'),
          _ => (_) => pending.future,
        },
      );
      answerHolders(state.processes.single, []);
      if (failure == 'stalled') await tester.pump(const Duration(seconds: 31));
      await World.settle(tester);
      expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
      expect(find.textContaining('cannot say'), findsWidgets);
      expect(find.byKey(const Key('host-give-back-anyway')), findsOneWidget);
      expect(state.commands, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      if (failure == 'stalled') pending.complete(const HostProgress());
      await tester.pump();
    });
  }

  // Harm: the local-only exception becomes unusable, or an ordinary return silently forces data loss.
  testWidgets('at central and local repositories allow ordinary give-back without forcing', (tester) async {
    final state = await openTakeDown(
      tester,
      readHostProgress: (_) async => HostProgress.read('''
{"projects":[{"project":"demo","state":"carried","repositories":[
{"repository":"core","state":"taken","central":{"state":"up-to-date"}},
{"repository":"scratch","state":"taken","central":{"state":"cannot-say","why":"local"}}
]}]}
'''),
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    expect(find.byKey(const Key('host-give-back-anyway')), findsNothing);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard')]);
    state.processes.last.end(65);
    await World.settle(tester);
    answerHolders(state.processes.last, []);
    await World.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a stale safe answer or the backup override bypasses a new central refusal after a failed return.
  testWidgets(
    'a failed return reads central status again and neither an old callback nor the backup override bypasses it',
    (tester) async {
      var reads = 0;
      final state = await openTakeDown(
        tester,
        readHostProgress: (_) async {
          reads++;
          return _centralProgress(reads == 1 ? {'state': 'up-to-date'} : {'state': 'ahead', 'commits': 2});
        },
      );
      answerHolders(state.processes.single, []);
      await World.settle(tester);
      final earlier = tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed!;
      earlier();
      await World.settle(tester);
      state.processes.last.end(65);
      await World.settle(tester);
      answerHolders(state.processes.last, []);
      await World.settle(tester);
      expect(reads, 2);
      expect(
        find.byKey(const Key('host-force-down')),
        findsNothing,
        reason: 'the loss is decided by Give it back anyway',
      );
      final before = state.commands.length;
      earlier();
      await World.settle(tester);
      expect(state.commands, hasLength(before));
      expect(find.byKey(const Key('host-give-back-anyway')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // Harm: retrying a failed backup override destroys newly unpushed work without confirming that separate loss.
  testWidgets('a failed backup override refreshes central status before another destructive retry', (tester) async {
    var reads = 0;
    final state = await openTakeDown(
      tester,
      readHostProgress: (_) async {
        reads++;
        return _centralProgress(reads < 3 ? {'state': 'up-to-date'} : {'state': 'ahead', 'commits': 2});
      },
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.end(65);
    await World.settle(tester);
    answerHolders(state.processes.last, []);
    await World.settle(tester);
    final force = find.byKey(const Key('host-force-down'));
    final earlier = tester.widget<OutlinedButton>(force).onPressed!;
    earlier();
    await World.settle(tester);
    expect(state.commands.last, contains('--give-back-anyway'));
    state.processes.last.end(65);
    await World.settle(tester);
    expect(reads, 3, reason: 'even a forced return that fails must read the host again');
    expect(state.commands.last, contains('--memberships'));
    answerHolders(state.processes.last, []);
    await World.settle(tester);
    expect(force, findsNothing, reason: 'one forcing button, worded for the loss it accepts');
    expect(find.textContaining('demo/core'), findsOneWidget);
    expect(find.byKey(const Key('host-give-back-anyway')), findsOneWidget);
    final before = state.commands.length;
    earlier();
    await World.settle(tester);
    expect(state.commands, hasLength(before), reason: 'the old backup decision cannot authorize newly unpushed work');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a fetched key is used without comparison, or a late scan replaces the key the person pasted.
  testWidgets('preparation requires comparison of a fetched key and invalidates it when the address changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    final scans = <Completer<Ran>>[];
    final fingerprint = 'SHA256:${List.filled(43, 'A').join()}';
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: '',
            machines: machines,
            hostRuns: runs,
            start: (_, _) async {
              starts++;
              throw StateError('must not start');
            },
            runKeyCommand: (_, arguments, {inDirectory, environment = const {}, input}) async {
              if (arguments.first == '-T') {
                final scan = Completer<Ran>();
                scans.add(scan);
                return scan.future;
              }
              expect(input, '$hostKey\n');
              return (code: 0, out: '256 $fingerprint no comment (ED25519)\n', err: '');
            },
          ),
        ),
      ),
    );
    await World.settle(tester);
    Future<void> type(String label, String value) async {
      final field = find.widgetWithText(TextField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    FilledButton prepare() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the machine'));
    // Harm: the button stays grey with nothing beside it saying why, and a person nearly closes the dialog.
    String? waits() {
      final found = find.byKey(const Key('preparation-waits'));
      return found.evaluate().isEmpty ? null : tester.widget<Text>(found).data;
    }

    await _chooseMachine(tester, 'orchard');
    await tester.pump();
    expect(waits(), contains('host key'));
    await type('Server address', '192.0.2.7');
    await tester.pump(const Duration(milliseconds: 501));
    expect(scans, hasLength(1));
    expect(prepare().onPressed, isNull);
    expect(waits(), contains('Fetching'));
    scans.first.complete((code: 0, out: '192.0.2.7 $hostKey\n', err: ''));
    await World.settle(tester);
    expect(find.text(fingerprint), findsOneWidget);
    expect(prepare().onPressed, isNull, reason: 'fetching alone must never permit preparation');
    expect(waits(), contains('I compared this fingerprint'));
    final confirmed = find.byKey(const Key('preparation-host-key-confirmed'));
    await tester.ensureVisible(confirmed);
    await tester.tap(confirmed);
    await World.settle(tester);
    final staleAction = prepare().onPressed;
    expect(staleAction, isNotNull);
    expect(waits(), isNull, reason: 'nothing to wait for once it can be pressed');
    await type('Server address', '192.0.2.8');
    await tester.pump();
    expect(prepare().onPressed, isNull, reason: 'a comparison belongs to one server address');
    staleAction!();
    await World.settle(tester);
    expect(starts, 0, reason: 'a stale callback must also recheck the comparison');
    await tester.pump(const Duration(milliseconds: 501));
    await type('SSH host key', backupKey);
    scans.last.complete((code: 0, out: '192.0.2.8 $hostKey\n', err: ''));
    await World.settle(tester);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'SSH host key')).controller!.text, backupKey);
    expect(find.byKey(const Key('preparation-host-key-confirmed')), findsNothing);
    expect(prepare().onPressed, isNotNull, reason: 'a pasted checked key needs no first-use checkbox');
  });

  // Harm: repeated clicks open competing setup dialogs, or a stale permission starts machine preparation.
  testWidgets('preparation opens once while reading and refuses a revoked key in its dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final proof = FixtureProof(fixture);
    final access = await fixture.access(settings, proof: proof);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    late BuildContext page;
    Command command() => prepareServerCommand(
      access: access,
      open: () => openPrepareServerDialog(
        page,
        runKeyCommand: _noKeyScan,
        machines: machines,
        settings: settings,
        hostRuns: runs,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            page = context;
            return const Scaffold();
          },
        ),
      ),
    );
    proof.hold = Completer<void>();
    command().run();
    await World.settle(tester);
    final openedWhileReading = find.byType(HostDialog).evaluate().length;
    command().run();
    await World.settle(tester);
    proof.hold!.complete();
    proof.hold = null;
    await World.settle(tester);
    expect(
      find.byType(HostDialog, skipOffstage: false),
      findsOneWidget,
      reason: 'a second click must not open a second setup dialog',
    );
    expect(openedWhileReading, 1, reason: 'the dialog must open before the reads answer');
    await tester.tap(find.text('Close'));
    await World.settle(tester);

    proof.hold = Completer<void>();
    command().run();
    await World.settle(tester);
    final prepare = find.widgetWithText(FilledButton, 'Prepare the machine');
    expect(
      tester.widget<FilledButton>(prepare).onPressed,
      isNull,
      reason: 'the earlier permission must not enable preparation during a fresh read',
    );
    expect(find.textContaining('Before setup'), findsNothing);
    proof.next = null;
    proof.hold!.complete();
    proof.hold = null;
    await World.settle(tester);
    expect(find.text('Your key is revoked.'), findsOneWidget);
    expect(tester.widget<FilledButton>(prepare).onPressed, isNull);
    expect(runs.preparing, isEmpty);
    expect(fixture.machineFiles, isEmpty);
    await tester.tap(find.text('Close'));
    await World.settle(tester);
  });

  // Harm: in the foo test *Prepare a machine…* was simply grey, its reason behind a hover, under an https organization.
  testWidgets('My machines says why it cannot prepare, with the next step, in words', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final access = await (HostFixture()..address = 'https://forge.example.org/acme/org').access(settings);
    addTearDown(() {
      machines.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MachinesPage(
            machines: machines,
            onAdd: () {},
            onDetails: (_) {},
            onForget: (_) {},
            prepareServer: prepareServerCommand(open: () {}, access: access),
          ),
        ),
      ),
    );
    final said = find.byKey(const ValueKey('machines-why host.prepare'));
    expect(tester.widget<Text>(said).data, contains('https://forge.example.org/acme/org'));
    expect(tester.widget<Text>(said).data, contains('porelo setup --organization'));
  });

  // Harm: closing progress cancels a machine setup, loses its row or starts a second command when reopened.
  testWidgets('closing a running preparation leaves its row and live protocol available', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final runs = HostRuns(machines, hostAccess: await HostFixture().access(settings));
    var process = HostProcess();
    var starts = 0;
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ListenableBuilder(
              listenable: runs,
              builder: (_, _) => MachinesPage(
                machines: machines,
                hostRuns: runs,
                onAdd: () {},
                onDetails: (_) {},
                onForget: (_) {},
                onHostProtocol: (run) =>
                    unawaited(openHostRunDialog(context, run: run, hostRuns: runs, machines: machines)),
              ),
            ),
            floatingActionButton: TextButton(
              onPressed: () => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) => HostDialog(
                    runKeyCommand: _noKeyScan,
                    project: '',
                    machines: machines,
                    hostRuns: runs,
                    start: (_, _) async {
                      starts++;
                      return process;
                    },
                  ),
                ),
              ),
              child: const Text('Open preparation'),
            ),
          ),
        ),
      ),
    );
    Future<HostPreparation> startPreparation(String name) async {
      await tester.tap(find.text('Open preparation'));
      await World.settle(tester);
      // The key first: an address typed with no key behind it goes to fetch one from the network.
      await _chooseMachine(tester, name);
      for (final value in [(1, hostKey), (0, '203.0.113.7')]) {
        final field = find.descendant(of: find.byType(HostDialog), matching: find.byType(TextField)).at(value.$1);
        await tester.ensureVisible(field);
        await World.settle(tester);
        await tester.enterText(field, value.$2);
      }
      await World.settle(tester);
      await tester.tap(find.text('Prepare the machine'));
      await World.settle(tester);
      return runs.of(name)!;
    }

    final run = await startPreparation('orchard');
    expect(starts, 1);
    await tester.tapAt(const Offset(10, 10));
    await World.settle(tester);
    expect(find.byType(HostDialog), findsNothing);
    expect(process.killed, isFalse);
    expect(run.running, isTrue);
    process.line(const host.Step('install', host.StepState.started, text: 'Installing the machine'));
    await World.settle(tester);
    await tester.tap(find.text('orchard'));
    await World.settle(tester);
    expect(find.textContaining('Installing the machine'), findsWidgets);
    await tester.tap(find.text('Close'));
    await World.settle(tester);
    expect(process.killed, isFalse);
    expect(run.running, isTrue);
    expect(starts, 1);
    process.line(const host.Step('play', host.StepState.refused, words: 'Stopped by the test'));
    process.end(65);
    await World.settle(tester);
    await run.finished;
    expect(settings.hostUp('orchard')!.protocol, isNotEmpty);
    expect(find.byKey(const ValueKey('host-preparing orchard')), findsOneWidget);

    process = HostProcess();
    final second = await startPreparation('demo');
    await tester.tap(find.text('Close'));
    await World.settle(tester);
    expect(find.byType(HostDialog), findsNothing, reason: 'Close must work after the run starts');
    expect(process.killed, isFalse);
    expect(second.running, isTrue);
    process.line(const host.Step('install', host.StepState.started, text: 'Installing the second machine'));
    await World.settle(tester);
    await tester.tap(find.text('demo'));
    await World.settle(tester);
    expect(find.textContaining('Installing the second machine'), findsWidgets);
    expect(starts, 2, reason: 'opening a protocol must not start another command');
    process.line(const host.Step('play', host.StepState.refused, words: 'Stopped by the test'));
    process.end(65);
    await World.settle(tester);
    await second.finished;
  });

  // Harm: a host admin must see every account and membership that explicit teardown will permanently remove.
  testWidgets('give-back shows holders and purges only the names shown', (tester) async {
    final state = await openTakeDown(tester);
    expect(state.commands.single, ['down', ...signedSetup.giveBackArguments('orchard'), '--memberships']);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
    answerHolders(state.processes.single, [
      holder('alice', admin: true),
      holder(
        'bob',
        projects: [
          {'project': 'garden', 'role': 'member'},
        ],
      ),
      holder('retired', state: 'purged'),
    ]);
    await World.settle(tester);
    expect(find.textContaining('alice:'), findsOneWidget);
    expect(find.textContaining('Machine Admin'), findsOneWidget);
    expect(find.textContaining('bob:'), findsOneWidget);
    expect(find.textContaining('garden'), findsOneWidget);
    expect(find.textContaining('member)'), findsOneWidget);
    expect(find.textContaining('retired:'), findsNothing);
    expect(find.byKey(const Key('host-force-down')), findsNothing);
    expect(state.commands, hasLength(1), reason: 'reading memberships cannot purge them');
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    expect(state.commands.last, [
      'down',
      ...signedSetup.giveBackArguments('orchard'),
      '--purge',
      'alice',
      '--purge',
      'bob',
    ]);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(state.settings.hostUp('orchard'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: clean teardown must remain available when there are no memberships to purge.
  testWidgets('no holders uses the existing give-back without purge options', (tester) async {
    final state = await openTakeDown(tester);
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    expect(find.byKey(const Key('host-force-down')), findsNothing);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard')]);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(state.settings.hostUp('orchard'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a machine kept after down shuts out what is put on it next, and nobody said so or how to end it.
  testWidgets('taking Porelo off says what the machine says stays, in full and copyable', (tester) async {
    const said = 'The firewall stays on this machine. To take it off: systemctl disable --now a-firewall.service';
    final state = await openTakeDown(
      tester,
      record: HostUpRecord(
        hostName: 'orchard',
        host: 'orchard',
        givenAddress: '203.0.113.7',
        givenHostKey: hostKey,
        preparationSettings: const host.HostPreparationSettings(),
        machineFile: signedSetup.machineFile,
        publicKey: signedSetup.publicKey,
      ),
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('note', host.StepState.note, words: said));
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(find.textContaining('Porelo was taken off.'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, 'The machine says: $said'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: the second try, cut short, takes away what the first said stays on a machine still theirs.
  testWidgets('a retry keeps what the try before it said stays', (tester) async {
    final state = await openTakeDown(tester);
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('note', host.StepState.note, words: 'The firewall stays.'));
    state.processes.last.line(const host.Step('give-back', host.StepState.refused));
    state.processes.last.end(65);
    await World.settle(tester);
    answerHolders(state.processes.last, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.refused));
    state.processes.last.end(65);
    await World.settle(tester);
    answerHolders(state.processes.last, []);
    await World.settle(tester);
    expect(find.textContaining('The machine says: The firewall stays.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: the same, when what the window keeps fails after the provider confirmed the return.
  testWidgets('a confirmed return says nothing of the machine, though forgetting it fails', (tester) async {
    final store = _RefusingStore();
    final state = await openTakeDown(tester, store: store);
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('note', host.StepState.note, words: 'The firewall stays.'));
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    store.refuses = true;
    state.processes.last.end(0);
    await World.settle(tester);
    expect(find.textContaining('The machine says:'), findsNothing);
    store.refuses = false;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a person told a server they gave back is still billed, when the provider said it is not.
  testWidgets('a confirmed return never says it stays billed, though forgetting it fails', (tester) async {
    final store = _RefusingStore();
    final state = await openTakeDown(tester, store: store);
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    store.refuses = true;
    state.processes.last.end(0);
    await World.settle(tester);
    expect(find.textContaining('stays billed'), findsNothing);
    expect(find.textContaining('not confirmed'), findsNothing);
    expect(find.textContaining('The provider confirmed the rental return. Billing has ended.'), findsOneWidget);
    expect(state.commands.where((command) => command.contains('--memberships')), hasLength(1));
    store.refuses = false;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: the same of a machine kept: Porelo is off it, and the window said it could not tell.
  testWidgets('Porelo confirmed off a machine never says it was not, though forgetting it fails', (tester) async {
    final store = _RefusingStore();
    final state = await openTakeDown(
      tester,
      store: store,
      record: HostUpRecord(
        hostName: 'orchard',
        host: 'orchard',
        givenAddress: '203.0.113.7',
        givenHostKey: hostKey,
        preparationSettings: const host.HostPreparationSettings(),
        machineFile: signedSetup.machineFile,
        publicKey: signedSetup.publicKey,
      ),
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    store.refuses = true;
    state.processes.last.end(0);
    await World.settle(tester);
    expect(find.textContaining('not confirmed'), findsNothing);
    expect(find.textContaining('Porelo was taken off.'), findsOneWidget);
    store.refuses = false;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a person told how to change a server that no longer is theirs.
  testWidgets('a rental given back says nothing of a machine now gone', (tester) async {
    final state = await openTakeDown(tester);
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('note', host.StepState.note, words: 'The firewall stays.'));
    await World.settle(tester);
    expect(find.textContaining('The machine says: The firewall stays.'), findsOneWidget, reason: 'it is still there');
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(find.textContaining('Billing has ended.'), findsOneWidget);
    expect(find.textContaining('The machine says:'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a machine taken down stays on the organization's list and goes on carrying what it carried, as the question
  // promised otherwise; or one not confirmed down is taken off the list.
  testWidgets('a confirmed down removes the machine from the organization, a refused one does not', (tester) async {
    final removed = <String>[];
    final state = await openTakeDown(
      tester,
      removeFromOrganization: (host) async {
        removed.add(host);
        return null;
      },
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.refused));
    state.processes.last.end(65);
    await World.settle(tester);
    answerHolders(state.processes.last, []);
    await World.settle(tester);
    expect(removed, isEmpty, reason: 'not confirmed down');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: as above, the confirmed case.
  testWidgets('a confirmed down sends the removal once', (tester) async {
    final removed = <String>[];
    final state = await openTakeDown(
      tester,
      removeFromOrganization: (host) async {
        removed.add(host);
        return null;
      },
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(removed, [signedSetup.hostName]);
    expect(find.textContaining('organization'), findsNothing, reason: 'no refusal to say');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a removal the organization refused is silent, and the person believes the machine left the list.
  testWidgets('a removal refused is said, with the way to remove it by hand', (tester) async {
    final state = await openTakeDown(tester, removeFromOrganization: (_) async => 'the forge did not answer');
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(find.textContaining('Billing has ended.'), findsOneWidget);
    expect(find.textContaining("stays on the organization's list: the forge did not answer"), findsOneWidget);
    expect(find.textContaining('Remove the machine…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: someone admitted after confirmation must never be purged without a new explicit choice.
  testWidgets('a refused down reads new holders and waits for their confirmation', (tester) async {
    final state = await openTakeDown(tester);
    answerHolders(state.processes.single, [holder('alice', admin: true)]);
    await World.settle(tester);
    final earlierChoice = tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed!;
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    final firstDown = state.commands.last;
    expect(firstDown, containsAllInOrder(['--purge', 'alice']));
    expect(firstDown, isNot(contains('charlie')));
    state.processes.last.line(const host.Step('play', host.StepState.refused, words: 'charlie holds garden'));
    state.processes.last.line(const host.Step('give-back', host.StepState.refused));
    state.processes.last.end(65);
    await World.settle(tester);
    expect(state.commands, hasLength(3));
    expect(state.commands.last, contains('--memberships'));
    expect(state.settings.hostUp('orchard'), isNotNull);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
    answerHolders(state.processes.last, [
      holder(
        'charlie',
        projects: [
          {'project': 'garden', 'role': 'admin'},
        ],
      ),
    ]);
    await World.settle(tester);
    expect(find.textContaining('charlie:'), findsOneWidget);
    expect(find.textContaining('alice:'), findsNothing);
    expect(state.commands, hasLength(3), reason: 'the new names must be shown before another destructive command');
    earlierChoice();
    await World.settle(tester);
    expect(state.commands, hasLength(3), reason: 'an earlier confirmation cannot authorize the refreshed list');
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard'), '--purge', 'charlie']);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a status that cannot be read, as on a server whose setup stopped before the helper, must neither imply a
  // purge nor trap a billed rental; and loss must not be offered before an ordinary give-back has failed.
  for (final failure in ['root', 'unreachable', 'malformed', 'incomplete']) {
    testWidgets('an unreadable $failure status purges nothing and leaves the ordinary give-back', (tester) async {
      final state = await openTakeDown(tester);
      final process = state.processes.single;
      if (failure == 'malformed') {
        process.line(const host.Step('org-status', host.StepState.done, words: '{"persons":[{}]}'));
        process.end(0);
      } else if (failure == 'incomplete') {
        process.end(0);
      } else {
        process.line(host.Step('org-status', host.StepState.refused, fix: failure, words: 'Permission denied'));
        process.end(failure == 'unreachable' ? 69 : 65);
      }
      await World.settle(tester);
      expect(find.byKey(const Key('host-force-down')), findsNothing);
      if (failure == 'root' || failure == 'unreachable') {
        expect(find.textContaining(failure), findsWidgets);
        expect(find.textContaining('Permission denied'), findsWidgets);
      }
      expect(state.settings.hostUp('orchard'), isNotNull);
      expect(state.commands, hasLength(1));

      await tester.tap(find.byKey(const Key('host-confirm-down')));
      await World.settle(tester);
      expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard')]);
      state.processes.last.line(const host.Step('give-back', host.StepState.refused));
      state.processes.last.end(65);
      await World.settle(tester);
      expect(state.settings.hostUp('orchard'), isNotNull, reason: 'a refused give-back keeps the recovery record');
      final reread = state.processes.last;
      expect(state.commands.last, contains('--memberships'));
      reread.end(0);
      await World.settle(tester);

      await tester.tap(find.byKey(const Key('host-force-down')));
      await World.settle(tester);
      expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard'), '--give-back-anyway']);
      state.processes.last.line(const host.Step('give-back', host.StepState.done));
      state.processes.last.end(0);
      await World.settle(tester);
      expect(state.settings.hostUp('orchard'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: a host that connects and then says nothing must not hold a person inside a billed server.
  testWidgets('a stalled holder read ends and leaves the ordinary give-back, with nobody purged', (tester) async {
    final state = await openTakeDown(tester);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down')));
    expect(confirm.onPressed, isNotNull);
    expect(state.processes.first.killed, isTrue, reason: 'nobody waits for the stalled read any more');
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await tester.pump();
    expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard')]);
    state.processes.first.end(0);
    state.processes.last.end(65);
    await World.settle(tester);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a read after a failed give-back that stalls must not close the way out while it waits.
  testWidgets('a stalled read after a failed give-back leaves the give-back without a backup open', (tester) async {
    final state = await openTakeDown(tester);
    answerHolders(state.processes.single, const []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.end(65);
    await tester.pump();
    await tester.pump();
    expect(state.commands.last, contains('--memberships'), reason: 'the read after the failure is under way');
    final force = tester.widget<OutlinedButton>(find.byKey(const Key('host-force-down')));
    expect(force.onPressed, isNotNull);
    state.processes.last.end(0);
    await World.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: merely reviewing a purge confirmation, or leaving while status is read, cannot delete accounts or release a host.
  for (final reading in [true, false]) {
    testWidgets('closing give-back while reading=$reading changes no server or recovery record', (tester) async {
      final state = await openTakeDown(tester);
      if (!reading) {
        answerHolders(state.processes.single, [holder('alice', admin: true)]);
        await World.settle(tester);
      }
      await tester.tap(find.text('Close'));
      await World.settle(tester);
      if (reading) {
        answerHolders(state.processes.single, [holder('alice', admin: true)]);
        await World.settle(tester);
      }
      expect(state.commands, hasLength(1));
      expect(state.commands.single, contains('--memberships'));
      expect(state.settings.hostUp('orchard'), isNotNull);
      expect(find.byType(HostDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: opening a retained protocol must not start a second command or lose its refusal.
  testWidgets('the retained setup protocol remains visible without starting another command', (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    final process = HostProcess();
    var starts = 0;
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async {
        starts++;
        return process;
      },
    );
    final run = runs.start(project: 'orchard', record: signedSetup, session: session);
    process.line(const host.Step('up', host.StepState.refused, fix: 'The signed state was refused.'));
    process.end(65);
    await run.finished;
    final startsBefore = starts;
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: 'orchard', machines: machines, settings: settings, hostRuns: runs, existingRun: run),
      ),
    );
    await World.settle(tester);
    expect(starts, startsBefore);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  // Harm: the stop says to run the command above, and no command is there; or it stays through the next try.
  testWidgets('a run stopped because root is closed shows the command again', (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final access = await HostFixture().access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = runs.start(project: 'orchard', record: signedSetup, session: session);
    process.line(const host.Step('ssh', host.StepState.refused, fix: '${host.rootStillClosed} Nothing changed.'));
    process.end(65);
    await run.finished;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: 'orchard', machines: machines, settings: settings, hostRuns: runs, existingRun: run),
      ),
    );
    await World.settle(tester);
    expect(find.byKey(const Key('preparation-root-command')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: the words under *Prepare* say it waits for something when nothing can change that.
  testWidgets('with no way to prepare from here it does not say it is waiting', (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    addTearDown(() {
      machines.dispose();
      settings.dispose();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(runKeyCommand: _noKeyScan, project: '', machines: machines, settings: settings),
      ),
    );
    await World.settle(tester);
    final said = tester.widget<Text>(find.byKey(const Key('preparation-waits'))).data!;
    expect(said, contains('cannot prepare'));
    expect(said, isNot(contains('Waiting')));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a grey button with nothing beside it while permission is read; a stop saying "the command above"
  // with the command below it; the old stop and its command staying up through the next try.
  testWidgets('from Prepare to a stop for root and on to the next try, the words fit each moment', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final proof = FixtureProof(fixture);
    final access = await fixture.access(settings, proof: proof);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    final processes = <HostProcess>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          runKeyCommand: _noKeyScan,
          project: '',
          machines: machines,
          settings: settings,
          hostRuns: runs,
          start: (_, _) async {
            processes.add(HostProcess());
            return processes.last;
          },
        ),
      ),
    );
    Future<void> type(String label, String value) async {
      final field = find.widgetWithText(TextField, label);
      await tester.ensureVisible(field);
      await World.settle(tester);
      await tester.enterText(field, value);
    }

    await _chooseMachine(tester, 'orchard');
    await type('Server address', '203.0.113.7');
    await type('SSH host key', hostKey);
    await World.settle(tester);

    final reading = Completer<void>();
    proof.hold = reading;
    await tester.ensureVisible(find.text('Prepare the machine'));
    await World.settle(tester);
    await tester.tap(find.text('Prepare the machine'));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('preparation-waits'))).data, contains('Checking'));
    proof.hold = null;
    reading.complete();
    await World.settle(tester);

    processes.last.line(
      const host.Step('ssh', host.StepState.refused, fix: '${host.rootStillClosed} Nothing changed.'),
    );
    processes.last.end(65);
    await World.settle(tester);
    final command = find.byKey(const Key('preparation-root-command'));
    expect(command, findsOneWidget);
    expect(
      tester.getTopLeft(command).dy,
      lessThan(tester.getTopLeft(find.textContaining(host.rootStillClosed).first).dy),
      reason: 'the words say "above"',
    );

    await tester.ensureVisible(find.text('Prepare the machine again'));
    await World.settle(tester);
    await tester.tap(find.text('Prepare the machine again'));
    await tester.pump();
    await tester.pump();
    expect(command, findsNothing, reason: 'the new try is under way');
    processes.last.end(1);
    await World.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: the key filed is an installer's that has gone, and `up` stops at its first ssh line with ssh's words.
  testWidgets('a key changed since it was compared starts nothing and says why, and the way to compare is named', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final runs = HostRuns(machines, hostAccess: await HostFixture().access(settings));
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    const other = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    var serves = hostKey;
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          project: '',
          machines: machines,
          settings: settings,
          hostRuns: runs,
          start: (_, _) async {
            starts++;
            return HostProcess();
          },
          runKeyCommand: (_, arguments, {inDirectory, environment = const {}, input}) async {
            if (arguments.first == '-T') return (code: 0, out: '192.0.2.7 $serves\n', err: '');
            return (code: 0, out: '256 SHA256:${List.filled(43, 'A').join()} no comment (ED25519)\n', err: '');
          },
        ),
      ),
    );
    await World.settle(tester);
    await _chooseMachine(tester, 'orchard');
    final address = find.widgetWithText(TextField, 'Server address');
    await tester.ensureVisible(address);
    await tester.enterText(address, '192.0.2.7');
    await tester.pump(const Duration(milliseconds: 501));
    await World.settle(tester);
    expect(
      tester.widget<SelectableText>(find.byKey(const Key('preparation-compare-command'))).data,
      contains('ssh-keygen -lf'),
    );
    final confirmed = find.byKey(const Key('preparation-host-key-confirmed'));
    await tester.ensureVisible(confirmed);
    await tester.tap(confirmed);
    await World.settle(tester);
    serves = other;
    await tester.ensureVisible(find.text('Prepare the machine'));
    await tester.tap(find.text('Prepare the machine'));
    await World.settle(tester);
    expect(starts, 0);
    expect(runs.of('orchard'), isNull);
    expect(find.textContaining('host key changed since it was fetched'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the machine')).onPressed,
      isNull,
      reason: 'it must be compared again',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a refused key's run can only be tried again with the same wrong key, or refused by name; and letting a
  // run go that stands on the machine, or a rental that bills, loses the record that takes it off.
  for (final kind in ['given', 'rental', 'past its login']) {
    testWidgets('a run stopped for its key: $kind', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings(MemorySettingsStore());
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
      final runs = HostRuns(machines, hostAccess: await HostFixture().access(settings));
      addTearDown(() {
        runs.dispose();
        machines.dispose();
        settings.dispose();
      });
      final record = kind == 'rental'
          ? signedSetup
          : HostUpRecord(
              hostName: 'orchard',
              host: 'orchard',
              givenAddress: '203.0.113.7',
              givenHostKey: hostKey,
              preparationSettings: const host.HostPreparationSettings(),
              machineFile: signedSetup.machineFile,
              publicKey: signedSetup.publicKey,
            );
      final processes = <HostProcess>[];
      final session = HostSession(
        executable: 'fake',
        arguments: const [],
        start: (_, _) async {
          processes.add(HostProcess());
          return processes.last;
        },
      );
      final run = runs.start(project: 'orchard', record: record, session: session);
      await tester.pump();
      if (kind == 'past its login') {
        processes.last.line(const host.Step('ssh', host.StepState.done));
        processes.last.line(const host.Step('play', host.StepState.refused, fix: 'A task refused.'));
        processes.last.end(65);
        await run.finished;
        unawaited(runs.resume(run));
        await tester.pump();
      }
      processes.last.line(
        const host.Step(
          'ssh',
          host.StepState.refused,
          fix: '${host.hostKeyNotFiled}, so this try changed nothing on it.',
        ),
      );
      processes.last.end(69);
      await run.finished;
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: HostDialog(
            runKeyCommand: _noKeyScan,
            project: 'orchard',
            machines: machines,
            settings: settings,
            hostRuns: runs,
            existingRun: run,
          ),
        ),
      );
      await World.settle(tester);
      final another = find.byKey(const Key('preparation-another-key'));
      if (kind != 'given') {
        expect(another, findsNothing);
        expect(run.problem, contains('removes its setup'), reason: 'what stands on the machine is still said');
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }
      expect(find.byKey(const Key('preparation-key-refused')), findsOneWidget, reason: 'said on reopening');
      expect(run.problem, isNot(contains('removes its setup')), reason: 'nothing of it stands there');
      expect(run.problem, isNot(contains('..')));
      expect(find.text('Prepare the machine again'), findsNothing, reason: 'it would be refused the same way');
      await tester.tap(another);
      await World.settle(tester);
      expect(runs.of('orchard'), isNull);
      expect(settings.hostUp('orchard'), isNull);
      expect(find.text('orchard'), findsOneWidget, reason: 'the name stands chosen');
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Server address')).controller!.text,
        '203.0.113.7',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'SSH host key')).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: the field keeps a name the organization no longer offers, and throws while it draws.
  testWidgets('a machine no longer offered is taken out of the choice, without a throw', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          runKeyCommand: _noKeyScan,
          project: '',
          machines: machines,
          settings: settings,
          hostRuns: runs,
        ),
      ),
    );
    await World.settle(tester);
    await _chooseMachine(tester, 'orchard');
    fixture.adminHosts = {'demo'};
    await access.readAgain();
    final address = find.widgetWithText(TextField, 'Server address');
    await tester.ensureVisible(address);
    await tester.enterText(address, '203.0.113.7');
    await World.settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('orchard'), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('preparation-waits'))).data, contains('Choose the machine'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a person with no machine meets a form that can only refuse them.
  testWidgets('with no machine to choose it says who adds one', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture()
      ..organizationAdmin = true
      ..admin = false;
    final runs = HostRuns(machines, hostAccess: await fixture.access(settings));
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          runKeyCommand: _noKeyScan,
          project: '',
          machines: machines,
          settings: settings,
          hostRuns: runs,
        ),
      ),
    );
    await World.settle(tester);
    expect(find.byKey(const Key('preparation-no-machine')), findsOneWidget);
    expect(find.byKey(const Key('preparation-machine-name')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: reopened by someone no longer a Machine Admin, the dialog throws while it draws.
  testWidgets('a run stopped for root, reopened without the right to prepare, draws and shows no command', (
    tester,
  ) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = runs.start(project: 'orchard', record: signedSetup, session: session);
    process.line(const host.Step('ssh', host.StepState.refused, fix: '${host.rootStillClosed} Nothing changed.'));
    process.end(65);
    await run.finished;
    fixture.admin = false;
    await access.readAgain();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: 'orchard', machines: machines, settings: settings, hostRuns: runs, existingRun: run),
      ),
    );
    await World.settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('preparation-root-command')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: preparation must use the chosen pinned host and limits, and the build's own collection, and retain readiness when signing is unavailable.
  // Harm: a server this computer reaches by name or IPv6 address cannot be prepared or read back after a restart.
  for (final address in ['203.0.113.7', 'orchard.example.org', '2001:db8::7']) {
    testWidgets(
      'Prepare the host passes public choices and the machine file, and keeps the host on its card at $address',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = Settings(MemorySettingsStore());
        final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
        final fixture = HostFixture();
        final access = await fixture.access(settings);
        final runs = HostRuns(machines, hostAccess: access);
        addTearDown(() {
          runs.dispose();
          machines.dispose();
          settings.dispose();
        });
        final process = HostProcess();
        List<String>? arguments;
        await tester.pumpWidget(
          MaterialApp(
            home: HostDialog(
              runKeyCommand: _noKeyScan,
              project: '',
              machines: machines,
              settings: settings,
              hostRuns: runs,
              start: (_, args) async {
                arguments = args;
                return process;
              },
            ),
          ),
        );
        Future<void> type(String label, String value) async {
          final field = find.widgetWithText(TextField, label);
          await tester.ensureVisible(field);
          await World.settle(tester);
          await tester.enterText(field, value);
        }

        await _chooseMachine(tester, 'orchard');
        await type('Server address', address);
        await type('SSH host key', hostKey);
        await tester.ensureVisible(find.text('More settings'));
        await World.settle(tester);
        await tester.tap(find.text('More settings'));
        await World.settle(tester);
        for (final entry in {'forge_runner_capacity': '1', 'forge_job_cpus': '1', 'forge_job_memory': '768m'}.entries) {
          await tester.ensureVisible(find.byKey(Key(entry.key)));
          await World.settle(tester);
          await tester.enterText(find.byKey(Key(entry.key)), entry.value);
        }
        await tester.ensureVisible(find.text('Use settings'));
        await World.settle(tester);
        await tester.tap(find.text('Use settings'));
        await tester.tap(find.text('Prepare the machine'));
        await World.settle(tester);
        final run = runs.of('orchard')!;
        expect(arguments, ['up', ...hostArguments(run.record, 'orchard')]);
        expect(arguments, containsAllInOrder(['--given', address, '--host-key', hostKey]));
        expect(arguments, contains('--machine-file'));
        expect(
          arguments,
          containsAllInOrder(['--forge-runner-capacity', '1', '--forge-job-cpus', '1', '--forge-job-memory', '768m']),
        );
        expect(arguments, isNot(contains('--collection')), reason: 'The collection is the one the build knows.');
        process.line(host.Step('up', host.StepState.done, address: address, admin: 'root'));
        process.line(
          host.Step(
            'host',
            host.StepState.host,
            host: host.PreparedHost.read({...sshCompletion(), 'address': address}),
          ),
        );
        process.end(0);
        await run.finished;
        await World.settle(tester);
        expect(run.ready, isTrue);
        expect(settings.hostUp('orchard')!.preparedHost!.address, address);
        // Harm: a host set up already gives no word of what it was set to.
        expect(find.textContaining('It has a forge of its own, and runs no VMs in its jobs.'), findsOneWidget);
        expect(fixture.writes.single.input['address'], address);
        final restored = hostUpRestored(settings.hostUp('orchard')!);
        expect(restored.givenAddress, address);
        expect(restored.givenHostKey, hostKey);
        expect(hostArguments(restored, 'orchard'), isNot(contains('--collection')));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  // Harm: a reused name must not erase rental recovery or crash an active setup dialog.
  for (final collision in ['saved', 'active', 'waiting']) {
    testWidgets('preparation preserves the $collision host with the same name', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings(MemorySettingsStore());
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
      final fixture = HostFixture();
      final runs = HostRuns(machines, hostAccess: await fixture.access(settings));
      addTearDown(() {
        runs.dispose();
        machines.dispose();
        settings.dispose();
      });
      final process = HostProcess();
      HostPreparation? previous;
      if (collision == 'saved') {
        await settings.rememberHostUp('orchard', signedSetup);
      } else {
        previous = runs.start(
          project: 'orchard',
          record: signedSetup,
          session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
        );
        await tester.pump();
        if (collision == 'waiting') {
          process.line(const host.Step('person', host.StepState.waiting, needs: ['matrix']));
          process.end(75);
          await previous.finished;
        }
      }
      final kept = settings.hostUp('orchard')?.stored;
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HostDialog(
            runKeyCommand: _noKeyScan,
            project: '',
            machines: machines,
            hostRuns: runs,
            start: (_, _) async {
              starts++;
              return HostProcess()..end(65);
            },
          ),
        ),
      );
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('preparation-machine-name')));
      await World.settle(tester);
      expect(find.text('orchard'), findsNothing, reason: 'it has a preparation of its own');
      expect(find.text('demo'), findsWidgets);
      await tester.tap(find.text('demo').last);
      await World.settle(tester);
      expect(starts, 0);
      expect(settings.hostUp('orchard')?.stored, kept);
      if (previous != null) expect(runs.of('orchard'), same(previous));
      if (collision == 'active') {
        process.end(65);
        await previous!.finished;
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: a retained callback after revocation must never start root preparation.
  testWidgets('Prepare the host rechecks admin permission before starting SSH', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          runKeyCommand: _noKeyScan,
          project: '',
          machines: machines,
          hostRuns: runs,
          start: (_, _) async {
            starts++;
            return HostProcess();
          },
        ),
      ),
    );
    await _chooseMachine(tester, 'orchard');
    for (final field in {'Server address': '203.0.113.7', 'SSH host key': hostKey}.entries) {
      final finder = find.widgetWithText(TextField, field.key);
      await tester.ensureVisible(finder);
      await World.settle(tester);
      await tester.enterText(finder, field.value);
    }
    await World.settle(tester);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the machine'));
    fixture.admin = false;
    button.onPressed!();
    await World.settle(tester);
    expect(starts, 0);
    expect(runs.of('orchard'), isNull);
    expect(find.textContaining('Only a Machine Admin'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: the field a person clicks moves under the pointer as the words about the name change, and a floating
  // label is cut by the hint of the field above it.
  testWidgets('the fields of Prepare a server stay put and clear of each other', (tester) async {
    // Tall enough that nothing scrolls to reach the choice, as what is measured is what the name's words move.
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final access = await (HostFixture()..adminHosts = {'orchard'}).access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: '', machines: machines, hostRuns: runs, start: (_, _) async => HostProcess()),
      ),
    );
    await World.settle(tester);
    Finder field(String label) => find.widgetWithText(TextField, label);
    final before = tester.getTopLeft(field('Server address'));
    await _chooseMachine(tester, 'orchard');
    expect(tester.getTopLeft(field('Server address')), before);
    final hint = tester.getBottomLeft(find.textContaining('A machine the organization lists'));
    expect(before.dy - hint.dy, greaterThanOrEqualTo(8), reason: 'a floating label stands 8 above its field');
  });

  // Harm: a person watching a long run reads old steps and takes it for stuck, or is pulled away from one they
  // scrolled up to read.
  testWidgets('a running list stays at its end until the person scrolls up', (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final runs = HostRuns(machines, hostAccess: await HostFixture().access(settings));
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = runs.start(project: 'orchard', record: signedSetup, session: session);
    addTearDown(() {
      process.end(0);
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: 'orchard', machines: machines, settings: settings, hostRuns: runs, existingRun: run),
      ),
    );
    await World.settle(tester);
    ScrollPosition list() => tester
        .state<ScrollableState>(
          find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first,
        )
        .position;
    for (var step = 0; step < 60; step++) {
      process.line(host.Step('step$step', host.StepState.done, text: 'Step number $step'));
    }
    await World.settle(tester);
    expect(list().maxScrollExtent, greaterThan(0));
    expect(list().pixels, list().maxScrollExtent);
    list().jumpTo(0);
    await tester.pump();
    process.line(const host.Step('later', host.StepState.done, text: 'A later step'));
    await World.settle(tester);
    expect(list().pixels, 0);
  });

  testWidgets('nothing is prepared or shown for a host before its name, nor for a host alice is no admin of', (
    tester,
  ) async {
    // Harm: the admin of one host prepares another, or gets its root-key setup line before naming it.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture()..adminHosts = {'orchard'};
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: '', machines: machines, hostRuns: runs, start: (_, _) async => HostProcess()),
      ),
    );
    await World.settle(tester);
    FilledButton prepare() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the machine'));
    expect(prepare().onPressed, isNull);
    expect(find.textContaining('Choose the machine first'), findsOneWidget);
    expect(find.textContaining('Before setup'), findsNothing);
    await tester.tap(find.byKey(const Key('preparation-machine-name')));
    await World.settle(tester);
    expect(find.text('demo'), findsNothing, reason: 'alice is no Machine Admin of it, so it cannot be chosen');
    await tester.tap(find.text('orchard').last);
    await World.settle(tester);
    expect(find.textContaining('Before setup'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: root's bootstrap line, or a registered run, for a card key revoked or taken out of the agent since the read.
  testWidgets('the bootstrap line and a run wait for the identity read again, and none follows a failed one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = HostFixture();
    final proof = FixtureProof(fixture)..hold = Completer<void>();
    final access = await fixture.access(settings, proof: proof);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          runKeyCommand: _noKeyScan,
          project: '',
          machines: machines,
          hostRuns: runs,
          start: (_, _) async {
            starts++;
            return HostProcess();
          },
        ),
      ),
    );
    await World.settle(tester);
    expect(find.textContaining('Before setup'), findsNothing, reason: 'the read has not ended');
    expect(find.text('orchard'), findsNothing, reason: 'nor is a machine offered before it has');
    proof.hold!.complete();
    proof.hold = null;
    await World.settle(tester);
    await _chooseMachine(tester, 'orchard');
    for (final field in {'Server address': '203.0.113.7', 'SSH host key': hostKey}.entries) {
      final finder = find.widgetWithText(TextField, field.key);
      await tester.ensureVisible(finder);
      await World.settle(tester);
      await tester.enterText(finder, field.value);
    }
    await World.settle(tester);
    expect(find.textContaining('Before setup'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the machine'));
    proof.next = null;
    button.onPressed!();
    await World.settle(tester);
    expect(starts, 0);
    expect(runs.of('orchard'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

HostUpRecord hostUpRestored(HostUpRecord record) => HostUpRecord.fromStored(record.stored)!;

Map<String, Object?> holder(
  String login, {
  bool admin = false,
  String state = 'active',
  List<Object?> projects = const [],
}) => {'login': login, 'state': state, 'host_admin': admin, 'projects': projects};

void answerHolders(HostProcess process, List<Map<String, Object?>> persons) {
  process.line(host.Step('org-status', host.StepState.done, words: jsonEncode({'persons': persons})));
  process.end(0);
}

/// A store whose writes can be made to fail.
class _RefusingStore extends MemorySettingsStore {
  bool refuses = false;

  @override
  Future<void> write(Map<String, Object?> values) async {
    if (refuses) throw StateError('refused');
    await super.write(values);
  }
}

Future<({Settings settings, List<List<String>> commands, List<HostProcess> processes})> openTakeDown(
  WidgetTester tester, {
  HostUpRecord record = signedSetup,
  SettingsStore? store,
  Future<HostProgress> Function(String host)? readHostProgress = _emptyHostProgress,
  Future<String?> Function(String host)? removeFromOrganization,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = Settings(store ?? MemorySettingsStore());
  await settings.rememberHostUp('orchard', record);
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
  addTearDown(() {
    machines.dispose();
    settings.dispose();
  });
  final commands = <List<String>>[];
  final processes = <HostProcess>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => openHostTakeDownDialog(
            context,
            project: 'orchard',
            machines: machines,
            settings: settings,
            readHostProgress: readHostProgress,
            removeFromOrganization: removeFromOrganization,
            start: (_, arguments) async {
              commands.add(arguments);
              final process = HostProcess();
              processes.add(process);
              return process;
            },
          ),
          child: const Text('Open give-back'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open give-back'));
  await World.settle(tester);
  return (settings: settings, commands: commands, processes: processes);
}

Future<HostProgress> _emptyHostProgress(String host) async => const HostProgress();

HostProgress _centralProgress(Map<String, Object?>? central) => HostProgress.read(
  jsonEncode({
    'projects': [
      {
        'project': 'demo',
        'state': 'carried',
        'repositories': [
          {'repository': 'core', 'state': 'taken', 'central': ?central},
        ],
      },
    ],
  }),
);

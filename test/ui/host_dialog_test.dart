import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_access.dart' show HostAccess;
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart' show OrganizationRefused;
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_process.dart';
import '../support/host_organization.dart';
import '../support/host_rental.dart';
import '../support/signed_host.dart';

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

  // Harm: the machine's own Porelo says commits wait to reach central while the host says up to date, and they are lost
  // without the second decision.
  testWidgets('the machine saying a repository is ahead of central blocks the give-back the host would allow', (
    tester,
  ) async {
    final state = await openTakeDown(
      tester,
      readHostProgress: (_) async => _centralProgress({'state': 'up-to-date'}),
      itsDaemonLists: [
        Project.from(const {
          'name': 'demo',
          'repositories': [
            {'name': 'demo', 'own': true, 'carriedHere': true, 'central': 'up-to-date'},
            {
              'name': 'core',
              'carriedHere': true,
              'central': 'ahead',
              'ahead': 2,
              'aheadMeasured': '2026-11-09T08:00:00Z',
            },
          ],
        }),
      ],
    );
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
    expect(find.textContaining('demo/core'), findsOneWidget);
    expect(find.textContaining('demo/demo'), findsNothing, reason: 'up to date at central blocks nothing');
    expect(find.byKey(const Key('host-give-back-anyway')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    final process = HostProcess();
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
          ),
        ),
      ),
    );
    final run = runs.start(
      project: 'orchard',
      record: signedSetup,
      session: HostSession(
        executable: 'fake',
        arguments: const [],
        start: (_, _) async {
          starts++;
          return process;
        },
      ),
    );
    await World.settle(tester);
    expect(starts, 1);
    process.line(const host.Step('install', host.StepState.started, text: 'Installing the machine'));
    await World.settle(tester);
    await tester.tap(find.text('orchard'));
    await World.settle(tester);
    expect(find.textContaining('Installing the machine'), findsWidgets);
    await tester.tap(find.text('Close'));
    await World.settle(tester);
    expect(find.byType(HostDialog), findsNothing, reason: 'Close must work while the run goes on');
    expect(process.killed, isFalse);
    expect(run.running, isTrue);
    await tester.tap(find.text('orchard'));
    await World.settle(tester);
    expect(starts, 1, reason: 'opening a protocol must not start another command');
    await tester.tap(find.text('Close'));
    await World.settle(tester);
    process.line(const host.Step('play', host.StepState.refused, words: 'Stopped by the test'));
    process.end(65);
    await World.settle(tester);
    await run.finished;
    expect(settings.hostUp('orchard')!.protocol, isNotEmpty);
    expect(find.byKey(const ValueKey('host-preparing orchard')), findsOneWidget);
  });

  // Harm: a host admin must see every account and membership that explicit teardown will permanently remove.
  testWidgets('give-back shows holders and purges only the names shown', (tester) async {
    final state = await openTakeDown(tester);
    expect(state.commands.single, ['down', ...signedSetup.giveBackArguments('orchard'), '--memberships']);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
    answerHolders(state.processes.single, [
      holder('alice', state: 'locked', purgeOn: '2000-01-01'),
      holder('bob', state: 'locked', purgeOn: '2000-01-02'),
      holder('retired', state: 'purged'),
    ]);
    await World.settle(tester);
    expect(find.textContaining('alice: locked'), findsOneWidget);
    expect(find.textContaining('bob: locked'), findsOneWidget);
    expect(find.textContaining('alice, bob and everything they hold here are permanently deleted'), findsOneWidget);
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

  // Harm: the machine purges only a person locked, listed in no project and past their purge day; one confirmed
  // otherwise is refused there, and the take-down stops with the machine kept and billed, its reason unsaid here.
  testWidgets('only those the machine can purge are offered, the others named with why not', (tester) async {
    final state = await openTakeDown(tester);
    answerHolders(state.processes.single, [
      holder('alice', admin: true),
      holder(
        'bob',
        state: 'locked',
        purgeOn: '2000-01-01',
        projects: [
          {'project': 'garden', 'role': 'member'},
        ],
      ),
      holder('carol', state: 'locked', purgeOn: '2000-01-01'),
      holder('dan', state: 'locked', purgeOn: '2999-01-01'),
    ]);
    await World.settle(tester);
    expect(find.textContaining('carol:'), findsOneWidget);
    expect(find.textContaining('alice: Machine Admin; not offered'), findsOneWidget);
    expect(find.textContaining('bob: garden (member); not offered'), findsOneWidget);
    expect(find.textContaining('still listed in a project'), findsOneWidget);
    expect(find.textContaining('dan: locked; not offered'), findsOneWidget);
    expect(find.textContaining('until 2999-01-01'), findsOneWidget);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    expect(state.commands.last, ['down', ...signedSetup.giveBackArguments('orchard'), '--purge', 'carol']);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
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

  // Harm: in a short window a long list of holders pushes the give-back's decision out of reach, or overflows.
  testWidgets('a long list of holders scrolls in a short window, with a sign that more stands below', (tester) async {
    final state = await openTakeDown(tester, size: const Size(1280, 480));
    answerHolders(state.processes.single, [
      for (var each = 0; each < 40; each++) holder('person$each', state: 'locked', purgeOn: '2000-01-01'),
    ]);
    await World.settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.byKey(const Key('dialog-scrollbar'))),
      findsOneWidget,
    );
    await tester.ensureVisible(find.textContaining('person39:'));
    await World.settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNotNull);
    expect(tester.getRect(find.byKey(const Key('host-confirm-down'))).bottom, lessThanOrEqualTo(480));
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

  // Harm: a machine just taken off the list is still said to be named by the organization.
  testWidgets('a removal that went through takes back the words that the organization still names it', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final fixture = HostFixture()..cardAddress = '192.0.2.7';
    final access = await fixture.access(settings);
    final state = await openTakeDown(tester, hostAccess: access, removeFromOrganization: (_) async => null);
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await World.settle(tester);
    expect(find.textContaining('The organization still names'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a removal that never answers holds Close for as long as the organization's commands may take.
  testWidgets('a removal that does not answer in time is said, and Close is free', (tester) async {
    final never = Completer<String?>();
    final state = await openTakeDown(tester, removeFromOrganization: (_) => never.future);
    answerHolders(state.processes.single, []);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    state.processes.last.line(const host.Step('give-back', host.StepState.done));
    state.processes.last.end(0);
    await tester.pump(const Duration(minutes: 3));
    await World.settle(tester);
    expect(find.textContaining("stays on the organization's list"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: someone admitted after confirmation must never be purged without a new explicit choice.
  testWidgets('a refused down reads new holders and waits for their confirmation', (tester) async {
    final state = await openTakeDown(tester);
    answerHolders(state.processes.single, [holder('alice', state: 'locked', purgeOn: '2000-01-01')]);
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
    answerHolders(state.processes.last, [holder('charlie', state: 'locked', purgeOn: '2000-01-01')]);
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
      final handed = <HostPreparation>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openHostRunDialog(
                context,
                run: run,
                hostRuns: runs,
                machines: machines,
                settings: settings,
                onEnterKeyAgain: handed.add,
              ),
              child: const Text('Open the protocol'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open the protocol'));
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
      expect(handed, [same(run)], reason: 'the setup wizard takes it, at its key');
      expect(find.byType(HostDialog), findsNothing, reason: 'the protocol makes way for the wizard');
      expect(runs.of('orchard'), same(run), reason: 'let go only once a new one starts');
      expect(settings.hostUp('orchard'), isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
          find.descendant(of: find.byKey(const Key('following-output')), matching: find.byType(Scrollable)).first,
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

  // Harm: a setup that never started, refused for its identity, opens on an empty protocol that says nothing.
  testWidgets("a run that did not start shows why in its dialog", (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    addTearDown(() {
      machines.dispose();
      settings.dispose();
    });
    final run = HostPreparation(
      project: 'orchard',
      session: HostSession(executable: 'fake', arguments: const [])..state = HostRunState.refused,
      record: signedSetup,
    )..problem = 'Setup of orchard did not start: Your Porelo-Vault is shut: open it, then try again.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'orchard', machines: machines, settings: settings, existingRun: run),
        ),
      ),
    );
    await World.settle(tester);
    expect(find.textContaining('did not start: Your Porelo-Vault is shut'), findsOneWidget);
  });

  group("the server's identity before a give-back", () {
    FilledButton ordinary(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down')));

    // Harm: a server goes back while its keys are in no vault, and the keys the central forge knows are lost with it.
    testWidgets('kept first, the ordinary give-back waits for it and then goes', (tester) async {
      final asked = <String>[];
      final held = Completer<IdentityKeeping?>();
      final state = await openTakeDown(
        tester,
        keepIdentity: (host) {
          asked.add(host);
          return held.future;
        },
      );
      answerHolders(state.processes.single, []);
      await World.settle(tester);
      expect(asked, ['orchard']);
      expect(find.textContaining('Keeping the identity of orchard'), findsOneWidget);
      expect(ordinary(tester).onPressed, isNull, reason: 'not before the identity is kept');
      held.complete(const IdentityKeeping('orchard', IdentityKeepingState.kept));
      await World.settle(tester);
      expect(ordinary(tester).onPressed, isNotNull);
      expect(find.byKey(const Key('host-give-back-anyway')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // Harm: a give-back the person thinks safe leaves the server's keys at the central forge with nobody holding them.
    testWidgets('not kept, only giving it back anyway goes, and it names the keys left at the forge', (tester) async {
      var tries = 0;
      final state = await openTakeDown(
        tester,
        keepIdentity: (host) async {
          tries++;
          return const IdentityKeeping(
            'orchard',
            IdentityKeepingState.refused,
            why: 'Your Porelo-Vault is shut: open it, then try again.',
          );
        },
      );
      answerHolders(state.processes.single, []);
      await World.settle(tester);
      expect(ordinary(tester).onPressed, isNull);
      expect(find.textContaining('The identity of orchard is not kept in your Porelo-Vault'), findsOneWidget);
      expect(find.textContaining('Your Porelo-Vault is shut'), findsOneWidget);
      expect(find.textContaining('stay at the central forge until they are removed there by hand'), findsOneWidget);
      await tester.tap(find.byKey(const Key('host-keep-identity-again')));
      await World.settle(tester);
      expect(tries, 2);
      await tester.tap(find.byKey(const Key('host-give-back-anyway')));
      await World.settle(tester);
      expect(state.commands.last, contains('--give-back-anyway'));
      state.processes.last.end(65);
      await World.settle(tester);
      answerHolders(state.processes.last, []);
      await World.settle(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // Harm: a give-back anyway pressed while the identity is being kept again cuts the keeping off, and the keys go
    // with no word that they do.
    testWidgets('while it is kept again, giving it back anyway waits, and the keys left behind are said', (
      tester,
    ) async {
      var tries = 0;
      final again = Completer<IdentityKeeping?>();
      final state = await openTakeDown(
        tester,
        keepIdentity: (host) {
          tries++;
          return tries == 1
              ? Future.value(const IdentityKeeping('orchard', IdentityKeepingState.refused, why: 'shut'))
              : again.future;
        },
      );
      answerHolders(state.processes.single, []);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('host-keep-identity-again')));
      await World.settle(tester);
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('host-give-back-anyway'))).onPressed,
        isNull,
        reason: 'not while the keeping runs',
      );
      expect(find.textContaining('stay at the central forge until they are removed there by hand'), findsOneWidget);
      again.complete(const IdentityKeeping('orchard', IdentityKeepingState.refused, why: 'shut'));
      await World.settle(tester);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('host-give-back-anyway'))).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

Map<String, Object?> holder(
  String login, {
  bool admin = false,
  String state = 'active',
  String? purgeOn,
  List<Object?> projects = const [],
}) => {'login': login, 'state': state, 'host_admin': admin, 'projects': projects, 'purge_on': ?purgeOn};

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
  HostAccess? hostAccess,
  List<Project>? itsDaemonLists,
  Size size = const Size(1280, 800),
  Future<IdentityKeeping?> Function(String host)? keepIdentity,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = Settings(store ?? MemorySettingsStore());
  await settings.rememberHostUp('orchard', record);
  final backend = FakeBackend(const []);
  final machines = Machines(settings, reach: (_) => backend, tunnels: RecordingTunnels());
  addTearDown(() {
    machines.dispose();
    settings.dispose();
  });
  if (itsDaemonLists != null) {
    // The machine given back, watched here through its card, its daemon listing these.
    backend.theProjectsItHas = itsDaemonLists;
    final card = host.HostCardSsh(
      name: 'orchard',
      address: '203.0.113.9',
      sshPort: 22,
      hostKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
      login: 'hana',
      publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
    );
    await machines.add(Machine.fromHostCard(card, socketPath: '/unused'));
    await World.settle(tester);
  }
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
            hostAccess: hostAccess,
            keepIdentity: keepIdentity,
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

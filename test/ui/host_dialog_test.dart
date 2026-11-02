import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_process.dart';
import '../support/host_organization.dart';
import '../support/host_rental.dart';
import '../support/signed_host.dart';

void main() {
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
    expect(find.textContaining('host admin'), findsOneWidget);
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
  // Harm: preparation must use the chosen pinned host, collection and limits, and retain readiness when signing is unavailable.
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
              project: '',
              machines: machines,
              settings: settings,
              hostRuns: runs,
              pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
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

        await type('Host name', 'orchard');
        await type('Server address', address);
        await type('SSH host key', hostKey);
        await tester.ensureVisible(find.text('Choose collection'));
        await World.settle(tester);
        await tester.tap(find.text('Choose collection'));
        await tester.pump();
        await type('Collection SHA-256', 'a' * 64);
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
        await tester.tap(find.text('Prepare the host'));
        await World.settle(tester);
        final run = runs.of('orchard')!;
        expect(arguments, ['up', ...hostArguments(run.record, 'orchard')]);
        expect(arguments, containsAllInOrder(['--given', address, '--host-key', hostKey]));
        expect(arguments, contains('--machine-file'));
        expect(
          arguments,
          containsAllInOrder(['--forge-runner-capacity', '1', '--forge-job-cpus', '1', '--forge-job-memory', '768m']),
        );
        expect(
          arguments,
          containsAllInOrder(['--collection', '/collections/host.tar.gz', '--collection-sha256', 'a' * 64]),
        );
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
        expect(fixture.writes.single.input['address'], address);
        final restored = hostUpRestored(settings.hostUp('orchard')!);
        expect(restored.givenAddress, address);
        expect(restored.givenHostKey, hostKey);
        expect(hostArguments(restored, 'orchard'), contains('/collections/host.tar.gz'));
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
            project: '',
            machines: machines,
            hostRuns: runs,
            pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
            start: (_, _) async {
              starts++;
              return HostProcess()..end(65);
            },
          ),
        ),
      );
      for (final field in {
        'Host name': 'orchard',
        'Server address': '203.0.113.7',
        'SSH host key': hostKey,
        'Collection SHA-256': 'a' * 64,
      }.entries) {
        final finder = find.widgetWithText(TextField, field.key);
        await tester.ensureVisible(finder);
        await World.settle(tester);
        await tester.enterText(finder, field.value);
      }
      await tester.ensureVisible(find.text('Choose collection'));
      await World.settle(tester);
      await tester.tap(find.text('Choose collection'));
      await World.settle(tester);
      await tester.tap(find.text('Prepare the host'));
      await World.settle(tester);
      expect(tester.takeException(), isNull);
      expect(starts, 0);
      expect(settings.hostUp('orchard')?.stored, kept);
      if (previous != null) expect(runs.of('orchard'), same(previous));
      expect(find.textContaining('already'), findsWidgets);
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
          project: '',
          machines: machines,
          hostRuns: runs,
          pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
          start: (_, _) async {
            starts++;
            return HostProcess();
          },
        ),
      ),
    );
    for (final field in {
      'Host name': 'orchard',
      'Server address': '203.0.113.7',
      'SSH host key': hostKey,
      'Collection SHA-256': 'a' * 64,
    }.entries) {
      final finder = find.widgetWithText(TextField, field.key);
      await tester.ensureVisible(finder);
      await World.settle(tester);
      await tester.enterText(finder, field.value);
    }
    await tester.ensureVisible(find.text('Choose collection'));
    await World.settle(tester);
    await tester.tap(find.text('Choose collection'));
    await World.settle(tester);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the host'));
    fixture.admin = false;
    button.onPressed!();
    await World.settle(tester);
    expect(starts, 0);
    expect(runs.of('orchard'), isNull);
    expect(find.textContaining('Only a host admin'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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
        home: HostDialog(
          project: '',
          machines: machines,
          hostRuns: runs,
          pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
          start: (_, _) async => HostProcess(),
        ),
      ),
    );
    await World.settle(tester);
    FilledButton prepare() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the host'));
    expect(prepare().onPressed, isNull);
    expect(find.textContaining('Name the host first'), findsOneWidget);
    final name = find.widgetWithText(TextField, 'Host name');
    await tester.enterText(name, 'pear');
    await World.settle(tester);
    expect(prepare().onPressed, isNull);
    expect(find.textContaining('Before setup, run this'), findsNothing);
    await tester.enterText(name, 'orchard');
    await World.settle(tester);
    expect(find.textContaining('Before setup, run this'), findsOneWidget);
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
          project: '',
          machines: machines,
          hostRuns: runs,
          pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
          start: (_, _) async {
            starts++;
            return HostProcess();
          },
        ),
      ),
    );
    for (final field in {
      'Host name': 'orchard',
      'Server address': '203.0.113.7',
      'SSH host key': hostKey,
      'Collection SHA-256': 'a' * 64,
    }.entries) {
      final finder = find.widgetWithText(TextField, field.key);
      await tester.ensureVisible(finder);
      await World.settle(tester);
      await tester.enterText(finder, field.value);
    }
    await tester.ensureVisible(find.text('Choose collection'));
    await World.settle(tester);
    await tester.tap(find.text('Choose collection'));
    await World.settle(tester);
    expect(find.textContaining('Before setup, run this'), findsNothing, reason: 'the read has not ended');
    proof.hold!.complete();
    proof.hold = null;
    await World.settle(tester);
    expect(find.textContaining('Before setup, run this'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the host'));
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

Future<({Settings settings, List<List<String>> commands, List<HostProcess> processes})> openTakeDown(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = Settings(MemorySettingsStore());
  await settings.rememberHostUp('orchard', signedSetup);
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

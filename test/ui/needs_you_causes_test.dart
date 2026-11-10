import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/step/the_agent_of_ended_with_the_providers.dart';
import '../features/step/the_agent_of_finished_with_changed_files_outside_the_gate.dart';
import '../features/step/the_tile_says.dart';
import '../features/support/world.dart';
import '../support/expand_list_rows.dart';

/// The rows of *Needs you* whose id starts with [prefix], such as `question here/porelo-checkout-shell/`.
Finder _rows(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('attention-row $prefix');
});

String get _here => World.machines.current.name;

Future<void> _toNeedsYou(WidgetTester tester) async {
  World.shell.goTo(Section.attention);
  await World.settle(tester);
  await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  await World.settle(tester);
}

Finder _in(Finder row, Finder what) => find.descendant(of: row, matching: what);

void main() {
  // Harm: a question hides that the same work's agent ended, so the end is never read and its work is lost.
  testWidgets('a question and an ended agent of one task are two rows, each with its own action', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await theAgentOfEndedWithTheProviders(tester, 'porelo-checkout-shell', 402, 'This request requires more credits');
    World.backend.asking.add(World.blocked('api.example.test:443'));
    await _toNeedsYou(tester);

    final question = _rows('question $_here/porelo-checkout-shell/');
    final ended = _rows('ended $_here/porelo-checkout-shell');
    expect(question, findsOneWidget, reason: 'the question is a row of its own');
    expect(ended, findsOneWidget, reason: 'the ended agent is a row of its own');
    expect(_in(question, find.byKey(const Key('tile-let-through'))), findsOneWidget);
    expect(_in(question, find.byKey(const Key('ended-read-log'))), findsNothing);
    expect(_in(ended, find.byKey(const Key('ended-read-log'))), findsOneWidget);
    expect(_in(ended, find.byKey(const Key('tile-let-through'))), findsNothing);
  });

  // Harm: an ended agent hides the push its work left at the gate, or the push hides the end.
  testWidgets('an ended agent and its push at the gate are two rows, each with its own action', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.theWorkIs(
      'porelo-checkout-migrate',
      activity: 'ENDED',
      agentEnded: <String, dynamic>{
        'at': '2026-10-03T12:57:30Z',
        'finished': false,
        'error': 'This request requires more credits',
        'source': 'provider',
        'status': 402,
        'unpushed': 0,
      },
      waiting: 1,
    );
    await _toNeedsYou(tester);

    final ended = _rows('ended $_here/porelo-checkout-migrate');
    final gate = _rows('gate $_here/porelo-checkout-migrate');
    expect(ended, findsOneWidget);
    expect(gate, findsOneWidget);
    expect(_in(ended, find.byKey(const Key('ended-read-log'))), findsOneWidget);
    expect(_in(ended, find.text('Review at the gate')), findsNothing, reason: 'the review is the gate row\'s action');
    expect(_in(gate, find.text('Review at the gate')), findsOneWidget);
    expect(_in(gate, find.byKey(const Key('ended-read-log'))), findsNothing);
    expect(_in(find.byKey(const ValueKey<String>('needs-group reviews')), gate), findsOneWidget);
  });

  // Harm: a decision offered with one answer only, so blocking needs a detour or letting through is forced.
  testWidgets('a decision row offers both answers, and each reaches the machine', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.asking.add(World.blocked('api.example.test:443'));
    await _toNeedsYou(tester);

    final question = _rows('question $_here/porelo-checkout-shell/');
    final keep = _in(question, find.byKey(const Key('tile-keep-blocked')));
    final allow = _in(question, find.byKey(const Key('tile-let-through')));
    expect(tester.widget<ButtonStyleButton>(keep).onPressed, isNotNull);
    expect(tester.widget<ButtonStyleButton>(allow).onPressed, isNotNull);
    await tester.tap(keep);
    await World.settle(tester);
    expect(World.backend.decisions.single.allow, isFalse);
  });

  // Harm: a held message is released or refused without its text having been read.
  testWidgets('a held message is decided only after it was read', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    final message = HeldMessage.from(const <String, dynamic>{
      'task': 'porelo-checkout-shell',
      'message': 'held.json',
      'standing': 'held',
      'direction': 'out',
      'peer': 'reviewer',
    });
    World.backend.heldForAPerson.add(message);
    await World.machines.of(World.machines.current).mailboxes.refresh();
    await _toNeedsYou(tester);

    final open = find.byKey(const Key('open-attention'));
    expect(_in(open, find.byKey(const Key('release-message'))), findsNothing, reason: 'no decision on the row');
    expect(_in(open, find.byKey(const Key('refuse-message'))), findsNothing, reason: 'no decision on the row');

    final read = find.byKey(const ValueKey('read-message porelo-checkout-shell/held.json'));
    await tester.ensureVisible(read);
    await tester.tap(read);
    await World.settle(tester);
    expect(find.byKey(const Key('held-message-dialog')), findsOneWidget);
    expect(find.byKey(const Key('release-message')), findsNothing, reason: 'its text was not read');
    expect(find.byKey(const Key('refuse-message')), findsNothing, reason: 'its text was not read');
    await tester.tap(find.byKey(const Key('held-message-close')));
    await World.settle(tester);

    World.backend.readable[message.handle] = HeldMessageRead.from(<String, dynamic>{
      'outcome': 'FOUND',
      'message': message.handle,
      'standing': 'held',
      'text': <String>['Please review this work.'],
    });
    await tester.ensureVisible(read);
    await tester.tap(read);
    await World.settle(tester);
    expect(find.text('Please review this work.'), findsWidgets);
    expect(find.byKey(const Key('release-message')), findsOneWidget, reason: 'read, it can be decided');
    expect(World.backend.released, isEmpty);
  });

  // Harm: work nothing guards, a question's deadline, files that never reached the gate or a question about work the
  // machine does not list yet go unsaid once the task's tile is no longer inside the row.
  testWidgets('what only the tile said stands on the row of its cause', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    final audit = World.backend.tasksNow.firstWhere((task) => task.name == 'porelo-billing-audit');
    World.backend.publish(<Task>[
      for (final task in World.backend.tasksNow)
        if (task == audit) Task.from(<String, dynamic>{...wire(audit), 'waiting': 1}) else task,
    ]);
    await theAgentOfFinishedWithChangedFilesOutsideTheGate(tester, 'porelo-checkout-shell', 2);
    // Let through once before, then asked again on another port of the same host.
    final before = World.blocked('api.example.test:443', task: 'porelo-billing-shell');
    World.backend.asking.add(before);
    await World.settle(tester);
    World.backend.asking.add(World.settled(before, 'allow'));
    World.backend.asking.add(World.blocked('api.example.test:8443', task: 'porelo-billing-shell', deadline: ''));
    World.backend.asking.add(World.blocked('files.example.test:22', task: 'porelo-not-listed'));
    await _toNeedsYou(tester);

    final gate = _rows('gate $_here/porelo-billing-audit');
    expect(gate, findsOneWidget);
    expect(_in(gate, find.byKey(const Key('unenforced'))), findsOneWidget, reason: 'nothing guards this work');

    final ended = _rows('ended $_here/porelo-checkout-shell');
    expect(ended, findsOneWidget);
    expect(_in(ended, find.textContaining('2 changed files never reached the gate')), findsWidgets);

    final asked = _rows('question $_here/porelo-billing-shell/tcp/api.example.test:8443');
    expect(asked, findsOneWidget);
    expect(_in(asked, find.textContaining('does not run out')), findsOneWidget, reason: 'its deadline');
    expect(_in(asked, find.byKey(const Key('asked-before'))), findsOneWidget, reason: 'let through before');

    final orphan = _rows('question $_here/porelo-not-listed/');
    expect(orphan, findsOneWidget);
    expect(_in(orphan, find.textContaining("not on this machine's list")), findsOneWidget);
  });

  // Harm: a row of Needs you carries the task's whole tile, its menu and its buttons, so the one thing to do is lost.
  testWidgets('no task tile is embedded in a row of Needs you', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.asking.add(World.blocked('api.example.test:443'));
    await _toNeedsYou(tester);

    final open = find.byKey(const Key('open-attention'));
    final tiles = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && (key.value.startsWith('tile ') || key.value.startsWith('tile-menu '));
    });
    expect(_in(open, tiles), findsNothing);
    expect(_rows('question '), findsOneWidget);
    expect(_rows('gate '), findsOneWidget);
  });

  // Harm: changed files that never reached the gate are marked seen and lost with the task; a question or a push is
  // waved away as seen.
  testWidgets('Seen stands only on what informs: not on an end with files outside the gate', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await theAgentOfFinishedWithChangedFilesOutsideTheGate(tester, 'porelo-checkout-shell', 2);
    await theAgentOfEndedWithTheProviders(tester, 'porelo-billing-shell', 402, 'This request requires more credits');
    World.backend.asking.add(World.blocked('files.example.test:22', task: 'porelo-billing-audit'));
    await _toNeedsYou(tester);

    final owed = _rows('ended $_here/porelo-checkout-shell');
    final informs = _rows('ended $_here/porelo-billing-shell');
    expect(owed, findsOneWidget);
    expect(_in(owed, find.byKey(const Key('ended-put-away'))), findsNothing, reason: 'its files are owed');
    expect(_in(informs, find.byKey(const Key('ended-put-away'))), findsOneWidget, reason: 'it only informs');
    for (final row in [_rows('question '), _rows('gate ')]) {
      expect(row, findsOneWidget);
      expect(_in(row, find.byKey(const Key('ended-put-away'))), findsNothing);
      expect(_in(row, find.text('Seen')), findsNothing);
    }
  });

  // Harm: a scenario about Needs you passes on what Work says, so a fact missing from Needs you goes unseen.
  testWidgets('the steps about a tile read its row under Needs you, never Work', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.asking.add(World.blocked('api.example.test:443'));
    await _toNeedsYou(tester);

    await expectLater(
      theTileSays(tester, 'porelo-checkout-shell', 'Way of working'),
      throwsA(isA<TestFailure>()),
      reason: 'only a row of Work says how its work works',
    );
    expect(World.shell.section, Section.attention, reason: 'the step stays where the scenario is');
    await theTileSays(tester, 'porelo-checkout-shell', 'does not say when');
  });
  // Harm: what only informs asks for a word nobody agreed on, or can only be put away by opening it.
  testWidgets('a question that ran out and a failed operation each offer Seen', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.asking.add(World.blocked('api.example.test:443'));
    await World.settle(tester);
    World.backend.asking.add(World.settled(World.blocked('api.example.test:443'), 'timeout'));
    World.operations.run(
      title: 'Show what this project would open',
      output: Stream<Object>.error(Exception('could not read project.yml')),
    );
    await _toNeedsYou(tester);

    expect(_in(_rows('ran out '), find.text('Seen')), findsOneWidget);
    final seen = find.byKey(const Key('failed-operation-seen'));
    expect(seen, findsOneWidget, reason: 'a failure can be seen without opening what it printed');
    await tester.ensureVisible(seen);
    await World.settle(tester);
    await tester.tap(seen);
    await World.settle(tester);
    expect(World.operations.all.where((each) => each.failed && !each.seen), isEmpty);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import 'planning.dart';
import 'planning_details.dart';
import 'world.dart';

import 'package:porelo_frontend/src/ui/wizard.dart';

import '../../support/expand_list_rows.dart';
import '../../support/planned_orders.dart';
import '../../support/menu_entries.dart';
import '../../support/planning_embedding.dart';

/// The window's wizard frame's own controls, under the names the screen's plain frame gives them.
const _frame = <String, String>{
  'story-work-start': 'wizard-start',
  'story-work-cancel': 'wizard-leave',
  'story-work-next': 'wizard-next',
  'story-work-back': 'wizard-back',
};

/// Whether Start work shows in the window's own wizard; a narrow host shows the screen's plain frame alone.
bool _inWindowWizard() => find.byType(Wizard).evaluate().isNotEmpty;

/// The actual UI elements used by the story work scenarios, in whichever frame Start work shows.
Finder workKey(String key) => switch (key) {
  'story-work-dialog' => find.byType(Wizard),
  _ when _inWindowWizard() => find.byKey(Key(_frame[key] ?? key)),
  _ => find.byKey(Key(key)),
};

/// Walks Start work to the step that shows [key]: forward while Next goes on, then back; to the review for its start.
/// Answers what is found, or, for the start of a frame that cannot reach its review, the Next that holds it.
Future<Finder> workSee(WidgetTester tester, String key) async {
  final found = workKey(key);
  final next = workKey('story-work-next');
  if (found.evaluate().isNotEmpty || next.evaluate().isEmpty) return found;
  final start = workKey('story-work-start');
  final back = workKey('story-work-back');
  Future<bool> step(Finder control) async {
    if (control.evaluate().isEmpty) return false;
    if (tester.widget<ButtonStyleButton>(control).onPressed == null) return false;
    await tester.ensureVisible(control);
    await tester.tap(control);
    await World.settle(tester);
    return true;
  }

  while (found.evaluate().isEmpty && start.evaluate().isEmpty) {
    if (!await step(next)) break;
  }
  if (found.evaluate().isNotEmpty) return found;
  if (key == 'story-work-start') return next;
  while (found.evaluate().isEmpty) {
    if (!await step(back)) break;
  }
  return found;
}

/// Brings a scrollable form control into view before using it.
Future<void> workTap(WidgetTester tester, String key) async {
  var found = workKey(key);
  // The board builds only the cards in view, so a card's menu off screen is first walked to.
  if (found.evaluate().isEmpty && key.startsWith('planning-')) {
    await revealPlanning(tester, found);
  }
  if (key.startsWith('story-work-')) found = await workSee(tester, key);
  expect(found, findsOneWidget);
  await tester.ensureVisible(found);
  await tester.tap(found);
  await World.settle(tester);
}

/// Enters a choice in the real form, then lets its validation redraw.
Future<void> workText(WidgetTester tester, String key, String text) async {
  final found = await workSee(tester, key);
  expect(found, findsOneWidget);
  await tester.ensureVisible(found);
  await tester.enterText(found, text);
  await tester.pump();
}

/// Fixed repository identity supplied by this scenario fixture.
String workRepository() => 'porelo';

/// Fixed issue identity supplied by this scenario fixture.
const storyReadingIssue = 'B540';

/// Uses a 390-wide component host while the test view remains 1280x800.
Future<void> openNarrowWork(WidgetTester tester) async {
  final board = PlanningBoard(World.planning, 'checkout');
  await World.settle(tester);
  final work = planningStoryWork(board, board.stories.firstWhere((story) => story.id == 'ST291'), 'In analysis');
  addTearDown(() {
    work.dispose();
    board.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 800,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(390, 800)),
              child: StoryWorkWizard(work),
            ),
          ),
        ),
      ),
    ),
  );
  await World.settle(tester);
}

/// Sets daemon-side conditions without bypassing the form's actions.
Future<void> prepareWork(WidgetTester tester, String condition) async {
  switch (condition) {
    case 'closed story':
      final board = planningFixture();
      // A story closes with its issues: the planner refuses to finish one whose issues stay open.
      planningStoryStands(board, 'ST291', 'Finished');
      await pushPlanning(tester, board);
    case 'working without work':
      final board = planningFixture();
      planningStoryStands(board, 'ST291', 'In analysis');
      World.planning.work.statuses['ST291'] = {};
      await pushPlanning(tester, board);
    case 'unknown work':
      final board = planningFixture();
      planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291')['work'] = <String, dynamic>{};
      await pushPlanning(tester, board);
    case 'only unattended':
      final proposed = World.planning.work.call('ProposeStoryWork', {
        'project': 'checkout',
        'story': 'ST291',
        'to': 'In analysis',
      });
      World.planning.work.proposals['ST291'] = {
        ...proposed,
        'modes': ['UNATTENDED'],
      };
    case 'one issue held behind a blocker':
      final proposed = World.planning.work.call('ProposeStoryWork', {
        'project': 'checkout',
        'story': 'ST291',
        'to': 'In analysis',
      });
      World.planning.work.proposals['ST291'] = {
        ...proposed,
        'held': [
          {'issue': 'B542', 'reason': 'Waits on B540, which is not done'},
        ],
      };
    case 'second machine proposal':
      final proposed = World.planningOn(World.elsewhere).work
          .call('ProposeStoryWork', {'project': 'checkout', 'story': 'ST291', 'to': 'In analysis'});
      final repos = (proposed['repositories'] as List).cast<Map<String, dynamic>>();
      World.planningOn(World.elsewhere).work.proposals['ST291'] = {
        ...proposed,
        'repositories': [
          for (final repo in repos)
            {
              ...repo,
              'main': {...repo['main'] as Map<String, dynamic>, 'model': 'other-machine-model'},
            },
        ],
      };
    case 'start refused':
      World.planning.work.refusal = 'The repository cannot start on this machine.';
    case 'reading refused':
      World.planning.work.refusal = 'This reading cannot be resolved now.';
    case 'new revision':
      final board = {...World.planning.boards['checkout']!, 'revision': 'changed-elsewhere'};
      await pushPlanning(tester, board);
    case 'ended task answer':
      World.theWorkIs(
        'porelo-checkout-shell',
        activity: 'ENDED',
        running: false,
        agentEnded: {
          'at': 'instant',
          'finished': false,
          'error': 'Needs a repository decision.',
          'answer': 'Outcome: blocked - needs the repository key.',
        },
      );
    case 'ended blocked':
      final board = planningFixture();
      planningStoryStands(board, 'ST291', 'In analysis');
      planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291')['work'] = {
        'atWork': false,
        'tasks': [
          {
            'task': 'main',
            'role': authorRole,
            'readLanded': <String>[],
            'ended': {
              'outcome': 'BLOCKED',
              'at': 'instant',
              'why': 'Outcome: blocked - waiting for the repository key.',
              'answer': '',
            },
          },
        ],
      };
      await pushPlanning(tester, board);
    case 'started main task ended':
      final main = World.backend.tasksNow.firstWhere((task) => task.name.startsWith('mock-st291-porelo-author'));
      World.theWorkIs(
        main.name,
        activity: 'ENDED',
        running: false,
        agentEnded: {'at': 'the end', 'finished': false, 'error': 'Outcome: blocked - the key is missing.'},
        ended: {'outcome': 'FAILED', 'why': 'Outcome: blocked - the key is missing.', 'at': 'the end'},
      );
    case 'every started task ended':
      for (final task in World.backend.tasksNow.where((task) => task.name.startsWith('mock-st291-')).toList()) {
        // The row shows the outcome the task declared beside the run's end, as the machine lists an ended task.
        World.theWorkIs(
          task.name,
          activity: 'ENDED',
          running: false,
          agentEnded: {'at': 'the end', 'finished': true},
          ended: {'outcome': 'DONE', 'at': 'the end'},
        );
      }
      await World.settle(tester);
    case 'stopped reading':
    case 'stopped reading without echo':
    case 'stopped reading without blocking findings':
      final board = planningFixture();
      final story = planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291');
      final issue = (story['issues'] as List).first as Map<String, dynamic>;
      issue.addAll({'state': 'Reading', 'rounds': 3, 'roundsMost': 3, 'readingStopped': true});
      // An issue under reading puts its open story there, as the planner derives it.
      story['state'] = 'Reading';
      World.planning.work.findings[issue['id'] as String] = [
        {'number': 1, 'severity': 'NOTE', 'text': 'A small concern.'},
        // Rework with a blocking finding takes it as its reason; only without one does it need the person's words.
        if (condition != 'stopped reading without blocking findings')
          {'number': 2, 'severity': 'BLOCKING', 'text': 'A credential would leave the task.'},
      ];
      World.planning.work.deferEcho = condition == 'stopped reading without echo';
      await pushPlanning(tester, board);
    default:
      throw StateError('Unknown story work condition: $condition');
  }
  await World.settle(tester);
}

/// Drives the same controls a person uses.
Future<void> chooseWork(WidgetTester tester, String choice) async {
  switch (choice) {
    case 'other machine':
      await workTap(tester, 'story-work-machine');
      await tester.tap(find.text('elsewhere').last);
      await World.settle(tester);
    case 'open story menu':
      await workTap(tester, 'planning-menu ST291');
    case 'cancel':
      await workTap(tester, 'story-work-cancel');
    case 'start':
      await workTap(tester, 'story-work-start');
    case 'drop builder':
      await workTap(tester, 'story-work-choice ${workRepository()} porelo/B540/helper DROP');
    case 'comment and start':
      await workText(tester, 'story-work-comment', 'Use the chosen reading setup.');
      await workTap(tester, 'story-work-start');
    case 'with you':
      await workTap(tester, 'story-work-mode AGENT');
    case 'change main agent':
      await workTap(tester, 'story-work-main-agent porelo');
      await tester.tap(find.byKey(const Key('start-agent-choice an-agent')).last);
      await World.settle(tester);
    case 'change main model':
      await workText(tester, 'story-work-main-model porelo', 'chosen-main-model');
    case 'change builder':
      await workTap(tester, 'story-work-choice porelo porelo/B540/helper CHANGE');
    case 'change builder agent':
      await workTap(tester, 'story-work-agent porelo porelo/B540/helper');
      await tester.tap(find.byKey(const Key('start-agent-choice an-agent')).last);
      await World.settle(tester);
    case 'change builder model':
      await workText(tester, 'story-work-model porelo porelo/B540/helper', 'chosen-builder-model');
    case 'comment':
      await workText(tester, 'story-work-comment', 'Use the chosen reading setup.');
    case 'refold issue rounds':
      await workSee(tester, 'story-work-rounds');
      final perIssue = find.text('Per issue');
      await tester.ensureVisible(perIssue);
      await tester.tap(perIssue);
      await World.settle(tester);
      await tester.ensureVisible(perIssue);
      await tester.tap(perIssue);
      await World.settle(tester);
    case 'show closed cards':
      await workTap(tester, 'planning-fold-phase Done');
    case 'change builder and rounds':
      await workTap(tester, 'story-work-choice ${workRepository()} porelo/B540/helper CHANGE');
      await workText(tester, 'story-work-model ${workRepository()} porelo/B540/helper', 'chosen-builder-model');
      await workText(tester, 'story-work-rounds', '5');
      final perIssue = find.text('Per issue');
      await tester.ensureVisible(perIssue);
      await tester.tap(perIssue);
      await World.settle(tester);
      await workText(tester, 'story-work-rounds $storyReadingIssue', '7');
    case 'stop':
      await workTap(tester, 'planning-menu ST291');
      await workTap(tester, 'planning-stop ST291');
      await workTap(tester, 'story-work-stop-confirm');
    case 'expand attention':
      await expandListRows(tester);
    case 'needs you':
      await workTap(tester, 'rail attention');
    case 'put the reading away':
      final seen = find.byWidgetPredicate(
        (widget) => switch (widget.key) {
          ValueKey<String>(:final value) => value.startsWith('story-seen reading '),
          _ => false,
        },
      );
      expect(seen, findsOneWidget);
      await tester.ensureVisible(seen);
      await tester.tap(seen);
      await World.settle(tester);
    case 'send rework text':
      await workText(tester, 'reading-rework-comment', 'Keep credentials inside the task.');
      await workTap(tester, 'reading-rework-send');
    default:
      throw StateError('Unknown story work choice: $choice');
  }
}

/// Checks rendered widgets; RPC payloads are checked by client and model tests.
Future<void> proveWork(WidgetTester tester, String proof) async {
  Finder cardIn(String state) =>
      find.descendant(of: workKey('planning-state $state'), matching: workKey('planning-card ST291'));
  // A state may start folded or open, as the planner's preferences say: a tap that folded it away is taken back.
  Future<void> revealWork(String state) async {
    bool shown() => find.descendant(of: cardIn(state), matching: find.textContaining('tasks')).evaluate().isNotEmpty;
    if (shown()) return;
    await workTap(tester, 'planning-fold-state $state');
    if (!shown() && cardIn(state).evaluate().isEmpty) await workTap(tester, 'planning-fold-state $state');
  }

  String cardText() => planningText(tester, workKey('planning-card ST291'));
  switch (proof) {
    case 'proposal defaults and allowed modes':
      expect(tester.widget<TextFormField>((await workSee(tester, 'story-work-rounds'))).initialValue, '2');
      expect((await workSee(tester, 'story-work-coordinator')), findsOneWidget);
      expect((await workSee(tester, 'story-work-task porelo')), findsOneWidget);
      expect((await workSee(tester, 'story-work-task porelo-host')), findsOneWidget);
      expect(find.textContaining('B540, B541'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>((await workSee(tester, 'story-work-choice porelo porelo/B540/helper KEEP'))).selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>((await workSee(tester, 'story-work-choice porelo-host porelo-host/HO156/helper KEEP')))
            .selected,
        isTrue,
      );
      // The one mode the planner allows is no step of its own: the review says it, beside the start.
      await workSee(tester, 'story-work-start');
      expect(find.text('Unattended'), findsOneWidget);
      expect(workKey('story-work-mode AGENT'), findsNothing);
      expect(find.text('Start 2 tasks'), findsOneWidget);
    case 'held issue and its blocker visible':
      expect(_inWindowWizard(), isTrue, reason: 'Start work shows in the window\'s own wizard here');
      expect((await workSee(tester, 'story-work-held B542')), findsOneWidget);
      expect(find.textContaining('Waits on B540, which is not done'), findsOneWidget);
    case 'held issue and its blocker visible in a narrow host':
      expect((await workSee(tester, 'story-work-held B542')), findsOneWidget);
      expect(find.textContaining('Waits on B540, which is not done'), findsOneWidget);
    case 'other machine proposal visible':
      expect(find.textContaining('Story supplied by another machine'), findsOneWidget);
      final model = find.descendant(
        of: (await workSee(tester, 'story-work-main-model porelo')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(model).controller.text, 'other-machine-model');
    case 'drop dialog visible':
      expect(workKey('story-work-dialog'), findsOneWidget);
      expect(find.text('Backlog → In analysis'), findsOneWidget);
    case 'nothing started':
      expect(workKey('story-work-dialog'), findsNothing);
      expect(cardIn('Backlog'), findsOneWidget);
      expect(cardIn('In analysis'), findsNothing);
    case 'start unavailable':
      expect(menuEntryEnabled(tester, workKey('planning-start ST291')), isFalse);
      expect(find.text('Unavailable: work status not reported'), findsOneWidget);
    case 'start disabled':
      expect(workKey('story-work-dialog'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>((await workSee(tester, 'story-work-start'))).onPressed, isNull);
    case 'started behind the operation':
      // The start ran on after Start work closed: the machine runs the main task, and the board beneath, still built,
      // holds the story with its work.
      expect(World.backend.tasksNow.where((task) => task.name.startsWith('mock-st291-porelo-author')), isNotEmpty);
      final card = find.descendant(
        of: find.byKey(const Key('planning-state Backlog'), skipOffstage: false),
        matching: find.byKey(const Key('planning-card ST291'), skipOffstage: false),
      );
      expect(card, findsOneWidget);
      expect(workKey('story-work-dialog'), findsNothing);
    case 'running work visible':
      expect(workKey('story-work-dialog'), findsNothing);
      // The planner moves the story once it is told its tasks started, which the window does not tell yet.
      expect(cardIn('Backlog'), findsOneWidget);
      await revealWork('Backlog');
      // The work names a coordinator only once the planner's run records one.
      // How many tasks the run has is the planner's to say; the card shows that it runs some.
      expect(cardText(), contains(RegExp(r'\b[1-9][0-9]* tasks\b')));
      expect(cardText(), contains('codex'));
      expect(cardText(), contains('proposed-model'));
      expect(cardText(), contains('unattended'));
    case 'waiting card quiet':
    case 'closed card quiet':
      final card = cardIn(proof == 'closed card quiet' ? 'Finished' : 'Backlog');
      await revealPlanning(tester, card);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('The host run by a program of its own, built like porelo')),
        findsOneWidget,
      );
      expect(planningText(tester, card), isNot(contains('Work not reported')));
      expect(planningText(tester, card), isNot(contains('nobody at work')));
    case 'card needs you':
    case 'card quiet':
      final card = workKey('planning-card ST291');
      await revealPlanning(tester, card);
      expect(card, findsOneWidget);
      // A stopped reading says so on its card until the person has seen it in Needs you.
      expect(
        find.descendant(of: card, matching: find.text('stopped in Reading - needs you')),
        proof == 'card needs you' ? findsOneWidget : findsNothing,
      );
    case 'working work missing':
      await revealWork('In analysis');
      expect(cardText(), contains('Work not reported'));
    case 'start available':
      expect(menuEntryEnabled(tester, workKey('planning-start ST291')), isTrue);
    case 'started main model visible':
      expect(workKey('story-work-dialog'), findsNothing);
      await revealWork('Backlog');
      expect(cardText(), contains('chosen-main-model'));
      expect(cardText(), contains('an-agent'));
    case 'change proposal prefilled':
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              (await workSee(tester, 'story-work-agent porelo porelo/B540/helper')),
            )
            .initialValue,
        'codex',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: (await workSee(tester, 'story-work-model porelo porelo/B540/helper')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'proposed-model',
      );
    case 'per issue rounds retained':
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: (await workSee(tester, 'story-work-rounds B540')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '7',
      );
    case 'main model visible':
      expect(
        tester
            .widget<DropdownButtonFormField<String>>((await workSee(tester, 'story-work-main-agent porelo')))
            .initialValue,
        'an-agent',
      );
      final editable = find.descendant(
        of: (await workSee(tester, 'story-work-main-model porelo')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).controller.text, 'chosen-main-model');
      expect(tester.widget<FilledButton>((await workSee(tester, 'story-work-start'))).onPressed, isNotNull);
    case 'refusal and original board':
      expect(find.text('The repository cannot start on this machine.'), findsOneWidget);
      expect(cardIn('Backlog'), findsOneWidget);
      expect(cardIn('In analysis'), findsNothing);
      expect(workKey('story-work-dialog'), findsOneWidget);
    case 'stopped where it stands':
      expect(cardIn('Backlog'), findsOneWidget);
      expect(cardIn('Review'), findsNothing);
    case 'ended task answer visible':
      expect(find.byKey(const Key('tile-last-answer')), findsWidgets);
      expect(find.text('Outcome: blocked - needs the repository key.'), findsWidgets);
    case 'ended reason visible':
      expect((await workSee(tester, 'story-work-ended ST291')), findsOneWidget);
      expect(find.text('Outcome: blocked - waiting for the repository key.'), findsOneWidget);
    case 'blocking findings first':
      final blocking = find.text('Blocking: A credential would leave the task.');
      final note = find.text('Note: A small concern.');
      expect(blocking, findsOneWidget);
      expect(note, findsOneWidget);
      expect(tester.getTopLeft(blocking).dy, lessThan(tester.getTopLeft(note).dy));
    case 'reading removed from open attention':
      expect(workKey('open-attention'), findsOneWidget);
      expect(
        find.descendant(of: workKey('recently-resolved'), matching: find.textContaining('B540 · porelo · reading')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: workKey('open-attention'), matching: workKey('reading-resolve B540 REVIEW_ANYWAY')),
        findsNothing,
      );
    case 'reading put away':
      expect(
        find.descendant(of: workKey('open-attention'), matching: find.textContaining('B540 · porelo · reading')),
        findsNothing,
      );
      expect(World.settings.readingsPutAway.map((each) => each.issue), ['B540'], reason: 'kept in the settings');
    case 'decision waits for echo':
      expect(find.text('Waiting for the board to confirm the decision.'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(workKey('reading-resolve B540 ONE_MORE_ROUND')).onPressed, isNull);
      expect(find.textContaining('B540 · porelo · reading 3 of 3'), findsOneWidget);
    case 'rework text required':
      expect(workKey('reading-rework-comment'), findsOneWidget);
      expect(tester.widget<FilledButton>(workKey('reading-rework-send')).onPressed, isNull);
    case 'rework resolved on screen':
      expect(workKey('open-attention'), findsOneWidget);
      expect(
        find.descendant(of: workKey('recently-resolved'), matching: find.textContaining('B540 · porelo · reading')),
        findsOneWidget,
      );
      expect(workKey('reading-rework-comment'), findsNothing);
      expect(
        find.descendant(of: workKey('open-attention'), matching: workKey('reading-resolve B540 REWORK')),
        findsNothing,
      );
    case 'reading refusal visible':
      expect(find.text('This reading cannot be resolved now.'), findsOneWidget);
      expect(workKey('reading-resolve B540 REVIEW_ANYWAY'), findsOneWidget);
    case 'stale reading retained':
      final key = workKey('reading-resolve B540 REVIEW_ANYWAY');
      expect(key, findsOneWidget);
      expect(tester.widget<OutlinedButton>(key).onPressed, isNull);
      expect(find.text('The board changed or is no longer live.'), findsOneWidget);
    case 'reported end visible':
      // One row per issue the ended task raised, each saying how it ended.
      expect((await workSee(tester, 'story-work-ended ST291')), findsWidgets);
      expect(find.textContaining('Outcome: blocked - the key is missing.'), findsWidgets);
    case 'with you terminal':
      expect(workKey('running-name'), findsOneWidget);
      // The container Start answered for the story's main task, as the machine names it.
      expect(planningText(tester, workKey('running-name')), startsWith('mock-st291-porelo-author'));
      expect(workKey('running-none'), findsNothing);
      expect(workKey('terminal'), findsOneWidget);
    case 'narrow dialog usable':
      for (final key in ['story-work-task porelo', 'story-work-task porelo-host']) {
        final name = await workSee(tester, key);
        await tester.ensureVisible(name);
        await tester.pump();
        expect(name.hitTestable(), findsOneWidget);
        final text = tester.widget<Text>(name);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
        expect(text.data, key == 'story-work-task porelo' ? 'porelo' : 'porelo-host');
        expect(tester.getSize(name).width, lessThanOrEqualTo(390));
      }
      await workTap(tester, 'story-work-choice porelo porelo/B540/helper CHANGE');
      for (final key in ['story-work-agent porelo porelo/B540/helper', 'story-work-model porelo porelo/B540/helper']) {
        await tester.ensureVisible(workKey(key));
        await tester.pump();
        expect(workKey(key).hitTestable(), findsOneWidget);
      }
      await workText(tester, 'story-work-model porelo porelo/B540/helper', 'narrow-builder-model');
      await workSee(tester, 'story-work-rounds');
      final perIssue = find.text('Per issue');
      await tester.ensureVisible(perIssue);
      await tester.tap(perIssue);
      await World.settle(tester);
      await workText(tester, 'story-work-rounds B540', '6');
      expect((await workSee(tester, 'story-work-rounds B540')).hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: (await workSee(tester, 'story-work-rounds B540')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '6',
      );
      expect(tester.takeException(), isNull);
    default:
      throw StateError('Unknown story work proof: $proof');
  }
}

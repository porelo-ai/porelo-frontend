import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import 'planning.dart';
import 'world.dart';
import '../../support/expand_list_rows.dart';
import '../../support/planning_embedding.dart';

/// The actual UI elements used by the story work scenarios.
Finder workKey(String key) => find.byKey(Key(key));

/// Brings a scrollable form control into view before using it.
Future<void> workTap(WidgetTester tester, String key) async {
  final found = workKey(key);
  expect(found, findsOneWidget);
  await tester.ensureVisible(found);
  await tester.tap(found);
  await World.settle(tester);
}

/// Enters a choice in the real form, then lets its validation redraw.
Future<void> workText(WidgetTester tester, String key, String text) async {
  final found = workKey(key);
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
              child: StoryWorkDialog(work),
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
      planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291')['state'] = 'Finished';
      await pushPlanning(tester, board);
    case 'working without work':
      final board = planningFixture();
      planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291')['state'] = 'In analysis';
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
          'lastAnswer': 'Outcome: blocked - needs the repository key.',
        },
      );
    case 'ended blocked':
      final board = planningFixture();
      planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291')['state'] = 'In analysis';
      planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291')['work'] = {
        'atWork': false,
        'tasks': [
          {
            'task': 'main',
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
    case 'stopped reading':
    case 'stopped reading without echo':
      final board = planningFixture();
      final story = planningMaps(board, 'stories').firstWhere((story) => story['id'] == 'ST291');
      final issue = (story['issues'] as List).first as Map<String, dynamic>;
      issue.addAll({'state': 'Reading', 'rounds': 3, 'roundsMost': 3, 'readingStopped': true});
      World.planning.work.findings[issue['id'] as String] = [
        {'severity': 'NOTE', 'text': 'A small concern.'},
        {'severity': 'BLOCKING', 'text': 'A credential would leave the task.'},
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
    case 'drop reader':
      await workTap(tester, 'story-work-choice ${workRepository()} porelo/B540/READER DROP');
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
    case 'change reader':
      await workTap(tester, 'story-work-choice porelo porelo/B540/READER CHANGE');
    case 'change reader agent':
      await workTap(tester, 'story-work-agent porelo porelo/B540/READER');
      await tester.tap(find.byKey(const Key('start-agent-choice an-agent')).last);
      await World.settle(tester);
    case 'comment':
      await workText(tester, 'story-work-comment', 'Use the chosen reading setup.');
    case 'refold issue rounds':
      final perIssue = find.text('Per issue');
      await tester.ensureVisible(perIssue);
      await tester.tap(perIssue);
      await World.settle(tester);
      await tester.ensureVisible(perIssue);
      await tester.tap(perIssue);
      await World.settle(tester);
    case 'show closed cards':
      await workTap(tester, 'planning-show-closed');
      await workTap(tester, 'planning-fold-phase Done');
    case 'change reader and rounds':
      await workTap(tester, 'story-work-choice ${workRepository()} porelo/B540/READER CHANGE');
      await workText(tester, 'story-work-model ${workRepository()} porelo/B540/READER', 'chosen-reader-model');
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
  Future<void> revealWork() async {
    if (find.descendant(of: cardIn('In analysis'), matching: find.textContaining('tasks')).evaluate().isEmpty) {
      await workTap(tester, 'planning-fold-state In analysis');
    }
  }

  String cardText() => planningText(tester, workKey('planning-card ST291'));
  switch (proof) {
    case 'proposal defaults and allowed modes':
      expect(workKey('story-work-mode UNATTENDED'), findsOneWidget);
      expect(workKey('story-work-mode AGENT'), findsNothing);
      expect(tester.widget<TextFormField>(workKey('story-work-rounds')).initialValue, '2');
      expect(workKey('story-work-coordinator'), findsOneWidget);
      expect(workKey('story-work-task porelo'), findsOneWidget);
      expect(workKey('story-work-task porelo-host'), findsOneWidget);
      expect(find.textContaining('B540, B541'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(workKey('story-work-choice porelo porelo/B540/READER KEEP')).selected, isTrue);
      expect(
        tester.widget<ChoiceChip>(workKey('story-work-choice porelo-host porelo-host/HO156/READER KEEP')).selected,
        isTrue,
      );
      expect(find.text('The agents work unattended.'), findsOneWidget);
      expect(find.text('Start 2 tasks'), findsOneWidget);
    case 'other machine proposal visible':
      expect(find.textContaining('Story supplied by another machine'), findsOneWidget);
      final model = find.descendant(of: workKey('story-work-main-model porelo'), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(model).controller.text, 'other-machine-model');
    case 'drop dialog visible':
      expect(workKey('story-work-dialog'), findsOneWidget);
      expect(find.text('Backlog → In analysis'), findsOneWidget);
    case 'nothing started':
      expect(workKey('story-work-dialog'), findsNothing);
      expect(cardIn('Backlog'), findsOneWidget);
      expect(cardIn('In analysis'), findsNothing);
    case 'start unavailable':
      expect(tester.widget<PopupMenuItem<String>>(workKey('planning-start ST291')).enabled, isFalse);
      expect(find.text('Unavailable: work status not reported'), findsOneWidget);
    case 'start disabled':
      expect(workKey('story-work-dialog'), findsOneWidget);
      expect(tester.widget<FilledButton>(workKey('story-work-start')).onPressed, isNull);
    case 'running work visible':
      expect(workKey('story-work-dialog'), findsNothing);
      expect(cardIn('In analysis'), findsOneWidget);
      await revealWork();
      expect(cardText(), contains('coordinator'));
      expect(cardText(), contains('2 tasks'));
      expect(cardText(), contains('codex'));
      expect(cardText(), contains('proposed-model'));
      expect(cardText(), contains('unattended'));
    case 'waiting card quiet':
    case 'closed card quiet':
      final card = cardIn(proof == 'closed card quiet' ? 'Finished' : 'Backlog');
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('The host run by a program of its own, built like porelo')),
        findsOneWidget,
      );
      expect(planningText(tester, card), isNot(contains('Work not reported')));
      expect(planningText(tester, card), isNot(contains('nobody at work')));
    case 'working work missing':
      await revealWork();
      expect(cardText(), contains('Work not reported'));
    case 'start available':
      expect(tester.widget<PopupMenuItem<String>>(workKey('planning-start ST291')).enabled, isTrue);
    case 'started main model visible':
      expect(workKey('story-work-dialog'), findsNothing);
      await revealWork();
      expect(cardText(), contains('chosen-main-model'));
      expect(cardText(), contains('an-agent'));
    case 'change proposal prefilled':
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(workKey('story-work-agent porelo porelo/B540/READER'))
            .initialValue,
        'claude-code',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: workKey('story-work-model porelo porelo/B540/READER'),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'reader-model',
      );
    case 'per issue rounds retained':
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: workKey('story-work-rounds B540'), matching: find.byType(EditableText)),
            )
            .controller
            .text,
        '7',
      );
    case 'main model visible':
      expect(
        tester.widget<DropdownButtonFormField<String>>(workKey('story-work-main-agent porelo')).initialValue,
        'an-agent',
      );
      final editable = find.descendant(
        of: workKey('story-work-main-model porelo'),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).controller.text, 'chosen-main-model');
      expect(tester.widget<FilledButton>(workKey('story-work-start')).onPressed, isNotNull);
    case 'refusal and original board':
      expect(find.text('The repository cannot start on this machine.'), findsOneWidget);
      expect(cardIn('Backlog'), findsOneWidget);
      expect(cardIn('In analysis'), findsNothing);
      expect(workKey('story-work-dialog'), findsOneWidget);
    case 'stopped in working state':
      expect(cardIn('In analysis'), findsOneWidget);
      await revealWork();
      expect(cardText(), contains('nobody at work'));
      expect(cardIn('Review'), findsNothing);
    case 'ended task answer visible':
      expect(find.byKey(const Key('tile-last-answer')), findsWidgets);
      expect(find.text('Outcome: blocked - needs the repository key.'), findsWidgets);
    case 'ended reason visible':
      expect(workKey('story-work-ended ST291'), findsOneWidget);
      expect(find.text('Outcome: blocked - waiting for the repository key.'), findsOneWidget);
    case 'blocking findings first':
      final blocking = find.text('BLOCKING: A credential would leave the task.');
      final note = find.text('NOTE: A small concern.');
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
    case 'with you terminal':
      expect(workKey('running-name'), findsOneWidget);
      expect(planningText(tester, workKey('running-name')), contains('coordinator'));
      expect(workKey('running-none'), findsNothing);
      expect(workKey('terminal'), findsOneWidget);
    case 'narrow dialog usable':
      for (final key in ['story-work-task porelo', 'story-work-task porelo-host']) {
        final name = workKey(key);
        await tester.ensureVisible(name);
        await tester.pump();
        expect(name.hitTestable(), findsOneWidget);
        final text = tester.widget<Text>(name);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
        expect(text.data, key == 'story-work-task porelo' ? 'porelo' : 'porelo-host');
        expect(tester.getSize(name).width, lessThanOrEqualTo(390));
      }
      await workTap(tester, 'story-work-choice porelo porelo/B540/READER CHANGE');
      for (final key in ['story-work-agent porelo porelo/B540/READER', 'story-work-model porelo porelo/B540/READER']) {
        await tester.ensureVisible(workKey(key));
        await tester.pump();
        expect(workKey(key).hitTestable(), findsOneWidget);
      }
      await workText(tester, 'story-work-model porelo porelo/B540/READER', 'narrow-reader-model');
      final perIssue = find.text('Per issue');
      await tester.ensureVisible(perIssue);
      await tester.tap(perIssue);
      await World.settle(tester);
      await workText(tester, 'story-work-rounds B540', '6');
      expect(workKey('story-work-rounds B540').hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: workKey('story-work-rounds B540'), matching: find.byType(EditableText)),
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

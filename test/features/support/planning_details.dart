import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/ui/panes.dart';
import 'package:porelo_planning/planning_fake.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../step/a_backend_with_planning.dart';
import 'planning.dart';
import 'world.dart';
import '../../support/planning_embedding.dart';

Completer<PlanStoryDetail>? _heldStory;
List<double>? _boardOffsets;
Set<String>? _folded;
OverlayEntry? _browser;
String? _browserAddress;

Map<String, dynamic> _story() => mockStory('ST291');

/// Returns the scenario's mutable story, without silently creating one.
Map<String, dynamic> mockStory(String id) =>
    planningMaps(World.planning.boards['checkout']!, 'stories').singleWhere((story) => story['id'] == id);
Map<String, dynamic> _issue() => planningMaps(_story(), 'issues').singleWhere((issue) => issue['id'] == 'B541');

/// Sets up source fields explicitly reported by this scenario's machine.
Future<void> startPlanningDetails(WidgetTester tester) async {
  await aBackendWithPlanning(tester);
  World.planning.boards['checkout'] = planningFixture();
  _heldStory = null;
  _boardOffsets = null;
  _folded = null;
  _browser = null;
  _browserAddress = null;
  _story()['description'] = '# Story source';
  _issue().addAll({
    'whatMustBeTrue': 'Only confirmed work is published',
    'findings': [
      {'number': 7, 'severity': 'NOTE', 'text': 'Keep the explanation', 'file': 'lib/note.dart'},
      {'number': 9, 'severity': 'BLOCKING', 'text': 'Check the boundary', 'file': 'lib/boundary.dart', 'line': 42},
    ],
    'subAgents': [
      {'name': 'Reader', 'role': 'review', 'agent': 'Agent', 'model': 'Model', 'brief': 'Read the final changes'},
    ],
  });
}

/// The scrolling column of each phase on the board, left to right.
final _phaseScrolls = find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('planning-phase-scroll '),
);

/// The scroll of one phase's column, given the column's own keyed widget.
ScrollableState _phaseScrollable(WidgetTester tester, Finder phase) =>
    tester.state<ScrollableState>(find.descendant(of: phase, matching: find.byType(Scrollable), matchRoot: true).first);

/// The scroll of the phase that holds [finder], built or not in its view.
ScrollableState planningPhaseHolding(WidgetTester tester, Finder finder) {
  final phase = find.ancestor(of: finder, matching: _phaseScrolls);
  expect(phase, findsOneWidget);
  return _phaseScrollable(tester, phase);
}

/// The scroll of the phase whose column is keyed [id].
ScrollableState planningPhaseScroll(WidgetTester tester, String id) =>
    _phaseScrollable(tester, planningElement('phase-scroll $id'));

/// The scroll of every column on the board, left to right: each phase's, then the column of stories whose state the
/// workflow does not report, which has no key of its own and is found by its heading.
List<ScrollableState> _columnScrolls(WidgetTester tester) {
  final scrolls = [
    for (final phase in _phaseScrolls.evaluate().toList()) _phaseScrollable(tester, find.byWidget(phase.widget)),
  ];
  final unplaced = find.text('Stories outside the reported workflow', skipOffstage: false);
  if (unplaced.evaluate().isNotEmpty) {
    final scroll = tester.state<ScrollableState>(find.ancestor(of: unplaced, matching: find.byType(Scrollable)).first);
    expect(scroll.position.axis, Axis.vertical);
    scrolls.add(scroll);
  }
  return scrolls;
}

/// Walks the board's columns (or the one [only]) from top to foot, half a view at a time, and asks [look] at each stop.
///
/// Each column builds only the cards in its view, so this is how a check sees a whole column. The walk stops where
/// [look] answers true and leaves that column there; every other column gets its offset back. A board with no column
/// shown fails the walk, so a check over it never passes for having looked at nothing.
Future<bool> walkPlanning(WidgetTester tester, bool Function() look, {ScrollableState? only}) async {
  final scrolls = only != null ? [only] : _columnScrolls(tester);
  expect(scrolls, isNotEmpty, reason: 'no column of the planning board is shown');
  for (final scroll in scrolls) {
    final position = scroll.position;
    final start = position.pixels;
    position.jumpTo(0);
    await tester.pump();
    while (true) {
      if (look()) return true;
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo((position.pixels + position.viewportDimension / 2).clamp(0, position.maxScrollExtent).toDouble());
      await tester.pump();
    }
    position.jumpTo(start.clamp(0, position.maxScrollExtent).toDouble());
    await tester.pump();
  }
  return false;
}

/// Brings [finder] into its phase's view: a phase builds only the cards in its view.
///
/// A box whose middle lies outside its phase's view is scrolled to the view's top, or to its middle when it is taller
/// than the view; [alignment] gives another place and always scrolls. The column's length is an estimate until its
/// last cards are built, so one `Scrollable.ensureVisible` can stop short: the test scrolls the phase itself.
Future<void> revealPlanning(WidgetTester tester, Finder finder, {double? alignment}) async {
  if (finder.evaluate().isEmpty) await walkPlanning(tester, () => finder.evaluate().isNotEmpty);
  final found = finder.evaluate();
  if (found.length != 1 || found.single.renderObject is! RenderBox) return;
  final phase = find.ancestor(of: finder, matching: _phaseScrolls);
  if (phase.evaluate().isEmpty) return;
  final scroll = _phaseScrollable(tester, phase);
  final view = tester.getRect(find.byWidget(scroll.widget));
  final rect = tester.getRect(finder);
  if (alignment == null) {
    if (rect.center.dy >= view.top && rect.center.dy <= view.bottom) return;
    alignment = rect.height > view.height ? 0.5 : 0;
  }
  final position = scroll.position;
  // The column's length is an estimate until the cards near its end are built, so the scroll is taken again.
  for (var tries = 0; tries < 5; tries++) {
    final rect = tester.getRect(finder);
    final to = (position.pixels + rect.top - view.top - (view.height - rect.height) * alignment)
        .clamp(0, position.maxScrollExtent)
        .toDouble();
    if ((to - position.pixels).abs() < 0.5) break;
    position.jumpTo(to);
    await tester.pump();
  }
}

/// Expects [finder] to find nothing anywhere on the board, its phases walked through.
Future<void> expectPlanningNowhere(WidgetTester tester, Finder finder) async {
  await walkPlanning(tester, () {
    expect(finder, findsNothing);
    return false;
  });
}

/// Opens an actual keyed action, scrolling it into view first.
Future<void> tapPlanning(WidgetTester tester, Finder finder) async {
  await revealPlanning(tester, finder);
  expect(finder, findsOneWidget);
  if (finder.hitTestable().evaluate().isEmpty) await tester.ensureVisible(finder);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await World.settle(tester);
}

/// Checks visible detail text: plain, selectable, or rendered from Markdown.
void expectPlanningDetail(String words, {bool present = true}) {
  final detail = planningElement('detail');
  expect(detail, findsOneWidget);
  final found = find.descendant(
    of: detail,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Text && ((widget.data ?? widget.textSpan?.toPlainText())?.contains(words) ?? false) ||
          widget is SelectableText && (widget.data?.contains(words) ?? false),
    ),
  );
  expect(found, present ? findsWidgets : findsNothing);
}

/// Ensures the breadcrumb is exact and each key names a real library widget.
Future<void> expectPlanningCrumbs(WidgetTester tester, String path) async {
  final parts = path.split(',');
  for (var i = 0; i < parts.length; i++) {
    final finder = planningElement('crumb $i');
    expect(finder, findsOneWidget);
    expect(planningText(tester, finder), parts[i]);
    await tester.ensureVisible(finder);
    expect(finder.hitTestable(), findsOneWidget);
  }
  final crumbs = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('planning-crumb ');
  });
  expect(crumbs, findsNWidgets(parts.length));
}

/// The last reading keeps report order within severities and preserves locations.
void expectPlanningFindings(WidgetTester tester) {
  final blocking = planningElement('finding 9');
  final note = planningElement('finding 7');
  expect(blocking, findsOneWidget);
  expect(note, findsOneWidget);
  expect(tester.getTopLeft(blocking).dy, lessThan(tester.getTopLeft(note).dy));
  expect(planningText(tester, blocking), contains('BLOCKING'));
  expect(find.descendant(of: blocking, matching: find.byIcon(Icons.error_outline)), findsOneWidget);
  final locations = tester
      .widgetList<SelectableText>(find.descendant(of: blocking, matching: find.byType(SelectableText)))
      .map((text) => text.data)
      .toList();
  expect(locations, contains('lib/boundary.dart · line 42'));
  final noteText = tester
      .widgetList<SelectableText>(find.descendant(of: note, matching: find.byType(SelectableText)))
      .map((text) => text.data)
      .toList();
  expect(noteText, contains('lib/note.dart'));
}

List<double> _offsets(WidgetTester tester) {
  final board = planningElement('board-scroll');
  expect(board, findsOneWidget);
  // The board scrolls sideways, and each phase scrolls on its own: the position is all of them, left to right.
  final sideways = tester.state<ScrollableState>(
    find.descendant(of: board, matching: find.byType(Scrollable), matchRoot: true).first,
  );
  expect(sideways.position.axis, Axis.horizontal);
  final phases = [
    for (final phase in _phaseScrolls.evaluate().toList()) _phaseScrollable(tester, find.byWidget(phase.widget)),
  ];
  expect(phases, isNotEmpty);
  for (final phase in phases) {
    expect(phase.position.axis, Axis.vertical);
  }
  return [sideways.position.pixels, for (final phase in phases) phase.position.pixels];
}

/// Remembers actual scroll positions and the folded board controls.
Future<void> rememberPlanningBoard(WidgetTester tester) async {
  _boardOffsets = _offsets(tester);
  expect(_boardOffsets!.first, greaterThan(0));
  expect(_boardOffsets!.skip(1).where((offset) => offset > 0), isNotEmpty);
  _folded = tester
      .widgetList<IconButton>(
        find.byWidgetPredicate((widget) => widget is IconButton && (widget.tooltip?.startsWith('Unfold ') ?? false)),
      )
      .map((button) => button.tooltip!)
      .toSet();
  expect(_folded, contains('Unfold Analysis'));
}

/// Checks that back navigation retains search, priority, folds and both scroll axes.
void expectPlanningBoardRetained(WidgetTester tester) {
  expect(tester.widget<TextField>(planningElement('search')).controller!.text, 'ST');
  expect(find.text('High and above'), findsOneWidget);
  final folded = tester
      .widgetList<IconButton>(
        find.byWidgetPredicate((widget) => widget is IconButton && (widget.tooltip?.startsWith('Unfold ') ?? false)),
      )
      .map((button) => button.tooltip!)
      .toSet();
  expect(_folded, isNotNull);
  expect(folded, _folded);
  expect(_boardOffsets, isNotNull);
  expect(_offsets(tester), _boardOffsets);
}

/// Changes the scenario's source, then emits the watch replacement that triggers detail reads.
Future<void> updatePlanningDetails(WidgetTester tester) async {
  _story()['title'] = 'Updated story title';
  _issue()['title'] = 'Updated issue title';
  _issue()['state'] = 'Review';
  World.planning.push('checkout', {...World.planning.boards['checkout']!, 'revision': 'updated'});
  await World.settle(tester);
}

/// Supplies an independently delayed answer for the lifecycle scenario.
void delayPlanningStory() {
  _heldStory = Completer<PlanStoryDetail>();
  World.planning.readStory = (_, _) => _heldStory!.future;
}

/// Completes the old request only after its screen has been left.
Future<void> releasePlanningStory(WidgetTester tester) async {
  expect(_heldStory, isNotNull);
  _heldStory!.complete(PlanStoryDetail.from({'story': _story(), 'text': 'Late story source'}));
  await World.settle(tester);
}

/// Sends the same key the user presses to follow the parent path.
Future<void> planningBack(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}

/// Changes the exact link returned by the source.
void setPlanningIssueLink(String link) => _issue()['link'] = link;

/// Refuses detail reads independently of a successful watch.
void refusePlanningDetails() => World.planning.detailFailure = mockRefusal('org.fuin.porelo.Tasks1.WorkNotAllowed', {
  'detail': 'The story store is locked for repair',
});

/// Omits the list instead of confirming that it is empty.
void omitPlanningIssues() => _story().remove('issues');

/// Reports malformed numbers without discarding the reader's text.
void incompletePlanningFindingNumbers() => _issue()['findings'] = [
  {'text': 'First unnumbered finding', 'severity': 'NOTE'},
  {'number': false, 'text': 'Second unnumbered finding', 'severity': 'BLOCKING'},
  {'number': 3, 'text': 'Repeated number first', 'severity': 'NOTE'},
  {'number': 3, 'text': 'Repeated number second', 'severity': 'NOTE'},
];

/// A list with malformed entries cannot certify that the reading is clean.
void malformedPlanningFindings() => _issue()['findings'] = [false];

/// Scrolls a populated board while keeping the intended card reachable.
Future<void> scrollPlanningBoard(WidgetTester tester) async {
  final story = planningElement('story ST291');
  await revealPlanning(tester, story);
  await tester.ensureVisible(story);
  await World.settle(tester);
  // Centred next: the card shows its issues, so a card brought only to the edge leaves the view with the scroll.
  await revealPlanning(tester, story, alignment: 0.5);
  await World.settle(tester);
  final phase = planningPhaseHolding(tester, story);
  // A wheel over the card scrolls the board as a person does; a drag that starts on a card would pick the card up
  // instead. Both scroll back, as the card brought into view may stand at the end of either.
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(tester.getCenter(story)));
  await tester.sendEventToBinding(pointer.scroll(const Offset(0, -60)));
  await World.settle(tester);
  await tester.sendEventToBinding(pointer.scroll(const Offset(-70, 0)));
  await World.settle(tester);
  expect(_offsets(tester).first, greaterThan(0));
  expect(phase.position.pixels, greaterThan(0));
  expect(story.hitTestable(), findsOneWidget);
}

/// A section assertion cannot match a summary or another page.
void expectPlanningSection(WidgetTester tester, String title, String words) {
  final detail = planningElement('detail');
  expect(detail, findsOneWidget);
  final heading = find.descendant(of: detail, matching: find.text(title));
  expect(heading, findsOneWidget);
  // An issue's facts share one card, a row each; elsewhere a section is its own card.
  final shared = find.ancestor(of: heading, matching: find.byKey(const Key('planning-issue-details')));
  final section = shared.evaluate().isNotEmpty
      ? find.ancestor(of: heading, matching: find.byType(Row)).first
      : find.ancestor(of: heading, matching: find.byType(Card)).first;
  expect(planningText(tester, section), contains(words));
}

/// Renders the browser stand-in's received address; Then steps inspect this screen.
Future<void> openPlanningBrowser(WidgetTester tester, String label) async {
  final button = find.descendant(of: planningElement('detail'), matching: find.widgetWithText(OutlinedButton, label));
  expect(button, findsOneWidget);
  if (_browser == null) {
    final entry = OverlayEntry(
      builder: (_) => Align(
        alignment: Alignment.topCenter,
        child: IgnorePointer(
          child: Material(
            child: Text(_browserAddress == null ? 'Browser has not opened a page' : 'Browser opened $_browserAddress'),
          ),
        ),
      ),
    );
    _browser = entry;
    Overlay.of(tester.element(button)).insert(entry);
    // The test's own tree takes the entry with it; it is only removed while still shown.
    addTearDown(() {
      if (entry.mounted) entry.remove();
    });
    openLink = (address) async {
      _browserAddress = address.toString();
      entry.markNeedsBuild();
    };
  }
  await tapPlanning(tester, button);
}

/// Uses a narrow planning pane inside the required desktop test window.
Future<void> narrowPlanningPane(WidgetTester tester) async {
  final boards = PlanningBoards(World.planningOf(World.machines).client);
  addTearDown(boards.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            child: planningView(
              boards: boards,
              shell: World.shell,
              onTask: (_, _) {},
              taskUnavailable: (_, _) => 'Task unavailable in this preview.',
              onNeedsYou: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await World.settle(tester);
}

/// Refuses one RPC while leaving independently read content available.
void refusePlanningPart(String part) => World.planning.partFailures[part] = mockRefusal(
  'org.fuin.porelo.Tasks1.WorkNotAllowed',
  {'detail': 'This part is locked for repair'},
);

/// Lists an issue under another story on the machine's board, as a move between stories would.
Future<void> listPlanningIssueUnder(WidgetTester tester, String issue, String story) async {
  final board = World.planning.boards['checkout']!;
  final stories = planningMaps(board, 'stories');
  final owner = stories.singleWhere((each) => planningMaps(each, 'issues').any((item) => item['id'] == issue));
  final moved = planningMaps(owner, 'issues').singleWhere((item) => item['id'] == issue);
  (owner['issues'] as List<dynamic>).remove(moved);
  (mockStory(story)['issues'] as List<dynamic>).add(moved);
  World.planning.push('checkout', {...board, 'revision': 'issue-moved'});
  await World.settle(tester);
}

/// Supplies malformed blockers without turning them into an unblocked answer.
Future<void> reportMalformedPlanningBlockers(WidgetTester tester) async {
  _issue()['blockedBy'] = [false, ''];
  World.planning.push('checkout', {...World.planning.boards['checkout']!});
  await World.settle(tester);
}

/// Names work known on the scenario's machine, or work absent from its task list.
void reportPlanningWork(bool known) => _story()['work'] = {
  'tasks': [
    {
      'task': known ? 'porelo-checkout-shell' : 'missing-task',
      'containerId': 'container',
      'repository': 'porelo',
      'issues': ['B540', 'B541'],
      'state': 'Implementing',
      'done': 'Review',
      'mode': 'UNATTENDED',
      'agent': 'Agent',
      'model': 'Model',
      'role': 'MAIN',
      'since': 'instant',
      'atWork': true,
      'ended': null,
    },
  ],
  'coordinator': null,
  'since': 'instant',
  'atWork': true,
  'repositories': <Map<String, dynamic>>[],
  'comment': '',
  'readingRounds': 2,
  'issueReadingRounds': <Map<String, dynamic>>[],
  'issues': <Map<String, dynamic>>[],
};

/// Tests task reachability using the rendered button and explanation.
Future<void> expectPlanningTask(WidgetTester tester, String name, String reason) async {
  final link = find.descendant(of: planningElement('detail'), matching: planningElement('task $name'));
  expect(link, findsOneWidget);
  final button = tester.widget<TextButton>(link);
  expect(button.onPressed, reason.isEmpty ? isNotNull : isNull);
  final tooltip = tester.element(link).findAncestorWidgetOfExactType<Tooltip>();
  expect(tooltip, isNotNull);
  expect(tooltip!.message, reason.isEmpty ? 'Open $name' : contains(reason));
  if (reason.isNotEmpty) {
    final explanation = find.descendant(of: planningElement('detail'), matching: find.textContaining(reason));
    expect(explanation, findsOneWidget);
    await tester.ensureVisible(explanation);
    expect(explanation.hitTestable(), findsOneWidget);
  }
}

/// Confirms that task navigation opened the actual work pane and correct task.
void expectPlanningWorkOpened(WidgetTester tester, String name) {
  final pane = find.byType(WorkDetail);
  expect(pane, findsOneWidget);
  expect(find.descendant(of: pane, matching: find.text(name)), findsWidgets);
  expect(planningElement('detail'), findsNothing);
}

/// Confirms the rail highlight from its own semantics, including ancestor destinations.
void expectPlanningRail(WidgetTester tester) {
  final rail = find.byKey(const Key('rail planning'));
  expect(rail, findsOneWidget);
  final semantics = tester.element(rail).findAncestorWidgetOfExactType<Semantics>();
  expect(semantics, isNotNull);
  expect(semantics!.properties.selected, isTrue);
}

/// Removes the provider of the open page through the machine model.
Future<void> removePlanningProvider(WidgetTester tester) async {
  final view = tester.widget<PlanningScreen>(find.byType(PlanningScreen));
  final place = World.shell.place;
  final machine = World.machines.all.singleWhere((machine) => machine.name == place.planningSource);
  // No use of the old boards after the source has been forgotten.
  expect(view.boards.at(place.planningSource, place.project), isNotNull);
  await World.machines.forget(machine);
  await World.settle(tester);
}

/// Supplies mixed valid and malformed optional reports for the incomplete-section display.
void partialPlanningSections() => _issue().addAll({
  'whatMustBeTrue': ['Keep this criterion', false],
  'subAgents': [
    {'name': 'Visible reader', 'role': 'review'},
    false,
  ],
});

/// Counts only rendered detail text, so duplicate error/loading sentences cannot pass.
void expectPlanningMessageOnce(String words) {
  expect(planningElement('detail'), findsOneWidget);
  expect(find.descendant(of: planningElement('detail'), matching: find.textContaining(words)), findsOneWidget);
}

/// Supplies a finding whose empty file must not create a separator before the line.
void reportEmptyFindingFile() => _issue()['findings'] = [
  {'number': 9, 'severity': 'BLOCKING', 'text': 'Check the line', 'file': '', 'line': 42},
];

/// A watch replacement starts a fresh read group and preserves the last answer on failure.
Future<void> refusePlanningReplacement(WidgetTester tester, String part) async {
  refusePlanningPart(part);
  World.planning.push('checkout', {...World.planning.boards['checkout']!, 'revision': 'failed-read'});
  await World.settle(tester);
}

/// Supplies known wire modes without inventing a coordinator name.
void reportPlanningMode(String mode) => _story()['work'] = {
  'tasks': [
    {'task': 'main', 'role': 'MAIN', 'mode': mode, 'atWork': true},
  ],
  'atWork': true,
  'coordinator': '',
};

/// Opens one row's configured state menu and chooses a real destination.
Future<void> movePlanningIssue(WidgetTester tester, String id, String to) async {
  await tapPlanning(tester, planningElement('move $id'));
  await tapPlanning(tester, planningElement('move-to $id $to'));
}

/// Reads one issue's reported state from its row's state control, without the saving or reason lines.
String planningIssueReportedState(WidgetTester tester, String id) {
  final control = find.descendant(of: planningElement('detail'), matching: planningElement('move $id'));
  return planningText(tester, control).trim();
}

/// A scenario can hold the daemon acknowledgement without editing any state optimistically.
void holdPlanningMove() => World.planning.moveHeld = Completer<void>();

/// Completes the daemon acknowledgement on demand.
Future<void> completePlanningMove(WidgetTester tester) async {
  World.planning.moveHeld!.complete();
  await World.settle(tester);
}

/// Changes the backing store without sending a watch event, exercising the daemon's stale-revision reply.
void stalePlanningMoves() {
  _story()['issues'] = [
    for (final issue in planningMaps(_story(), 'issues')) {...issue, if (issue['id'] == 'B540') 'state': 'Review'},
  ];
  World.planning.boards['checkout']!['revision'] = 'external-change';
}

/// Produces the exact refusal contract for the move of B541.
void refusePlanningMove(String name) {
  World.planning.moveFailure = mockRefusal(
    'org.fuin.porelo.Tasks1.$name',
    name == 'EnteredOnlyByWork'
        ? {'item': 'B541', 'to': 'Review'}
        : {'item': 'B541', 'from': 'Implementing', 'to': 'Review', 'reason': 'Policy refused this move'},
  );
}

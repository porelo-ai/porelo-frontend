import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';

import '../features/step/i_choose_from_the_menu_of_the_tile.dart';
import '../features/step/i_choose_the_tab_of.dart';
import '../features/step/i_go_to_the_running_work.dart';
import '../features/step/i_open_the_command_finder.dart';
import '../features/step/i_pick_in_the_finder.dart';
import '../features/step/i_put_away_what_the_tile_says.dart';
import '../features/step/i_watch_another_machine_called.dart';
import '../features/step/the_machine_is_the_same_node.dart';
import '../features/step/the_row_of_is_in_the_group.dart';
import '../features/step/the_tab_of_is_chosen.dart';
import '../features/step/the_work_runs_unattended.dart';
import '../features/step/there_is_a_tab_for.dart';
import '../features/step/there_is_no_tab_for.dart';
import '../features/support/tiles.dart';
import '../features/support/world.dart';
import '../support/expand_list_rows.dart';

/// Faults a reading of the work page found: each test says what a person would meet.
void main() {
  const work = 'porelo-checkout-shell';
  const other = 'porelo-billing-shell';
  const audit = 'porelo-billing-audit';

  Future<void> theApp(WidgetTester tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
  }

  Future<void> onRunning(WidgetTester tester) async {
    await theApp(tester);
    await iGoToTheRunningWork(tester);
  }

  Future<void> toSection(WidgetTester tester, Section section) async {
    World.shell.goTo(section);
    await World.settle(tester);
  }

  /// The machine back, so nothing is left trying when the test ends.
  Future<void> itAnswersAgain(WidgetTester tester) async {
    World.backend.absent = null;
    await tester.pump(const Duration(minutes: 10));
    await World.settle(tester);
  }

  Map<String, dynamic> anEnd({String at = '2026-10-03T12:57:30Z', bool finished = false, int unpushed = 0}) =>
      <String, dynamic>{
        'at': at,
        'finished': finished,
        'error': finished ? '' : 'it stopped',
        'source': 'agent',
        'unpushed': unpushed,
      };

  String count(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('needing-count'))).data!;

  /// Republishes [name] in a terminal mode with the end given.
  void aTerminalEnded(String name, Map<String, dynamic> ended) {
    World.backend.publish(<Task>[
      for (final task in World.backend.tasksNow)
        if (task.name != name)
          task
        else
          Task.from(<String, dynamic>{...wire(task), 'mode': 'SHELL', 'agentEnded': ended}),
    ]);
  }

  group('how work ended', () {
    // Harm: a row that stays after what it asks has been done.
    testWidgets('reading its log from the list of work is opening it', (tester) async {
      await theApp(tester);
      await toSection(tester, Section.attention);
      World.theWorkIs(work, activity: 'ENDED', running: false, agentEnded: anEnd());
      await World.settle(tester);
      final before = count(tester);
      await toSection(tester, Section.work);
      await toTheTile(tester, work);
      await tester.tap(find.byKey(const Key('tile-read-log')).first);
      await World.settle(tester);
      World.shell.close();
      await toSection(tester, Section.attention);
      expect(count(tester), isNot(before));
    });

    // Harm: a push to review stood among the rest, and its button leaves the row saying it was never seen.
    testWidgets('work that ended with a push waiting stands under Reviews, and reviewing it is opening it', (
      tester,
    ) async {
      await theApp(tester);
      await toSection(tester, Section.attention);
      World.theWorkIs(work, activity: 'ENDED', agentEnded: anEnd(), waiting: 1);
      await World.settle(tester);
      await theRowOfIsInTheGroup(tester, work, 'reviews');
      await expandListRows(tester, within: find.byKey(const Key('open-attention')));
      await tester.tap(find.byKey(const Key('ended-review')).first);
      await World.settle(tester);
      World.shell.close();
      await toSection(tester, Section.attention);
      expect(find.byKey(const Key('ended-put-away')), findsNothing);
      await theRowOfIsInTheGroup(tester, work, 'reviews');
    });

    // Harm: a second failure hidden because the machine gave no time, or the same time, for it.
    testWidgets('an end without a time, or with new facts, is not the end put away', (tester) async {
      await theApp(tester);
      await toSection(tester, Section.attention);
      final calm = count(tester);
      World.theWorkIs(
        work,
        activity: 'ENDED',
        since: '2026-10-03T08:00:00Z',
        agentEnded: anEnd(at: ''),
      );
      await World.settle(tester);
      final ended = count(tester);
      expect(ended, isNot(calm));
      await expandListRows(tester, within: find.byKey(const Key('open-attention')));
      await tester.tap(find.byKey(const Key('ended-put-away')).first);
      await World.settle(tester);
      expect(count(tester), calm);

      World.theWorkIs(
        work,
        activity: 'ENDED',
        since: '2026-10-04T08:00:00Z',
        agentEnded: anEnd(at: ''),
      );
      await World.settle(tester);
      expect(count(tester), ended, reason: 'another run ended, and no time tells it from the first');

      await expandListRows(tester, within: find.byKey(const Key('open-attention')));
      await tester.tap(find.byKey(const Key('ended-put-away')).first);
      await World.settle(tester);
      World.theWorkIs(
        work,
        activity: 'ENDED',
        since: '2026-10-04T08:00:00Z',
        agentEnded: anEnd(at: '', unpushed: 2),
      );
      await World.settle(tester);
      expect(count(tester), ended, reason: 'the same time, and now files never reached the gate');
    });

    // Harm: an end somebody already dealt with comes back each time the window opens on a slow machine.
    test('an end put away on a machine still reading its list is kept', () async {
      Task ended(String name) => Task.from(<String, dynamic>{
        'name': name,
        'task': 'shell',
        'project': 'checkout',
        'running': false,
        'state': 'Exited (0) 1 minute ago',
        'agentEnded': anEnd(),
      });
      const far = Machine(name: 'elsewhere', socketPath: '/tmp/elsewhere.sock');
      final settings = Settings(MemorySettingsStore());
      final held = _HeldList(<Task>[ended('porelo-far')]);
      FakeBackend here() => FakeBackend(<Task>[ended('porelo-near'), ended('porelo-near-2')])..nodeId = 'here';

      final first = Machines(
        settings,
        reach: (machine) => machine.name == far.name ? (FakeBackend(held.list)..nodeId = 'far') : here(),
        tunnels: FakeTunnels(),
      );
      await first.of(first.current).untilAsked();
      await first.add(far);
      await first.of(first.all.firstWhere((each) => each.name == far.name)).untilAsked();
      await pumpEventQueue();
      final attentionFirst = Attention(first, settings);
      attentionFirst.putAwayTheEnd(attentionFirst.needing.firstWhere((tile) => tile.task?.name == 'porelo-far'));
      await pumpEventQueue();
      attentionFirst.dispose();
      first.dispose();

      final second = Machines(
        settings,
        reach: (machine) => machine.name == far.name ? held : here(),
        tunnels: FakeTunnels(),
      );
      final attention = Attention(second, settings);
      addTearDown(() {
        attention.dispose();
        second.dispose();
        settings.dispose();
      });
      await second.of(second.current).untilAsked();
      await pumpEventQueue();
      Tile endOf(String name) => attention.needing.firstWhere((tile) => tile.task?.name == name);
      expect(second.all.where((each) => each.name == far.name), isEmpty, reason: 'not loaded yet');
      attention.putAwayTheEnd(endOf('porelo-near'));
      await pumpEventQueue();
      await second.add(far);
      await pumpEventQueue();
      final slow = second.of(second.all.firstWhere((each) => each.name == far.name));
      expect(slow.reachability, Reachability.connected);
      expect(slow.tasks, isEmpty, reason: 'it answered, and has not listed yet');
      attention.putAwayTheEnd(endOf('porelo-near-2'));
      await pumpEventQueue();
      held.letItList();
      await pumpEventQueue();
      held.publish(held.list);
      await pumpEventQueue();
      expect(slow.tasks, isNotEmpty);
      expect(attention.needing.where((tile) => tile.task?.name == 'porelo-far'), isEmpty);
    });

    // Harm: a log view that waits for ever on a file work in a terminal does not write.
    testWidgets('a terminal that ended is asked which log, and no agent log is opened', (tester) async {
      await theApp(tester);
      await toSection(tester, Section.attention);
      aTerminalEnded(work, anEnd());
      await World.settle(tester);
      await expandListRows(tester, within: find.byKey(const Key('open-attention')));
      await tester.tap(find.byKey(const Key('ended-read-log')).first);
      await World.settle(tester);
      expect(
        World.backend.tailsAsked.where((tail) => tail.task == work && tail.formatted && tail.log == 'task.log'),
        isEmpty,
      );
    });
  });

  group('the session and the page', () {
    // Harm: a terminal stays attached under a page nobody sees: the design has one place for it.
    testWidgets('what is opened over Running leaves its session, and closing it comes back', (tester) async {
      await onRunning(tester);
      await iChooseTheTabOf(tester, other);
      expect(World.sessions.any, isTrue);
      World.shell.openOperations();
      await World.settle(tester);
      expect(World.sessions.any, isFalse);
      World.shell.close();
      await World.settle(tester);
      expect(World.sessions.current?.task, other);
    });

    // Harm: the same, with a refusal in its place.
    testWidgets('a refusal in place of Running leaves its session', (tester) async {
      await onRunning(tester);
      await iChooseTheTabOf(tester, other);
      expect(World.sessions.any, isTrue);
      World.backend.nextRemove = Removed.from(const <String, dynamic>{
        'outcome': 'STILL_RUNNING',
        'work': '',
        'rescuedRef': '',
        'removed': false,
        'discarded': 0,
      });
      await World.fleet.removeWork(other);
      await World.settle(tester);
      expect(World.fleet.refusal, isNotNull);
      expect(World.sessions.any, isFalse);
    });

    // Harm: a tab left blank after a quick move, its agent unreachable until something else redraws.
    testWidgets('a tab chosen while the last one is still asked after opens', (tester) async {
      await onRunning(tester);
      await iChooseTheTabOf(tester, work);
      expect(World.sessions.any, isFalse);
      final held = Completer<void>();
      World.backend.screenHolds[other] = held;
      await iChooseTheTabOf(tester, other);
      await iChooseTheTabOf(tester, audit);
      expect(World.sessions.current?.task, audit, reason: 'it does not wait on what the last tab asked');
      held.complete();
      await World.settle(tester);
      expect(World.sessions.current?.task, audit);
    });

    // Harm: a cheerful attempt at a terminal over ssh to a machine that is down.
    testWidgets('a tab of a machine not answering says so and opens nothing', (tester) async {
      await onRunning(tester);
      World.backend.absent = const VarlinkDisconnected('nothing there');
      World.backend.lose();
      await World.settle(tester);
      await World.sessions.leave();
      World.terminals.clear();
      await World.settle(tester);
      await iChooseTheTabOf(tester, other);
      expect(World.sessions.any, isFalse);
      expect(find.byKey(const Key('running-ended')), findsOneWidget);
      await itAnswersAgain(tester);
    });

    // Harm: one agent shown twice, a session opened on either, and every count double.
    testWidgets('one node reached two ways has one tab per agent', (tester) async {
      await theApp(tester);
      await theMachineIsTheSameNode(tester, 'elsewhere');
      World.elsewhere.publish(World.work);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iGoToTheRunningWork(tester);
      final tabs = find.byWidgetPredicate(
        (widget) => '${widget.key}'.endsWith("/$other'>]") && '${widget.key}'.contains('running-tab '),
      );
      expect(tabs, findsOneWidget);
    });

    // Harm: the terminal asked for is not opened, and the agent's log stands in its place.
    testWidgets('a new terminal asked for on unattended work worked by hand is a terminal', (tester) async {
      await theApp(tester);
      await theWorkRunsUnattended(tester, other);
      await toSection(tester, Section.work);
      await iChooseFromTheMenuOfTheTile(tester, 'Work in it by hand', other);
      expect(World.sessions.current?.task, other);
      World.terminals.last.endsWith(69);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('running-new-terminal')));
      await World.settle(tester);
      expect(World.sessions.current?.task, other);
      expect(find.byType(SessionView), findsOneWidget);
    });

    // Harm: a blank tab: work by hand over, with nothing on it and no way but the row back.
    testWidgets('a by-hand terminal that ended by itself goes back to the log', (tester) async {
      await theApp(tester);
      await theWorkRunsUnattended(tester, other);
      await toSection(tester, Section.work);
      await iChooseFromTheMenuOfTheTile(tester, 'Work in it by hand', other);
      final terminals = World.terminals.length;
      World.terminals.last.endsWith(0);
      await World.settle(tester);
      expect(World.sessions.any, isFalse);
      expect(World.terminals.length, terminals);
      expect(find.byKey(const Key('follow')), findsOneWidget);
    });

    // Harm: coming back shows another agent than was left, and keys go to that one.
    testWidgets('a tab shown by itself is the tab on coming back, whatever started meanwhile', (tester) async {
      await onRunning(tester);
      final shown = tester.widget<Text>(find.byKey(const Key('running-name'))).data!;
      await toSection(tester, Section.attention);
      World.backend.publish(<Task>[...World.backend.tasksNow, World.aTask('porelo-aaa-first', 'aaa')]);
      await World.settle(tester);
      await toSection(tester, Section.work);
      await theTabOfIsChosen(tester, shown);
    });

    // Harm: a key the far end takes is swallowed to move a tab.
    testWidgets('Ctrl with another modifier and a page key reaches the terminal', (tester) async {
      await onRunning(tester);
      await iChooseTheTabOf(tester, other);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await World.settle(tester);
      await theTabOfIsChosen(tester, other);
    });

    // Harm: the next-agent key throws somebody out of the terminal they were working in.
    testWidgets('moving between tabs keeps work by hand in its terminal', (tester) async {
      await theApp(tester);
      await theWorkRunsUnattended(tester, other);
      await toSection(tester, Section.work);
      await iChooseFromTheMenuOfTheTile(tester, 'Work in it by hand', other);
      expect(find.byType(SessionView), findsOneWidget);
      await iChooseTheTabOf(tester, work);
      await iChooseTheTabOf(tester, other);
      expect(find.byKey(const Key('running-follow-log')), findsOneWidget);
      expect(World.sessions.current?.task, other);
    });

    // Harm: the window deaf to its own keys on a tab with no terminal.
    testWidgets('the window keeps the keyboard on a tab without a terminal', (tester) async {
      await onRunning(tester);
      await iChooseTheTabOf(tester, other);
      expect(find.byType(SessionView), findsOneWidget);
      await iChooseTheTabOf(tester, work);
      expect(find.byType(SessionView), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await World.settle(tester);
      expect(find.byKey(const Key('command-query')), findsOneWidget);
    });

    // Harm: the same under the sentence a clean exit leaves.
    testWidgets('the window keeps the keyboard when a terminal exits cleanly', (tester) async {
      await onRunning(tester);
      await iChooseTheTabOf(tester, other);
      World.terminals.last.endsWith(0);
      World.backend.screens[other] = const Screen(lines: <String>[], live: false);
      await World.settle(tester);
      expect(find.byKey(const Key('running-ended')), findsOneWidget);
      await iOpenTheCommandFinder(tester);
      expect(find.byKey(const Key('command-query')), findsOneWidget);
    });

    // Harm: the window deaf to its own keys after something opened over the list and closed.
    testWidgets('the window keeps the keyboard on the list after what opened over it closes', (tester) async {
      await theApp(tester);
      await toSection(tester, Section.work);
      await tester.tap(find.byKey(const Key('work-list-filter')));
      await World.settle(tester);
      World.shell.openOperations();
      await World.settle(tester);
      World.shell.close();
      await World.settle(tester);
      await iOpenTheCommandFinder(tester);
      expect(find.byKey(const Key('command-query')), findsOneWidget);
    });

    // Harm: a blank tab: working by hand in an agent that has no terminal of its own yet is refused by a look.
    testWidgets('work by hand opens its terminal whatever a look would say', (tester) async {
      await theApp(tester);
      World.backend.screens[work] = const Screen(lines: <String>[], live: false);
      await toSection(tester, Section.work);
      await iChooseFromTheMenuOfTheTile(tester, 'Work in it by hand', work);
      expect(World.sessions.current?.task, work);
    });

    // Harm: a step that passes with the tab still in the bar, under a label.
    testWidgets('a tab is looked for among the tabs, under its label too', (tester) async {
      await onRunning(tester);
      World.backend.publish(<Task>[
        for (final task in World.backend.tasksNow)
          if (task.name != other) task else Task.from(<String, dynamic>{...wire(task), 'label': 'the billing work'}),
      ]);
      await World.settle(tester);
      await expectLater(thereIsNoTabFor(tester, other), throwsA(isA<TestFailure>()));
      await thereIsATabFor(tester, other);
    });
  });

  group('what has come out', () {
    // Harm: what came out returns to Recently resolved each time it would have gone, and is never gone.
    test('an outcome goes when its time is up, and does not come back', () async {
      var now = DateTime.utc(2026, 11, 5, 8);
      final backend = FakeBackend(World.work)..nodeId = 'here';
      final settings = Settings(MemorySettingsStore());
      final machines = Machines(settings, reach: (_) => backend, tunnels: FakeTunnels());
      final attention = Attention(machines, settings, null, () => now);
      addTearDown(() {
        attention.dispose();
        machines.dispose();
        settings.dispose();
      });
      await machines.of(machines.current).untilAsked();
      await pumpEventQueue();
      final asked = World.blocked('api.example.test:443');
      backend.asking.add(asked);
      await pumpEventQueue();
      final counted = attention.needingSomebody;
      backend.asking.add(World.settled(asked, 'timeout'));
      await pumpEventQueue();
      expect(attention.needingSomebody, counted - 1);
      Iterable<ResolvedAttention> outcome() =>
          attention.recentlyResolved.where((each) => each.row.id.endsWith('/porelo-checkout-shell'));
      expect(outcome(), hasLength(1));
      expect((outcome().single.row.value as Tile).settled, isNotNull);

      now = now.add(const Duration(hours: 2));
      backend.publish(backend.tasksNow);
      await pumpEventQueue();
      expect(outcome(), isEmpty);
      backend.publish(backend.tasksNow);
      await pumpEventQueue();
      expect(outcome(), isEmpty);
      expect(attention.needingSomebody, counted - 1);
    });

    // Harm: the answer on work that still holds a push cannot be put away, or takes the push with it.
    testWidgets('an outcome on work with a push waiting stays on its row until put away', (tester) async {
      await theApp(tester);
      await toSection(tester, Section.attention);
      World.theWorkIs(work, activity: 'WORKING', waiting: 1);
      final asked = World.blocked('api.example.test:443');
      World.backend.asking.add(asked);
      await World.settle(tester);
      World.backend.asking.add(World.settled(asked, 'allow'));
      await World.settle(tester);
      await theRowOfIsInTheGroup(tester, work, 'reviews');
      await iPutAwayWhatTheTileSays(tester, work);
      await theRowOfIsInTheGroup(tester, work, 'reviews');
      expect(find.byKey(const Key('tile-put-away')), findsNothing);
    });
  });

  group('asking the machine', () {
    // Harm: a call every thirty seconds into a tunnel known to be down.
    testWidgets('terminals of a machine not answering are not looked at', (tester) async {
      await theApp(tester);
      await toSection(tester, Section.work);
      await tester.pump(const Duration(seconds: 1));
      World.backend.absent = const VarlinkDisconnected('nothing there');
      World.backend.lose();
      await World.settle(tester);
      World.backend.screensAsked.clear();
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(World.backend.screensAsked, isEmpty);
      await itAnswersAgain(tester);
    });

    // Harm: the terminal a person just asked for is closed by what the machine said of the last one.
    testWidgets('a look begun before a new terminal does not end it', (tester) async {
      await onRunning(tester);
      World.backend.screens[other] = const Screen(lines: <String>[], live: false);
      await iChooseTheTabOf(tester, other);
      expect(find.byKey(const Key('running-new-terminal')), findsOneWidget);
      final held = Completer<void>();
      World.backend.screenHolds[other] = held;
      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.byKey(const Key('running-new-terminal')));
      await Future<void>.value();
      held.complete();
      await Future<void>.value();
      await World.settle(tester);
      expect(World.sessions.current?.task, other);
    });

    // Harm: a number that goes stale on screen, or stays unsaid after the machine came back.
    testWidgets('an unfolded row reads again what its work used while it runs', (tester) async {
      await theApp(tester);
      await toSection(tester, Section.work);
      World.backend.usages[other] = _used(1000);
      await toTheTile(tester, other);
      await World.settle(tester);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('tile-fact tokens'))).data, contains('1'));
      final before = tester.widget<Text>(find.byKey(const ValueKey<String>('tile-fact tokens'))).data;
      World.backend.usages[other] = _used(900000);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('tile-fact tokens'))).data, isNot(before));
    });
  });

  group('the finder', () {
    // Harm: the finder goes to a menu that is not on screen, and nothing seems to happen.
    testWidgets('a command of a row goes to the list from Running', (tester) async {
      await onRunning(tester);
      await iChooseTheTabOf(tester, work);
      World.fleet.selectTask(other);
      await World.settle(tester);
      await iOpenTheCommandFinder(tester);
      await iPickInTheFinder(tester, 'Stop it, keeping its workspace');
      expect(find.byKey(const Key('work-page')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('tile-menu $other')), findsOneWidget);
    });
  });
}

Usage _used(int total) => Usage.from(<String, dynamic>{
  'state': 'available',
  'totals': <String, dynamic>{
    'input': <String, dynamic>{'tokens': total, 'missing': 0},
  },
});

/// A machine that answers and has not listed its work yet.
class _HeldList extends FakeBackend {
  _HeldList(this.list) : super(const <Task>[]);

  final List<Task> list;
  final Completer<void> _held = Completer<void>();

  void letItList() => _held.complete();

  @override
  Future<List<Task>> tasks() async {
    await _held.future;
    return list;
  }
}

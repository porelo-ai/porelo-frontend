import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/log_files.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/window_log.dart' show LogLevel;
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/planning_fake.dart' show mockStartTask;
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

/// The links in Options that open the window's log and the planner's, with the desktop's opener faked: nothing here
/// runs `xdg-open`.
void main() {
  late Directory scratch;
  late Desk before;
  late String windowsLog;
  final opened = <List<String>>[];

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('log-links-');
    before = desk;
    opened.clear();
    desk = LinuxDesk(
      {'HOME': scratch.path, 'XDG_STATE_HOME': '${scratch.path}/state'},
      openAndWait: (executable, arguments) async {
        opened.add([executable, ...arguments]);
        return ProcessResult(0, 0, '', '');
      },
    );
    windowsLog = '${scratch.path}/state/porelo/logs/frontend.log';
  });

  tearDown(() {
    desk = before;
    scratch.deleteSync(recursive: true);
  });

  Future<void> start(WidgetTester tester, {String? plannerLog, LogLevel? plannerLevel}) async {
    final planner = _Planner(plannerLog)..plannerLevel = plannerLevel;
    addTearDown(planner.dispose);
    await World.startBackend(World.work);
    await World.startApp(tester, planning: (_) => EmbeddedPlanning(planner, startTask: mockStartTask));
  }

  Future<void> openOptions(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    await World.settle(tester);
    if (width < 1280) {
      await World.tapInView(tester, 'bar-overflow');
      await tester.tap(find.text('Options').last);
      await World.settle(tester);
    } else {
      await World.tapInView(tester, 'options-menu');
    }
  }

  String said(WidgetTester tester) =>
      tester
          .widget<Text>(find.descendant(of: find.byKey(const Key('log-said')), matching: find.byType(Text)).first)
          .data ??
      '';

  // Harm: a person cannot tell which file a link opens, on a desktop or on a phone's width.
  for (final width in [390.0, 1280.0]) {
    testWidgets('both links name their files in Options at $width', (tester) async {
      await start(tester, plannerLog: '/state/porelo/logs/planner.log');
      await openOptions(tester, width);
      expect(find.textContaining(windowsLog), findsOneWidget);
      expect(find.textContaining('/state/porelo/logs/planner.log'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: the opener is called on nothing and fails silently, so the person is told nothing.
  testWidgets('a log not there yet is said with its path, and nothing is opened', (tester) async {
    await start(tester);
    await openOptions(tester, 1280);
    await World.tapInView(tester, 'log.window');
    expect(said(tester), allOf(contains(windowsLog), contains('not there yet')));
    expect(opened, isEmpty);
  });

  // Harm: on a page with no status line, what came of the link is told nowhere, so a failure reads as nothing at all.
  testWidgets('what came of a link is said on Needs you too, which has no status line', (tester) async {
    await start(tester);
    World.shell.goTo(Section.attention);
    await World.settle(tester);
    await openOptions(tester, 1280);
    await World.tapInView(tester, 'log.window');
    expect(said(tester), allOf(contains(windowsLog), contains('not there yet')));
  });

  // Harm: the link opens another file than the window's log, or opens nothing.
  testWidgets('a log that is there is opened with the desktop\'s opener and its path', (tester) async {
    File(windowsLog)
      ..createSync(recursive: true)
      ..writeAsStringSync('a line\n');
    await start(tester);
    await openOptions(tester, 1280);
    await World.tapInView(tester, 'log.window');
    expect(opened, [
      ['xdg-open', windowsLog],
    ]);
  });

  // Harm: a person who wants to see more finds no way to say so, or the window's log does not follow the choice.
  testWidgets('a level chosen in Options is the window\'s, and the planner at another level is said', (tester) async {
    await start(tester, plannerLevel: LogLevel.error);
    await openOptions(tester, 1280);
    expect(find.text('The planner’s log is at ERROR, not INFO'), findsOneWidget);

    await World.tapInView(tester, 'log.level.debug');
    expect(World.settings.logLevel.value, LogLevel.debug);
  });

  // Harm: a guessed path is opened where the planner names none, or the person is told nothing.
  testWidgets('a planner that names no log is said so, and nothing is opened', (tester) async {
    await start(tester);
    await openOptions(tester, 1280);
    expect(find.textContaining(plannerNamesNoLog), findsOneWidget);
    await World.tapInView(tester, 'log.planner');
    expect(said(tester), contains(plannerNamesNoLog));
    expect(opened, isEmpty);
  });
}

/// A planner the window reached, naming [log] in its address file.
class _Planner extends ChangeNotifier implements PlanningClient, NamesItsLog, TakesTheLogLevel {
  _Planner(this.log);

  @override
  LogLevel? plannerLevel;

  @override
  String? get levelProblem => null;

  @override
  final String? log;

  @override
  List<PlanningProvider> get providers => const [];

  @override
  String? get currentProvider => null;

  @override
  String? get chosenProject => null;

  @override
  Future<void> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
  }) async {}
}

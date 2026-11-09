import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/planning_board.dart';
import 'package:porelo_frontend/src/ui/planning_view.dart';

import '../features/support/world.dart';

class _SilentPlanning extends FakeBackend {
  _SilentPlanning() : super([]);
  final waiting = StreamController<PlanningSnapshot>();
  @override
  Stream<PlanningSnapshot> watchStories(String project) => waiting.stream;
}

void main() {
  // Harm: a silent watch leaves an endless animation, preventing a waiting page or its test from settling.
  testWidgets('a planning page waiting for its first answer has no endless animation', (tester) async {
    await World.startBackend([]);
    await World.startApp(tester);
    final backend = _SilentPlanning();
    backend.theProjectsItHas = [
      Project.from({'name': 'checkout'}),
    ];
    final machines = Machines(World.settings, reach: (_) => backend);
    await machines.load();
    await machines.fleet.untilAsked();
    final boards = PlanningBoards(machines);
    addTearDown(() async {
      boards.dispose();
      machines.dispose();
      await backend.waiting.close();
      await backend.stop();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningView(boards: boards, onNeedsYou: () {}, onStartRequested: (story, state) {}),
        ),
      ),
    );
    await World.settle(tester);
    expect(find.text('Waiting for the machine’s planning answer.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner_build.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/planning_fake.dart' show mockStartTask;
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

const _commit = '0123456789abcdef0123456789abcdef01234567';

/// About names the planner the window runs beside porelo's version, or says why it names none.
void main() {
  Future<String> about(WidgetTester tester, PlannerBuild? build) async {
    final planner = _Planner(build);
    addTearDown(planner.dispose);
    await World.startBackend(World.work);
    await World.startApp(tester, planning: (_) => EmbeddedPlanning(planner, startTask: mockStartTask));
    await World.tapInView(tester, 'about');
    final line = find.byKey(const Key('about-planner'));
    expect(line, findsOneWidget, reason: 'About has a line for the planner');
    return tester.widget<Text>(line).data ?? '';
  }

  // Harm: with the planner swapped between builds, nothing in the window tells which one answers the planning.
  testWidgets('a planner naming its version and commit is named with the commit\'s first twelve', (tester) async {
    final line = await about(tester, const PlannerBuild(version: '0.2.0~snapshot.41', commit: _commit));

    expect(line, allOf(contains('0.2.0~snapshot.41'), contains(_commit.substring(0, 12)), isNot(contains(_commit))));
  });

  testWidgets('a planner built without a checkout is named by its version alone', (tester) async {
    final line = await about(tester, const PlannerBuild(version: '0.2.0'));

    expect(line, contains('0.2.0'));
  });

  // Harm: a planner that names no version, or none reached, reads as a line left out, or as each other.
  testWidgets('a planner naming no version is said so', (tester) async {
    final line = await about(tester, const PlannerBuild());

    expect(line, contains('says no version'));
  });

  testWidgets('no planner reached is said so', (tester) async {
    final line = await about(tester, null);

    expect(line, contains('not reached'));
  });
}

/// A planner whose health names [answer], null where none is reached.
class _Planner extends ChangeNotifier implements PlanningClient, NamesItsBuild {
  _Planner(this.answer);

  final PlannerBuild? answer;

  @override
  Future<PlannerBuild?> build() async => answer;

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
    List<PlanningLanding> landed = const [],
    PlanningStartRefusal? refusal,
  }) async {}
}

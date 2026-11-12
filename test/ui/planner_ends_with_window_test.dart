import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/planning_fake.dart' show mockStartTask;
import 'package:porelo_planning/porelo_planning.dart';

import '../features/step/i_ask_to_close_it.dart';
import '../features/step/i_close_the_interface.dart';
import '../features/step/i_stay.dart';
import '../features/support/world.dart';

/// Closing the window ends the planner it started, once the person agreed to leave.
void main() {
  late _Planner planner;

  Future<void> start(WidgetTester tester) async {
    planner = _Planner();
    addTearDown(planner.dispose);
    await World.startBackend(World.work);
    await World.startApp(tester, planning: (_) => EmbeddedPlanning(planner, startTask: mockStartTask));
  }

  // Harm: a planner the window started outlives the window, so the next planner cannot start.
  testWidgets('closing the window ends the planner', (tester) async {
    await start(tester);

    await iCloseTheInterface(tester);

    expect(planner.ends, 1);
  });

  // Harm: a person who chose to stay loses the planner the board reads from.
  testWidgets('staying ends nothing', (tester) async {
    await start(tester);

    await iAskToCloseIt(tester);
    await iStay(tester);

    expect(planner.ends, 0);
  });
}

/// A planner the window reached, counting how often the window ended it.
class _Planner extends ChangeNotifier implements PlanningClient, EndsWithTheWindow {
  var ends = 0;

  @override
  Future<void> end() async => ends++;

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
  }) async {}
}

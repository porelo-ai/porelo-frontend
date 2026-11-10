import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_planning/porelo_planning.dart';

/// The planner as Windows has it: porelo-planner is built for Linux only, so a window there starts nothing.
void main() {
  test('on Windows nothing is started or read, and the place says planning is not offered there', () async {
    final starts = <String>[];
    var opened = 0;
    final planner = LocalPlanner(
      projects: () => const ['demo'],
      repositories: (project) async => throw PlanningRefusal('NoRepository', const {}),
      runtimeDirectory: r'C:\Users\someone\AppData\Local\Temp\planner-runtime',
      candidates: const [r'C:\Program Files\Porelo\porelo-planner.exe'],
      start: (executable, environment) async => starts.add(executable),
      open: (projects, {runtimeDirectory}) async {
        opened++;
        throw StateError('not to be opened on Windows');
      },
      onWindows: true,
    );
    addTearDown(planner.dispose);

    await planner.reach();

    expect(planner.notReached, plannerNotOnWindows);
    expect(starts, isEmpty);
    expect(opened, 0);
    expect(planner.started, isFalse);
  });
}

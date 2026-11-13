import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/planner_process.dart';

/// The planner as Windows has it: porelo-planner.exe on an absolute folder of the path, its address in its own folder.
void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('planner-windows-'));
  tearDown(() => folder.deleteSync(recursive: true));

  // Harm: on Windows the window starts the planner by itself, which the person did not ask for, or it offers no way
  // to start it, so planning stays out of reach until the next sign-in.
  test('on Windows the planner is started only when the person asks, once, and its address read', () async {
    final program = File('${folder.path}${Platform.pathSeparator}porelo-planner.exe')..writeAsStringSync('');
    final starts = <(String, Map<String, String>)>[];
    final opened = <String?>[];
    final planner = LocalPlanner(
      projects: () => const ['demo'],
      repositories: (project) async => throw PlanningRefusal('NoRepository', const {}),
      candidates: [program.path],
      // A runtime directory is a Linux matter: on Windows the planner keeps its address in its own folder.
      runtimeDirectory: r'C:\Users\someone\AppData\Local\Temp\planner-runtime',
      start: (executable, environment) async {
        starts.add((executable, environment));
        return PlannerProcess();
      },
      open: (projects, {runtimeDirectory}) async {
        opened.add(runtimeDirectory);
        throw const PlanningRefusal('NoAddress', {});
      },
      wait: const Duration(milliseconds: 300),
      poll: const Duration(milliseconds: 20),
      onWindows: true,
    );
    addTearDown(planner.dispose);

    await planner.reach();
    await planner.reach();

    expect(starts, isEmpty, reason: 'nothing is started at a look');
    expect(planner.notReached, plannerNotRunningOnWindows);
    expect(planner.startOffered, isTrue);

    await planner.startNow();
    await planner.reach();

    expect(starts.map((each) => each.$1), [program.path], reason: 'started once, on the ask');
    expect(starts.single.$2, isEmpty, reason: 'no runtime directory is passed on Windows');
    expect(opened, isNotEmpty, reason: 'its address is read');
    expect(opened.toSet(), {null});
    expect(planner.startOffered, isFalse, reason: 'a planner started is not offered for a start again');
  });

  // Harm: on Linux the planning place waits for a button nobody needs there.
  test('elsewhere than Windows no start is offered', () async {
    final planner = LocalPlanner(
      projects: () => const ['demo'],
      repositories: (project) async => throw PlanningRefusal('NoRepository', const {}),
      candidates: const [],
      start: (executable, environment) async => fail('nothing is installed to start'),
      open: (projects, {runtimeDirectory}) async => throw const PlanningRefusal('NoAddress', {}),
      onWindows: false,
    );
    addTearDown(planner.dispose);

    await planner.reach();

    expect(planner.startOffered, isFalse);
  });

  // Harm: on Windows the planner is never found, or a relative folder of the path runs a program from wherever the
  // window was started.
  test('on Windows the planner is looked for as porelo-planner.exe on the absolute folders of the path alone', () {
    expect(
      plannerCandidates({
        'PATH': r'C:\Tools;bin;;"C:\Program Files\Porelo"; D:\x;C:\a\..\b;C:relative',
      }, onWindows: true),
      [r'C:\Tools\porelo-planner.exe', r'C:\Program Files\Porelo\porelo-planner.exe'],
    );
  });

  // Harm: a person on Windows without the planner is told to install a Linux package, or that planning is not offered.
  test('on Windows without the planner the place names its Windows package', () async {
    final planner = LocalPlanner(
      projects: () => const ['demo'],
      repositories: (project) async => throw PlanningRefusal('NoRepository', const {}),
      candidates: ['${folder.path}${Platform.pathSeparator}porelo-planner.exe'],
      start: (executable, environment) async => fail('nothing is installed to start'),
      open: (projects, {runtimeDirectory}) async => throw const PlanningRefusal('NoAddress', {}),
      onWindows: true,
    );
    addTearDown(planner.dispose);

    await planner.reach();

    expect(planner.notReached, plannerNotInstalledOnWindows);
    expect(planner.startOffered, isFalse, reason: 'nothing is there to start');
  });

  // Harm: on Windows the window takes the planner's address file for gone, since it looks for it where Linux keeps it,
  // and looks for a planner again and again while the one found answers.
  test('on Windows the planner found is followed through its address file in its own folder', () async {
    final local = Directory('${folder.path}${Platform.pathSeparator}local')..createSync();
    Directory('${local.path}${Platform.pathSeparator}porelo-planner').createSync();
    File('${local.path}${Platform.pathSeparator}porelo-planner${Platform.pathSeparator}planner.json')
        .writeAsStringSync('{"port": 4711, "token": "a-token-of-the-planner"}');
    var opened = 0;
    final planner = LocalPlanner(
      projects: () => const ['demo'],
      repositories: (project) async => throw PlanningRefusal('NoRepository', const {}),
      candidates: const [],
      start: (executable, environment) async => fail('the planner found is not started again'),
      open: (projects, {runtimeDirectory}) async {
        opened++;
        return HttpPlanningSource.at(PlannerAddress(4711, 'a-token-of-the-planner'), projects);
      },
      follow: const Duration(milliseconds: 20),
      onWindows: true,
      environment: {'LOCALAPPDATA': local.path},
    );
    addTearDown(planner.dispose);

    await planner.reach();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(planner.notReached, isNull);
    expect(opened, 1, reason: 'the address file is found again at every look, unchanged');
  });
}

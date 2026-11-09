import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import 'e2e.dart';
import 'remote.dart';

/// The rented host and the project of a rehearsed move, as `tool/rehearse_window.sh` is told them.
abstract final class Rehearsal {
  /// The host's name, as the organization's card names it.
  static String get hostName => _required('PORELO_REHEARSAL_HOST_NAME');

  /// The project the organization put on the host.
  static String get project => _required('PORELO_REHEARSAL_PROJECT');

  static String _required(String variable) {
    final value = Platform.environment[variable] ?? '';
    if (value.isEmpty) throw StateError('$variable is not set: run this through tool/rehearse_window.sh');
    return value;
  }

  /// The name and model the window showed for the work it started, read back from the host's answer.
  static String? startedName;

  /// The model the window showed, empty where it named none.
  static String? startedModel;

  /// The repository work was started on.
  static String? startedRepository;

  /// The key the rehearsal read from the server as root when it was rented, `TYPE BASE64`.
  static String get hostKey => _required('PORELO_REHEARSAL_HOST_KEY');

  /// Why the scenario that runs is not run, once it said so: its later steps do nothing.
  static String? notRun;

  /// The agents the host said were not signed in before the window signed one in.
  static Set<String> notSignedIn = {};

  /// The task whose work waited at its gate.
  static String? waitingTask;

  /// The commit the gate's review named.
  static String? reviewedCommit;

  /// The new branch of the host's forge the work was forwarded to.
  static String? forwardedBranch;
}

/// Asks the host's own daemon, as the person, over the same contract the window reads: the host's word, not the
/// window's, is what a step compares the screen with.
Future<Map<String, dynamic>> askTheHostsDaemon(String method, [Map<String, Object?> parameters = const {}]) async {
  final said = await onTheTestMachine('''
socket="\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}/porelo/porelod.sock"
varlinkctl call --json=short "\$socket" org.fuin.porelo.Tasks1.$method '${jsonEncode(parameters)}'
''');
  final line = said.split('\n').lastWhere((each) => each.trim().startsWith('{'), orElse: () => '');
  if (line.isEmpty) throw StateError('the host did not answer $method: $said');
  return jsonDecode(line) as Map<String, dynamic>;
}

/// The project as the host's daemon has it, or null where it does not list it.
Future<Map<String, dynamic>?> theProjectOnTheHost() async {
  final projects = (await askTheHostsDaemon('Projects'))['projects'] as List<dynamic>? ?? const [];
  for (final each in projects.cast<Map<String, dynamic>>()) {
    if (each['name'] == Rehearsal.project) return each;
  }
  return null;
}

/// The project's repositories the host says it carries, by name.
Future<List<String>> theCarriedRepositories() async {
  final project = await theProjectOnTheHost();
  final repositories = (project?['repositories'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
  return [
    for (final each in repositories)
      if (each['carriedHere'] == true) each['name'] as String,
  ];
}

/// The host's tasks of the project, as its daemon lists them.
Future<List<Map<String, dynamic>>> theProjectsTasksOnTheHost() async {
  final tasks = (await askTheHostsDaemon('List'))['tasks'] as List<dynamic>? ?? const [];
  return [
    for (final each in tasks.cast<Map<String, dynamic>>())
      if (each['project'] == Rehearsal.project) each,
  ];
}

/// The host's entry under *My machines*, unfolded, once it is connected.
Finder theHostsEntry() => machineEntry(Rehearsal.hostName);

/// Goes to one section of the host under *My machines*.
Future<void> toTheHostsSection(WidgetTester tester, MachineSection section) async {
  await toTheMachines(tester);
  final entry = theHostsEntry();
  await tester.ensureVisible(entry.first);
  await tester.tap(entry.first);
  await pumpFor(tester);
  final place = find.byKey(ValueKey<String>('rail ${ShellPlace.machineKey(Rehearsal.hostName)} ${section.name}'));
  await pumpUntil(tester, () => place.evaluate().isNotEmpty, what: 'the host to show ${section.label}');
  await tester.ensureVisible(place.first);
  await tester.tap(place.first);
  await pumpFor(tester);
}

/// Opens the project's page on the host, as a person does from the host's *Projects*.
Future<void> toTheProjectOnTheHost(WidgetTester tester) async {
  await toTheHostsSection(tester, MachineSection.projects);
  final row = find.byKey(ValueKey<String>('project ${Rehearsal.hostName}/${Rehearsal.project}'));
  await pumpUntil(tester, () => row.evaluate().isNotEmpty, what: 'the host to list ${Rehearsal.project}');
  await tester.ensureVisible(row.first);
  await tester.tap(row.first);
  await pumpFor(tester);
  await pumpUntil(tester, () => find.byKey(const Key('project-repositories')).evaluate().isNotEmpty, what: 'its page');
}

/// Presses the item [label] of the popup menu opened by the button keyed [menu], scrolling inside a tall menu.
Future<void> chooseFromTheMenu(WidgetTester tester, Finder menu, String label) async {
  await tester.ensureVisible(menu.first);
  await tester.tap(menu.first);
  await pumpFor(tester);
  final item = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is PopupMenuItem));
  await pumpUntil(tester, () => item.evaluate().isNotEmpty, what: 'the menu to offer $label');
  await tester.tap(item.first);
  await pumpFor(tester);
}

/// The text a field shows, or "" where it is not there.
String theFieldsText(WidgetTester tester, Key key) {
  final field = find.descendant(of: find.byKey(key), matching: find.byType(EditableText));
  if (field.evaluate().isEmpty) return '';
  return tester.widget<EditableText>(field.first).controller.text;
}

/// The tile of the task [task] under *Work*, on whichever machine the window names it.
Finder theTileOf(String task) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      RegExp('^tile .* ${RegExp.escape(task)}\$').hasMatch((w.key! as ValueKey<String>).value),
);

/// What the widgets under [of] say, joined.
String theWordsUnder(WidgetTester tester, Finder of) => [
  for (final each
      in find.descendant(of: of, matching: find.byWidgetPredicate((w) => w is Text || w is SelectableText)).evaluate())
    switch (each.widget) {
      final Text text => text.data ?? '',
      final SelectableText text => text.data ?? '',
      _ => '',
    },
].join(' · ');

/// Marks the scenario not run, with [why] in the report, and has its later steps do nothing.
void notRunBecause(String why) {
  Rehearsal.notRun = why;
  markTestSkipped(why);
}

/// The host's agents with a login running, each with its login's container, by the daemon's own list.
Future<Map<String, String>> theSignInsRunningOnTheHost() async => {
  for (final each in await _theSignIns())
    if (each['running'] case final String running when running.isNotEmpty) each['agent'] as String: running,
};

/// The host's agents it says are not signed in.
Future<Set<String>> theAgentsNotSignedInOnTheHost() async => {
  for (final each in await _theSignIns())
    if (each['state'] == 'NOT_SIGNED_IN') each['agent'] as String,
};

Future<List<Map<String, dynamic>>> _theSignIns() async =>
    ((await askTheHostsDaemon('AgentSignIns'))['signIns'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

/// Runs one step of the rehearsal, and where it fails keeps a picture of the window in `PORELO_REHEARSAL_SHOTS`,
/// named after the scenario, before the failure goes on unchanged.
///
/// Taken inside the step, while the frame still stands: Flutter checks after every test that its exception
/// reporter was left as it was, so a picture is never hung on that.
Future<void> pictured(WidgetTester tester, Future<void> Function() step) async {
  try {
    await step();
  } catch (_) {
    await _keepAPicture(tester);
    rethrow;
  }
}

Future<void> _keepAPicture(WidgetTester tester) async {
  final into = Platform.environment['PORELO_REHEARSAL_SHOTS'] ?? '';
  if (into.isEmpty) return;
  try {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer;
    if (layer is! OffsetLayer) return;
    // The root layer scales the test's logical screen onto the window: the picture is of the window, whole.
    final whole = Offset.zero & view.size;
    final bounds = layer is TransformLayer && layer.transform != null
        ? MatrixUtils.transformRect(layer.transform!, whole)
        : whole;
    final image = await layer.toImage(bounds);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return;
    final name = tester.testDescription.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    await Directory(into).create(recursive: true);
    await File('$into/$name.png').writeAsBytes(png.buffer.asUint8List());
  } on Object catch (missed) {
    // A picture missed never hides the failure it was for.
    debugPrint('no picture of the failure: $missed');
  }
}

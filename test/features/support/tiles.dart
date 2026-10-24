import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import 'world.dart';

/// The tile for one piece of work, matched on its key rather than on text it happens to show.
///
/// Work shows every machine's tiles at once, and two machines can serve the same work: the tile on
/// the machine being acted on is the one meant, where there is one.
Finder tileFor(String work) {
  bool open(Element element) {
    var resolved = false;
    element.visitAncestorElements((ancestor) {
      resolved = ancestor.widget.key == const Key('recently-resolved');
      return !resolved;
    });
    return !resolved;
  }

  final here = find.byElementPredicate(
    (element) => element.widget.key == ValueKey<String>('tile ${World.machines.current.name} $work') && open(element),
  );
  if (here.evaluate().isNotEmpty) return here;
  return find.byElementPredicate(
    (element) =>
        element.widget is Card &&
        '${element.widget.key}'.contains("'tile ") &&
        '${element.widget.key}'.endsWith(" $work'>]") &&
        open(element),
  );
}

/// The entry of one project under the machine being looked at.
Finder cardFor(String project) => find.byKey(ValueKey<String>('project $project'));

/// The rail entry of one machine, by the badge every entry carries.
Finder railEntryFor(String machine) => find.byKey(ValueKey<String>('waiting-count $machine'));

/// Brings [target] on screen and taps it.
///
/// The machine tree builds only what is near the screen, so an entry of it that is not built yet is
/// scrolled to, as a person would.
Future<void> tapOnScreen(WidgetTester tester, Finder target) async {
  // Machines are listed on their page, and projects on theirs: whichever holds it, as a person goes.
  if (target.evaluate().isEmpty) await toTheMachines(tester);
  if (target.evaluate().isEmpty) await toTheProjects(tester);
  final tree = find.descendant(of: _thePage(), matching: find.byType(Scrollable));
  if (target.evaluate().isEmpty && tree.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(target, 100, scrollable: tree.first, maxScrolls: 30);
  }
  await tester.ensureVisible(target.first);
  await tester.pump();
  await tester.tap(target.first);
}

/// Everything a piece of work's tile says, as one line.
String whatItSaysAbout(WidgetTester tester, String work) => <String>[
  for (final text in tester.widgetList<Text>(find.descendant(of: tileFor(work), matching: find.byType(Text))))
    text.data ?? text.textSpan?.toPlainText() ?? '',
].join(' ');

/// Presses what the finder marked where it went, when it went somewhere rather than running.
Future<void> followTheFinder(WidgetTester tester) async {
  final there = find.byKey(const Key('highlighted'));
  if (there.evaluate().isEmpty) return;
  await tester.tap(there.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Goes to the page of machines and their projects, where it is not on screen: setting up is a page
/// of its own now, out of the daily way, gone to as a person would.
Future<void> toTheMachines(WidgetTester tester, {bool timePasses = true}) async {
  if (find.byKey(const Key('machine-tree')).evaluate().isNotEmpty) return;
  await toThePlace(tester, 'machines', timePasses: timePasses);
}

/// Goes to one place of the rail - `work`, `attention`, `machines` or `projects` - opening the
/// rail first where a narrow window keeps it behind the menu button.
///
/// [timePasses] false only redraws: a check lets no time pass, or a machine's next try to answer
/// would happen inside it.
Future<void> toThePlace(WidgetTester tester, String place, {bool timePasses = true}) async {
  Future<void> settle() async {
    if (timePasses) return World.settle(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  final entry = find.byKey(ValueKey<String>('rail $place'));
  if (entry.evaluate().isEmpty) {
    final menu = find.byTooltip('Open navigation menu');
    if (menu.evaluate().isNotEmpty) {
      await tester.tap(menu.first);
      await settle();
    }
  }
  if (entry.evaluate().isEmpty) return;
  await tester.tap(entry.first);
  await settle();
}

/// Looks at the page of machines and their projects, then goes back to where the window was: a
/// check is no step a person takes, and the next step expects the window where it was.
Future<T> lookingAtTheMachines<T>(WidgetTester tester, Future<T> Function() look) async {
  final before = World.shell.section;
  await toTheMachines(tester, timePasses: false);
  final seen = await look();
  if (World.shell.section != before) {
    // Straight back, not through the machine's entry: opening a machine asks it again, and a check
    // must leave the world as it found it.
    World.shell.goTo(before);
    await tester.pump();
  }
  return seen;
}

/// Opens the current machine's page with the project chosen on it, where the window is elsewhere:
/// a project chosen already is not chosen again, since a second tap on it widens back to all.
Future<void> toTheChosenProject(WidgetTester tester) async {
  if (World.shell.section == Section.machine) return;
  // Opened again from its row on Projects, which keeps it chosen.
  final project = World.fleet.selectedProject?.name;
  if (project == null) return;
  await toTheProjects(tester);
  await tester.tap(cardFor(project).first);
  await World.settle(tester);
}

/// Brings the tile of [work] on screen, open: work is shown only on the work page now, in a group
/// that may be shut and as a tile that may be folded, and is gone to, opened and unfolded as a
/// person would.
Future<void> toTheTile(WidgetTester tester, String work) async {
  // Asked again at each step: which machine's tile is meant can change once the page is drawn.
  Finder tile() => tileFor(work);
  if (tile().evaluate().isEmpty && find.byKey(const Key('work-page')).evaluate().isEmpty) {
    await toThePlace(tester, 'work');
  }
  final page = find.descendant(of: find.byKey(const Key('work-page')), matching: find.byType(Scrollable));
  if (tile().evaluate().isEmpty) {
    // A shut group hides its tiles: every shut one is opened.
    for (final group in <String>['waiting', 'running', 'stopped']) {
      final heading = find.byKey(ValueKey<String>('work-group-fold $group'));
      // Further down than the page has built yet, where the tiles above are tall.
      if (heading.evaluate().isEmpty && page.evaluate().isNotEmpty) {
        try {
          await tester.scrollUntilVisible(heading, 200, scrollable: page.first, maxScrolls: 30);
        } on StateError {
          // No such group on this page.
        }
      }
      if (heading.evaluate().isEmpty) continue;
      if (find.descendant(of: heading, matching: find.byIcon(Icons.chevron_right)).evaluate().isEmpty) continue;
      await tester.ensureVisible(heading);
      await tester.tap(heading);
      await tester.pump();
    }
  }
  if (tile().evaluate().isEmpty && page.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(tile(), 200, scrollable: page.first, maxScrolls: 30);
  }
  if (tile().evaluate().isEmpty) return;
  await tester.ensureVisible(tile().first);
  await tester.pump();
  // Unfolded, so what it says below its work and machine can be read and pressed.
  final fold = find.descendant(of: tile().first, matching: find.byKey(ValueKey<String>('tile-fold $work')));
  if (fold.evaluate().isNotEmpty &&
      find.descendant(of: tile(), matching: find.byKey(const Key('tile-headline'))).evaluate().isEmpty) {
    await tester.tap(fold.first);
    await tester.pump();
  }
}

/// The page of machines or of projects, whichever is shown.
Finder _thePage() => find.byKey(const Key('machine-tree')).evaluate().isNotEmpty
    ? find.byKey(const Key('machine-tree'))
    : find.byKey(const Key('projects-page'));

/// Goes to the page of every project and the ways to set one up, where it is not shown already.
Future<void> toTheProjects(WidgetTester tester, {bool timePasses = true}) async {
  if (find.byKey(const Key('projects-page')).evaluate().isNotEmpty) return;
  await toThePlace(tester, 'projects', timePasses: timePasses);
}

/// Looks at the page of projects, then goes back to where the window was, as
/// [lookingAtTheMachines] does for machines.
Future<T> lookingAtTheProjects<T>(WidgetTester tester, Future<T> Function() look) async {
  final before = World.shell.section;
  await toTheProjects(tester, timePasses: false);
  final seen = await look();
  if (World.shell.section != before) {
    World.shell.goTo(before);
    await tester.pump();
  }
  return seen;
}

/// An entry of the command finder by its words: only in the finder, since the same words can stand
/// on the page behind it too (a project's points, a tile's menu).
Finder inTheFinder(String label) =>
    find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, label));

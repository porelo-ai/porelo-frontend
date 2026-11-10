import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';

import 'world.dart';
import '../../support/expand_list_rows.dart';

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
        '${element.widget.key}'.contains("'tile ") && '${element.widget.key}'.endsWith(" $work'>]") && open(element),
  );
}

/// The large title of a leaf, distinct from the same words in its breadcrumb.
Finder leafPageTitle(String title) => find.byWidgetPredicate(
  (widget) => widget is Text && widget.key == const Key('leaf-title') && widget.data == title,
  description: 'the leaf title $title',
);

/// One named organization project in either its own list or the organization's Projects leaf.
Finder organizationProjectInList(String project) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is FilteredListSection &&
        (widget.storageId == 'my-projects' || widget.storageId == 'organization-projects'),
  ),
  matching: find.text(project),
);

/// The entry of one project under the machine being looked at.
Finder cardFor(String project) => find.byKey(ValueKey<String>('project ${World.machines.current.name}/$project'));

/// Everything the row of [project] on the machine being looked at says, as one line.
String whatTheRowOfSays(WidgetTester tester, String project) {
  expect(cardFor(project), findsOneWidget, reason: '$project is not listed');
  return <String>[
    for (final text in tester.widgetList<Text>(find.descendant(of: cardFor(project), matching: find.byType(Text))))
      text.data ?? text.textSpan?.toPlainText() ?? '',
  ].join(' ');
}

/// Every piece of work shown, a row of its own on the work page and on what needs a person, in the
/// order they are drawn.
Finder workRows() => find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'tile "));

/// The rows of *Needs you* for what a piece of work waits on - a question, a wait, an end, a push at the gate - each a
/// row of its own; with [work], only that work's.
Finder causeRows([String? work]) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  if (key is! ValueKey<String>) return false;
  final match = RegExp(r'^attention-row (question|waits|ended|gate) [^/]+/([^/]+)').firstMatch(key.value);
  return match != null && (work == null || match.group(2) == work);
});

/// The navigation row of one machine.
Finder railEntryFor(String machine) => find.byKey(ValueKey<String>('rail ${ShellPlace.machineKey(machine)}'));

/// Opens [machine]'s own page from its row on Machines, and closes what is opened over it - what it
/// can run, which watching it opens - as a person does to read the page.
Future<void> toTheMachinesPage(WidgetTester tester, String machine) async {
  await toTheMachines(tester);
  await tapOnScreen(tester, railEntryFor(machine));
  await World.settle(tester);
  await closeNavigationTree(tester);
  await closeWhatCoversThePage(tester);
}

/// Opens navigation by its menu button when the tree is in a drawer.
Future<void> openNavigationTree(WidgetTester tester) async {
  if (find.byKey(const Key('shell-rail')).hitTestable().evaluate().isNotEmpty) return;
  final menu = find.byKey(const Key('open-rail'));
  if (menu.evaluate().isEmpty) return;
  await tester.tap(menu);
  await World.settle(tester);
}

/// Dismisses the phone menu after choosing a parent whose facts are to be read.
Future<void> closeNavigationTree(WidgetTester tester) async {
  final scaffold = find.byType(Scaffold).first;
  if (!tester.state<ScaffoldState>(scaffold).isDrawerOpen) return;
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}

/// Reaches today's organization page through one of its tree leaves.
Future<void> toTheOrganization(WidgetTester tester, {OrganizationSection section = OrganizationSection.people}) async {
  await toThePlace(tester, 'organizations');
  final rail = tester.widget<ShellRail>(find.byType(ShellRail));
  if (rail.organizations.isEmpty) {
    expect(rail.organizationsKnown, isTrue, reason: 'an absent organization must have been read');
    await closeNavigationTree(tester);
    return;
  }
  final parentKey = 'rail ${ShellPlace.organizationKey(rail.organizations.first.name)}';
  await World.tapInView(tester, parentKey);
  final leaf = find.byKey(ValueKey('$parentKey ${section.name}'));
  if (leaf.evaluate().isEmpty) {
    await World.tapInView(tester, parentKey.replaceFirst('rail ', 'fold '));
  }
  await World.tapInView(tester, '$parentKey ${section.name}');
  expect(World.shell.place.organizationSection, section, reason: 'navigation must reach the requested leaf');
}

/// Closes what is opened over the page - a view, the vault's, what a machine can run - as a person
/// does to reach what stands on the page itself, such as a machine's lock.
Future<void> closeWhatCoversThePage(WidgetTester tester) async {
  for (var press = 0; press < 3 && World.shell.canClose; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await World.settle(tester);
  }
}

/// Brings [target] on screen and taps it.
///
/// A list builds only what is near the screen, so an entry outside the view is scrolled to first.
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
  final body = find.descendant(of: target.first, matching: find.byType(InkWell));
  await tester.tap(
    tester.widget<Widget>(target.first) is InkWell || body.evaluate().isEmpty ? target.first : body.first,
  );
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
  // A long menu, such as a machine's, scrolls to the entry first, as a person's pointer does.
  await tester.ensureVisible(there.first);
  await tester.pump();
  await tester.tap(there.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Opens My machines and unfolds its tree so each machine can be chosen.
Future<void> toTheMachines(WidgetTester tester, {bool timePasses = true}) async {
  await toThePlace(tester, 'machines', timePasses: timePasses);
}

/// Goes to one place of the rail - `work`, `attention`, `machines` or `projects` - opening the
/// rail first where a narrow window keeps it behind the menu button.
///
/// [timePasses] false only redraws after selection; opening a phone drawer still completes its
/// animation, because its entries cannot be pressed before it is on screen.
Future<void> toThePlace(WidgetTester tester, String place, {bool timePasses = true}) async {
  if (place == 'organization') return toTheOrganization(tester);
  Future<void> settle() async {
    if (timePasses) return World.settle(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  await openNavigationTree(tester);
  final entry = find.byKey(ValueKey<String>('rail $place'));
  await tester.ensureVisible(entry);
  await tester.pump();
  await tester.tap(entry.first);
  await settle();
  if ((place == 'machines' || place == 'organizations') && !World.shell.foldedOpen.contains(place)) {
    final fold = find.byKey(ValueKey('fold $place'));
    if (fold.evaluate().isNotEmpty) {
      await tester.tap(fold);
      await settle();
    }
  }
}

/// Looks at the page of machines and their projects, then goes back to where the window was: a
/// check is no step a person takes, and the next step expects the window where it was.
Future<T> lookingAtTheMachines<T>(WidgetTester tester, Future<T> Function() look) async {
  final before = World.shell.place;
  final project = World.shell.itemProject;
  await toTheMachines(tester, timePasses: false);
  final seen = await look();
  if (World.shell.place.key != before.key || World.shell.itemProject != project) {
    // Straight back, not through the machine's entry: opening a machine asks it again, and a check
    // must leave the world as it found it.
    _restorePlace(before, project);
    await tester.pump();
  }
  return seen;
}

/// Opens the current machine's page with the project chosen on it, where the window is elsewhere:
/// a project chosen already is not chosen again, since a second tap on it widens back to all.
Future<void> toTheChosenProject(WidgetTester tester) async {
  if (World.shell.section == Section.project) return;
  // Opened again from its row on Projects, which keeps it chosen.
  final project = World.fleet.selectedProject?.name;
  if (project == null) return;
  await toTheProjects(tester);
  await tapOnScreen(tester, cardFor(project));
  await World.settle(tester);
}

/// Brings the row of [work] on screen, unfolded: work is listed on the work page alone, and is gone
/// to and unfolded as a person would. Under *Needs you* its row is opened where it stands.
Future<void> toTheTile(WidgetTester tester, String work) async {
  await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  // Asked again at each step: which machine's tile is meant can change once the page is drawn.
  Finder tile() => tileFor(work);
  if (tile().evaluate().isEmpty && find.byKey(const Key('work-page')).evaluate().isEmpty) {
    await toThePlace(tester, 'work');
    final list = find.byKey(const Key('work-view-list'));
    if (find.byKey(const Key('work-page')).evaluate().isEmpty && list.evaluate().isNotEmpty) {
      await tester.tap(list);
      await World.settle(tester);
    }
  }
  final page = find.descendant(of: find.byKey(const Key('work-page')), matching: find.byType(Scrollable));
  if (tile().evaluate().isEmpty && page.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(tile(), 200, scrollable: page.first, maxScrolls: 30);
  }
  if (tile().evaluate().isEmpty) return;
  await tester.ensureVisible(tile().first);
  await tester.pump();
  // Unfolded, so what it says below its work and machine can be read and pressed.
  final fold = find.descendant(of: tile().first, matching: find.byKey(ValueKey<String>('tile-fold $work')));
  if (fold.evaluate().isNotEmpty &&
      find.descendant(of: tile(), matching: find.byKey(const Key('tile-details'))).evaluate().isEmpty) {
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
  // Where an organization is read, the machines' projects are a step away from its own.
  if (find.byKey(const Key('projects-of-machines')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('projects-of-machines')));
    await World.settle(tester);
  }
}

/// Looks at the page of projects, then goes back to where the window was, as
/// [lookingAtTheMachines] does for machines.
Future<T> lookingAtTheProjects<T>(WidgetTester tester, Future<T> Function() look) async {
  final before = World.shell.place;
  final project = World.shell.itemProject;
  await toTheProjects(tester, timePasses: false);
  await expandListRows(tester);
  final seen = await look();
  if (World.shell.place.key != before.key || World.shell.itemProject != project) {
    _restorePlace(before, project);
    await tester.pump();
  }
  return seen;
}

void _restorePlace(ShellPlace place, String? project) {
  if (place.section == Section.project && place.machine != null && project != null) {
    World.shell.openProject(place.machine!, project);
  } else {
    World.shell.choosePlace(place);
  }
}

/// An entry of the command finder by its words: only in the finder, since the same words can stand
/// on the page behind it too (a project's points, a tile's menu).
Finder inTheFinder(String label) =>
    find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, label));

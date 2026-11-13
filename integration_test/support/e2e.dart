import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/main.dart' as app;
import 'package:porelo_frontend/src/app/porelo_app.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_frontend/src/ui/choice_field.dart';

import 'remote.dart';

/// The machine these tests run against, as `tool/e2e.sh` names it.
abstract final class E2e {
  /// What the dialog is told to call it.
  static const name = 'e2e machine';

  /// Where it is, as ssh would be given it.
  static String get host => _required('PORELO_E2E_HOST');

  /// Its daemon's socket, on that machine. Asked of the machine, never guessed: the uid differs.
  static String get remoteSocket => _required('PORELO_E2E_REMOTE_SOCKET');

  static String _required(String variable) {
    final value = Platform.environment[variable] ?? '';
    if (value.isEmpty) throw StateError('$variable is not set: run these through tool/e2e.sh');
    return value;
  }
}

/// Shows the interface, composed once for the whole run and shown again for each scenario.
Future<PoreloApp> showTheInterface(WidgetTester tester) async {
  final interface = await app.porelo();
  await tester.pumpWidget(interface);
  await pumpUntil(tester, () => find.byKey(const Key('shell-rail')).evaluate().isNotEmpty);
  return interface;
}

/// Goes to one place of the rail - `work`, `attention`, `machines` or `projects` - as a person
/// would: machines and projects are a place of setting up, apart from the daily work.
Future<void> toThePlace(WidgetTester tester, String place) async {
  final entry = find.byKey(ValueKey<String>('rail $place'));
  if (entry.evaluate().isEmpty) {
    final menu = find.byTooltip('Open navigation menu');
    if (menu.evaluate().isNotEmpty) {
      await tester.tap(menu.first);
      await pumpFor(tester);
    }
  }
  // The tree scrolls: after a machine far down was chosen, the places at its top are above the view.
  await tester.ensureVisible(entry.first);
  await pumpFor(tester);
  await tester.tap(entry.first);
  await pumpFor(tester);
}

/// The side bar's entry of the machine [name], under *My machines*.
Finder machineEntry(String name) => find.byKey(ValueKey<String>('rail ${ShellPlace.machineKey(name)}'));

/// Unfolds *My machines* in the side bar, where its machines are not shown already: a second tap
/// on it would fold them away again.
Future<void> toTheMachines(WidgetTester tester) async {
  final shown = find.byWidgetPredicate(
    (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('rail machine '),
  );
  if (shown.evaluate().isNotEmpty) return;
  await toThePlace(tester, 'machines');
}

/// Real time, not fake: the machine is real, and only waiting lets its answers arrive.
Future<void> pumpFor(WidgetTester tester, [Duration wait = const Duration(milliseconds: 300)]) async {
  await Future<void>.delayed(wait);
  await tester.pump();
}

/// Pumps until [key] is on screen: the next page or menu, drawn when the window gets to it.
Future<void> pumpUntilShown(WidgetTester tester, Key key) =>
    pumpUntil(tester, () => find.byKey(key).evaluate().isNotEmpty, what: '$key');

/// Pumps until [done] holds, and fails naming [what] when it never does.
Future<void> pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() done, {
  Duration timeout = const Duration(seconds: 15),
  String what = 'the window',
}) async {
  final by = DateTime.now().add(timeout);
  while (!await done()) {
    if (DateTime.now().isAfter(by)) {
      // What was there instead, so a red run says what it saw rather than only what it missed.
      final shown = tester.widgetList<Text>(find.byType(Text)).map((each) => each.data).nonNulls.toList();
      fail('waited ${timeout.inSeconds}s for $what; on screen: $shown');
    }
    await pumpFor(tester, const Duration(milliseconds: 200));
  }
}

/// Makes [name] the machine acted on, through the switcher a person would use.
Future<void> switchTo(WidgetTester tester, String name) async {
  await toTheMachines(tester);
  final entry = machineEntry(name);
  await tester.ensureVisible(entry.first);
  await tester.pump();
  await tester.tap(entry.first);
  await pumpFor(tester);
}

/// Fills the dialog for a forward to the test machine with [socket] there, and tries it.
Future<void> tryFromTheDialog(WidgetTester tester, String socket) async {
  await watchAnotherMachine(tester);
  await tester.enterText(find.byKey(const Key('machine-name')), 'e2e trial');
  // Porelo runs there already, set up by somebody else: only connecting to it is offered and wanted.
  await choose(tester, 'machine-admin', 'machine-admin-no');
  await choose(tester, 'machine-kind-choice', 'machine-raise-it');
  await goOnInTheWizard(tester);
  await tester.enterText(find.byKey(const Key('machine-host')), E2e.host);
  await tester.enterText(find.byKey(const Key('machine-remote-socket')), socket);
  await pumpFor(tester);
  await tester.tap(find.byKey(const Key('try-it')));
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('host-key-accept')).evaluate().isNotEmpty ||
        find.byKey(const Key('trial-result')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the trial or the host key question',
  );
  await trustTheHostKeyIfAsked(tester);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('trial-result')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the trial to say something',
  );
}

/// Goes from the wizard's first page, a name and a kind, to what a forward raised here needs.
Future<void> goOnInTheWizard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('wizard-next')));
  await pumpUntilShown(tester, const Key('machine-host'));
}

/// Trusts the test machine's host key when the wizard shows it. `tool/e2e.sh` writes it to
/// `known_hosts` before the run, so it is normally not asked; if it is, this is a machine the run
/// itself leased.
Future<void> trustTheHostKeyIfAsked(WidgetTester tester) async {
  final trust = find.byKey(const Key('host-key-accept'));
  if (trust.evaluate().isEmpty) return;
  await tester.tap(trust);
  await pumpFor(tester);
}

/// Waits until the machine dialog has closed — it asks the host for its key first, which takes a
/// real round trip — trusting that key if the wizard asks about it.
Future<void> untilTheDialogCloses(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () {
      if (find.byKey(const Key('host-key-accept')).evaluate().isNotEmpty) return true;
      return find.byKey(const Key('watch-it')).evaluate().isEmpty;
    },
    timeout: const Duration(seconds: 30),
    what: 'the machine dialog to close or ask about the host key',
  );
  await trustTheHostKeyIfAsked(tester);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('watch-it')).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine dialog to close',
  );
}

/// Opens the dialog that adds a machine, from the menu bar where it lives.
Future<void> watchAnotherMachine(WidgetTester tester) async {
  // The title bar's button; the menu and the machines' page offer the same.
  await tester.tap(find.byTooltip('Watch another machine…').first);
  await pumpUntilShown(tester, const Key('machine-name'));
}

/// Chooses [choice] in the drop-down [field]: opened first, then the entry's text in the open menu —
/// the field keeps a copy of every entry for its width, and a tap on that copy chooses nothing.
Future<void> choose(WidgetTester tester, String field, String choice) async {
  await tester.ensureVisible(find.byKey(Key(field)));
  await tester.pump();
  await tester.tap(find.byKey(Key(field)));
  await pumpFor(tester);
  await tester.tap(find.descendant(of: find.byKey(Key(choice)).last, matching: find.byType(Text)));
  await pumpFor(tester);
  final chosen = tester.widget<ChoiceField<Object?>>(
    find.ancestor(of: find.byKey(Key(field)), matching: find.byWidgetPredicate((each) => each is ChoiceField)),
  );
  expect(chosen.choices.where((each) => each.value == chosen.value).map((each) => each.id), [
    choice,
  ], reason: 'choosing $choice in $field');
}

/// Opens the connection wizard for the test machine, from its menu, once the machine has answered.
Future<void> openTheConnectionWizard(WidgetTester tester) async {
  await switchTo(tester, E2e.name);
  await tester.tap(find.byKey(const Key('machine-menu')).first);
  await pumpUntil(
    tester,
    () => find.text('Connections — how this machine connects out').evaluate().isNotEmpty,
    what: 'the machine menu',
  );
  // Found is not in place: the menu is still growing, and a tap during it lands beside the entry.
  await pumpFor(tester);
  await tester.tap(find.text('Connections — how this machine connects out').last);
  await tapInTheConnectionsMenu(tester, 'add-connection');
  await pumpUntil(
    tester,
    () => find.byKey(const Key('connection-match')).evaluate().isNotEmpty,
    what: 'the wizard asking what connection to add',
  );
}

/// Opens the menu of the connections on screen and runs its entry [id], where adding and forgetting stand.
///
/// Waits until [id] can be run first: the menu is drawn while the machine is still being asked, and
/// after a change the connections are read again. A menu opened meanwhile keeps the entry greyed out
/// even once the read is done, and a tap on it runs nothing.
Future<void> tapInTheConnectionsMenu(WidgetTester tester, String id) async {
  final menu = find.byKey(const Key('connections-menu'));
  final entry = find.byKey(ValueKey<String>(id));
  // A read again between the check and the opening greys the entry in the menu just opened: closed and opened again.
  for (var attempt = 1; ; attempt++) {
    await pumpUntil(
      tester,
      () =>
          menu.evaluate().isNotEmpty &&
          tester.widget<CommandMenu>(menu).commands.any((each) => each.id == id && each.available),
      what: 'the entry $id of the connections runnable, the machine having answered',
    );
    await tester.tap(menu);
    await pumpUntil(tester, () => entry.evaluate().isNotEmpty, what: 'the entry $id in the menu of the connections');
    // Found is not in place: the menu is still growing, and a tap during it lands beside the entry.
    await pumpFor(tester);
    final enabled = tester.widget<PopupMenuItem<String>>(entry.last).enabled;
    if (enabled) break;
    expect(
      attempt,
      lessThan(5),
      reason: 'the entry $id was greyed out each time the menu opened, so a tap would run nothing',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpUntil(tester, () => entry.evaluate().isEmpty, what: 'the menu of the connections closed');
  }
  await tester.tap(entry.last);
}

/// Opens the machine's destinations from its menu, unless they are open already.
Future<void> openTheDestinations(WidgetTester tester) async {
  if (find.byKey(const Key('destinations-dialog')).evaluate().isNotEmpty) return;
  await switchTo(tester, E2e.name);
  await tester.tap(find.byKey(const Key('machine-menu')).first);
  const entry = 'Destinations — the services a credential can be for';
  await pumpUntil(tester, () => find.text(entry).evaluate().isNotEmpty, what: 'the machine menu');
  // Found is not in place: the menu is still growing, and a tap during it lands beside the entry.
  await pumpFor(tester);
  await tester.tap(find.text(entry).last);
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('destinations-dialog')).evaluate().isNotEmpty &&
        find.text('Asking the machine…').evaluate().isEmpty,
    what: 'the destinations of the machine, read',
  );
}

/// Waits for the real machine's dry run in the wizard's last step, and keeps what it said.
Future<void> untilTheMachineChecked(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('connection-check-says')).evaluate().isNotEmpty ||
        find.byKey(const Key('connection-check-failed')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to check it',
  );
  final detail = find.byKey(const Key('connection-check-detail'));
  theCheckSaid = detail.evaluate().isEmpty ? '' : tester.widget<Text>(detail).data;
}

/// A key pair made for one scenario in a directory of its own, removed with it: never a key of
/// the person running the tests.
Future<({String private, String public})> aThrowawayKeyPair() async {
  final directory = Directory.systemTemp.createTempSync('e2e-key-');
  try {
    final made = await Process.run('ssh-keygen', <String>[
      '-q',
      '-t',
      'ed25519',
      '-N',
      '',
      '-C',
      'e2e throwaway',
      '-f',
      '${directory.path}/key',
    ]);
    if (made.exitCode != 0) throw StateError('ssh-keygen: ${made.stderr}');
    return (
      private: File('${directory.path}/key').readAsStringSync(),
      public: File('${directory.path}/key.pub').readAsStringSync(),
    );
  } finally {
    directory.deleteSync(recursive: true);
  }
}

/// Brings [target] into view on the test machine's *Projects*: the side bar's tree no longer lists a
/// machine's projects, and *My projects* lists the organization's where there is one.
Future<void> showOnTheMachines(WidgetTester tester, Finder target) async {
  await toTheMachines(tester);
  if (target.evaluate().isEmpty) {
    final section = find.byKey(ValueKey<String>('rail ${ShellPlace.machineKey(E2e.name)} projects'));
    // The machine's sections are in the tree once it is chosen.
    if (section.evaluate().isEmpty) await switchTo(tester, E2e.name);
    await tester.ensureVisible(section.first);
    await pumpFor(tester);
    await tester.tap(section.first);
    await pumpFor(tester);
  }
  final page = find.ancestor(
    of: find.byKey(ValueKey<String>('machine-projects ${E2e.name}')),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < 60 && target.evaluate().isEmpty && page.evaluate().isNotEmpty; i++) {
    await tester.drag(page.first, const Offset(0, -120));
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
  if (target.evaluate().isNotEmpty) await tester.ensureVisible(target.first);
  await pumpFor(tester, const Duration(milliseconds: 100));
}

/// Chooses [label] from the menu of the tile of [task] on the work page, as a person would: the page scrolled until
/// the tile shows, and the menu scrolled until the entry can be pressed.
Future<void> chooseFromTheMenuOfTheTile(WidgetTester tester, String task, String label) async {
  // Every machine's work is on the work page.
  await toThePlace(tester, 'work');
  // The work page draws each tile as a list row, a Material rather than a Card: found by its key alone.
  final tile = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('tile ') &&
        (widget.key! as ValueKey<String>).value.endsWith(' $task'),
  );
  final page = find.descendant(of: find.byKey(const Key('work-page')), matching: find.byType(Scrollable));
  for (var i = 0; i < 40 && tile.evaluate().isEmpty && page.evaluate().isNotEmpty; i++) {
    await tester.drag(page.first, const Offset(0, -120));
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
  if (tile.evaluate().isNotEmpty) await tester.ensureVisible(tile.first);
  await pumpFor(tester);
  expect(tile, findsOneWidget, reason: 'no tile of $task on any machine');
  // Keyed by its work, so each tile's menu can be told apart.
  await tester.tap(find.descendant(of: tile, matching: find.byKey(ValueKey<String>('tile-menu $task'))));
  await pumpFor(tester);
  final item = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is PopupMenuItem));
  // The menu is taller than a 720-pixel window when the tile sits low (CI's leased machine, run
  // 36884349003): scrolled inside the menu until the entry can be pressed, not only made "visible".
  await pumpFor(tester);
  final menu = find.ancestor(of: item, matching: find.byType(Scrollable));
  if (item.hitTestable().evaluate().isEmpty && menu.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(item.hitTestable(), 60, scrollable: menu.first);
    await pumpFor(tester);
  }
  await tester.tap(item.hitTestable());
  await pumpFor(tester);
}

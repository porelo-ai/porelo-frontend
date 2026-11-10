// Captures every screen of the window as a picture, at three window sizes, in the light and the dark theme, for a
// reading of how they look and whether they make sense. It asserts nothing: it is no test of the product, and runs
// only through tool/capture_screens.sh, which gives it the mock, the stand-ins and a folder of its own.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:porelo_frontend/main.dart' as app;
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/porelo_app.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The window sizes every screen is captured at: a phone, a small desktop window and a full screen.
const _sizes = <Size>[Size(390, 844), Size(1024, 768), Size(1920, 1080)];

/// The situation of this run: `full`, `empty`, or `lost`, the full one whose machine stops answering.
final _situation = Platform.environment['PORELO_CAPTURE_SITUATION'] ?? 'full';

/// Where the pictures go, one folder per situation.
final _into = Platform.environment['PORELO_CAPTURE_INTO'] ?? '/var/tmp/porelo-screens/$_situation';

/// The commands of the finder whose dialog or wizard is captured, each by its words in the finder.
///
/// Only commands that ask before they act: one that acts at once would change what the next screen shows.
final _dialogs = (Platform.environment['PORELO_CAPTURE_DIALOGS'] ?? '')
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

const _frame = Key('captured frame');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every screen of the window is captured in the $_situation situation', (tester) async {
    final shots = _Shots(tester);
    await Directory(_into).create(recursive: true);
    final socket = Platform.environment['PORELO_SOCKET'] ?? '';
    if (socket.isEmpty) fail('PORELO_SOCKET names where the mock answers; run tool/capture_screens.sh');

    final daemon = MockDaemon();
    await daemon.start();
    final mock = MockMachine(daemon, situation: _situation == 'empty' ? 'empty' : 'work');
    if (_situation != 'empty') mock.blocks('api.example.test:443');
    final link = Link(socket);
    if (link.existsSync()) link.deleteSync();
    link.createSync(daemon.socketPath);

    final interface = await app.porelo();
    await tester.pumpWidget(RepaintBoundary(key: _frame, child: interface));
    await shots.until(() => find.byKey(const Key('shell-rail')).evaluate().isNotEmpty, 'the side bar');
    // The machine answers, its lists arrive, and the organization is read.
    await shots.wait(const Duration(seconds: 4));
    final noticed = Stopwatch();
    if (_situation == 'lost') {
      await mock.close();
      await daemon.stop();
      if (link.existsSync()) link.deleteSync();
      // Captured once the window says so, never before: a screen taken earlier shows the machine still answering.
      noticed.start();
      await shots.until(
        () => find.textContaining('Cannot reach').evaluate().isNotEmpty,
        'the window to say the machine is lost',
        patience: const Duration(minutes: 3),
      );
      noticed.stop();
    }

    final screens = _Screens(tester, interface, shots);
    await screens.places();
    await screens.machineScreens();
    await screens.organization();
    await screens.opened();
    await screens.finder();
    for (final words in _dialogs) {
      await screens.dialog(words);
    }
    if (_situation == 'lost') {
      screens.missing.add(
        '(not missing) the window said the machine was lost ${noticed.elapsed.inSeconds} s after it stopped',
      );
    }
    await File('$_into/missing.txt').writeAsString(screens.missing.map((line) => '$line\n').join());

    if (_situation != 'lost') {
      await mock.close();
      await daemon.stop();
    }
    if (link.existsSync()) link.deleteSync();
  }, timeout: Timeout.none);
}

/// What the pictures are taken of: every place, section and overlay of the window.
class _Screens {
  _Screens(this.tester, this.interface, this.shots);

  final WidgetTester tester;
  final PoreloApp interface;
  final _Shots shots;

  /// Each screen that could not be reached in this situation, with why.
  final missing = <String>[];

  ShellModel get shell => interface.shell;

  Machine get machine => interface.machines.current;

  Future<void> _at(ShellPlace place, String name) async {
    shell.close();
    shell.choosePlace(place);
    await shots.wait();
    await shots.take(name);
  }

  Future<void> places() async {
    for (final section in [
      Section.work,
      Section.attention,
      Section.planning,
      Section.machines,
      Section.forges,
      Section.projects,
      Section.cards,
      Section.organizations,
    ]) {
      await _at(ShellPlace(section), 'place-${section.name}');
    }
  }

  Future<void> machineScreens() async {
    await _at(ShellPlace(Section.machine, machine: machine), 'machine');
    for (final section in MachineSection.values) {
      await _at(ShellPlace(Section.machine, machine: machine, machineSection: section), 'machine-${section.name}');
    }
    final projects = interface.machines.fleet.listedProjects;
    if (projects.isEmpty) {
      missing.add('project: the machine lists no project');
    } else {
      shell.close();
      shell.openProject(machine, projects.first.name);
      await shots.wait();
      await shots.take('project');
    }
  }

  Future<void> organization() async {
    final read = await _organizationName();
    if (read == null) {
      missing.add('organization and its sections: no organization is read on this computer');
      return;
    }
    await _at(ShellPlace(Section.organization, organization: read), 'organization');
    for (final section in OrganizationSection.values) {
      await _at(
        ShellPlace(Section.organization, organization: read, organizationSection: section),
        'organization-${section.name}',
      );
    }
  }

  Future<String?> _organizationName() async {
    try {
      return (await interface.organizationSource?.read())?.name;
    } on Object {
      return null;
    }
  }

  Future<void> opened() async {
    final fleet = interface.machines.fleet;
    final tasks = fleet.tasks;
    if (tasks.isEmpty) {
      missing.add('a piece of work opened, and its log: the machine runs no work');
    } else {
      shell.close();
      shell.choosePlace(const ShellPlace(Section.work));
      fleet.selectProject(tasks.first.project);
      fleet.selectTask(tasks.first.name);
      shell.openDetail();
      await shots.wait();
      await shots.take('opened-work');
    }
    final projects = fleet.listedProjects;
    if (projects.isEmpty) {
      missing.add('the gate, the egress and the backups of a project: the machine lists no project');
    } else {
      fleet.selectProject(projects.first.name);
      for (final (name, open) in [
        ('opened-gate', shell.openGate),
        ('opened-egress', shell.openEgress),
        ('opened-backups', shell.openBackups),
      ]) {
        shell.close();
        open();
        await shots.wait();
        await shots.take(name);
      }
    }
    shell.close();
    shell.openOperations();
    await shots.wait();
    await shots.take('opened-operations');
    shell.close();
  }

  Future<void> _openFinder() async {
    shell.close();
    shell.choosePlace(const ShellPlace(Section.work));
    await shots.wait();
    final finder = find.byTooltip('Find a command (Ctrl+K)');
    if (finder.evaluate().isEmpty) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    } else {
      await tester.tap(finder.first);
    }
    await shots.wait();
  }

  Future<void> finder() async {
    await _openFinder();
    await shots.take('finder');
    // Every command it lists, for choosing which dialogs to capture.
    final labels = <String>{};
    final list = find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable));
    for (var page = 0; page < 60 && list.evaluate().isNotEmpty; page++) {
      final before = labels.length;
      for (final text in tester.widgetList<Text>(
        find.descendant(of: find.byType(Dialog), matching: find.byType(Text)),
      )) {
        if (text.data != null) labels.add(text.data!);
      }
      if (page > 0 && labels.length == before) break;
      await tester.drag(list.last, const Offset(0, -300));
      await shots.wait(const Duration(milliseconds: 300));
    }
    await File('$_into/finder-words.txt').writeAsString(labels.map((line) => '$line\n').join());
    await _putAway();
  }

  /// Opens the command a line of the dialogs names in the finder and captures what it opens, each step of a wizard as
  /// far as Next goes without anything typed.
  ///
  /// The finder goes where the command lives and marks it there, in a menu or on a page; what it marked is pressed,
  /// as a person would.
  ///
  /// A line `WORDS => PRESSED` finds the command by WORDS and presses PRESSED where the finder showed it, for a command
  /// whose menu entry is worded shorter than the finder's.
  Future<void> dialog(String line) async {
    final parts = line.split(' => ');
    final words = parts.first;
    final pressed = parts.last;
    await _openFinder();
    final field = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    if (field.evaluate().isEmpty) {
      missing.add('$words: the finder did not open');
      await _putAway();
      return;
    }
    await tester.enterText(field.first, words);
    await shots.wait(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await shots.wait(const Duration(seconds: 1));
    final marked = find.text(pressed).hitTestable().evaluate().isNotEmpty
        ? find.text(pressed).hitTestable()
        : find.textContaining(pressed).hitTestable();
    if (marked.evaluate().isNotEmpty) {
      await tester.tap(marked.first, warnIfMissed: false);
      await shots.wait(const Duration(seconds: 2));
    }
    final name =
        'dialog-${words.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';
    if (!_navigator.canPop()) {
      await shots.take('$name-not-a-dialog');
      missing.add('$words: pressed where the finder showed it, it opened no dialog (captured as it showed)');
      await _putAway();
      return;
    }
    await shots.take(name);
    for (var step = 2; step <= 8; step++) {
      final next = find.widgetWithText(FilledButton, 'Next').hitTestable();
      if (next.evaluate().isEmpty) break;
      if (tester.widget<FilledButton>(next.first).onPressed == null) break;
      await tester.tap(next.first);
      await shots.wait(const Duration(seconds: 1));
      await shots.take('$name-step$step');
    }
    await _putAway();
  }

  NavigatorState get _navigator => tester.state<NavigatorState>(find.byType(Navigator).first);

  /// Puts away whatever is open over the frame: Escape first, as a person would, then every route left.
  Future<void> _putAway() async {
    for (var i = 0; i < 3 && _navigator.canPop(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await shots.wait(const Duration(milliseconds: 500));
    }
    if (_navigator.canPop()) {
      _navigator.popUntil((route) => route.isFirst);
      await shots.wait(const Duration(milliseconds: 500));
    }
    shell.close();
  }
}

/// Takes the pictures, in real time: the machine is a real socket, and only waiting lets its answers arrive.
class _Shots {
  _Shots(this.tester);

  final WidgetTester tester;
  var count = 0;

  Future<void> wait([Duration wait = const Duration(milliseconds: 800)]) async {
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < wait) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    // An overflow or a failed build is part of what is read, never a reason to stop.
    final error = tester.takeException();
    if (error != null) await File('$_into/exceptions.txt').writeAsString('$error\n', mode: FileMode.append);
  }

  Future<void> until(bool Function() ready, String what, {Duration patience = const Duration(seconds: 60)}) async {
    final elapsed = Stopwatch()..start();
    while (!ready()) {
      if (elapsed.elapsed > patience) fail('Timed out waiting for $what');
      await wait(const Duration(milliseconds: 200));
    }
  }

  /// [name] at every size, in both themes.
  Future<void> take(String name) async {
    for (final size in _sizes) {
      for (final brightness in Brightness.values) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await wait(const Duration(milliseconds: 700));
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (png == null) continue;
        final file = '$_into/$name--${size.width.toInt()}x${size.height.toInt()}--${brightness.name}.png';
        await File(file).writeAsBytes(png.buffer.asUint8List());
        count++;
      }
    }
  }
}

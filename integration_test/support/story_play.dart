import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:xterm/xterm.dart';

import 'e2e.dart';
import 'idea_walk.dart';
import 'rehearsal.dart';

/// What the steps of a played story share: the work they started, its terminal in the window and the terminal on the
/// machine beside it. A story is played by `tool/play_story.sh` on the test machine itself.
abstract final class Played {
  /// The project the story's work is in, made by the story and removed again.
  static const project = 'e2e-term';

  /// The work's name within the project.
  static const task = 'term';

  /// The work's container as porelo lists it, once it does.
  static String? container;

  /// The work's terminal in the window, once it shows.
  static Terminal? ofTheWork;

  /// Every line typed or pasted into the work, in order, for the step that reads what the work received.
  static final List<String> typed = [];

  /// The terminal on the machine beside the window, once it is opened.
  static TerminalOnTheMachine? beside;

  /// The reach of the work for a host nobody declared, while it runs.
  static Process? reach;

  /// The steps that failed and were gone past.
  static final List<String> failed = [];
}

/// Runs one step of a played story: a picture of the window where it fails, and one line in the steps file the driver
/// reads, `PORELO_STORY_STEPS`: `OK <n> [<leans on>] <words>`, or `FAIL <n> [<leans on>] <words>: <why>` with what
/// was asked and got.
///
/// [step] starts with its number in the feature. [leansOn] names in one word the part of Porelo the step needs beyond
/// what is there for every story, so a driver told that part is missing can say the failure was expected. Where
/// [goesOn], the steps after it do not stand on it: its failure is noted and the story plays on, and the scenario
/// fails once it ended.
Future<void> played(
  WidgetTester tester,
  String step,
  Future<void> Function() body, {
  String? leansOn,
  bool goesOn = false,
}) async {
  final words = leansOn == null ? step : step.replaceFirst(' ', ' [$leansOn] ');
  try {
    await pictured(tester, body, name: 'step-${step.split(' ').first}');
  } catch (failure) {
    _note('FAIL $words: ${'$failure'.replaceAll('\n', ' | ')}');
    _keepTheTerminalBeside(step.split(' ').first);
    if (!goesOn) rethrow;
    if (Played.failed.isEmpty) {
      addTearDown(() {
        if (Played.failed.isNotEmpty) throw TestFailure('steps failed and were gone past: ${Played.failed.join(', ')}');
      });
    }
    Played.failed.add(step.split(' ').first);
    return;
  }
  _note('OK $words');
}

void _note(String line) {
  final into = Platform.environment['PORELO_STORY_STEPS'] ?? '';
  if (into.isNotEmpty) File(into).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
}

/// What the terminal on the machine showed when a step failed, beside the window's picture: it is not in the window.
void _keepTheTerminalBeside(String number) {
  final into = Platform.environment['PORELO_REHEARSAL_SHOTS'] ?? '';
  final beside = Played.beside;
  if (into.isEmpty || beside == null) return;
  try {
    Directory(into).createSync(recursive: true);
    File('$into/step-$number-terminal-on-the-machine.txt').writeAsStringSync(beside.text);
  } on FileSystemException catch (missed) {
    debugPrint('no copy of the terminal on the machine: $missed');
  }
}

/// A terminal on the test machine as a person opens one beside the window: a login shell under a pseudoterminal of
/// its own, drawn by the same terminal the window draws with, so what it shows can be read as a person reads it.
class TerminalOnTheMachine {
  TerminalOnTheMachine._(this._channel, this.terminal);

  /// Opens it, at [columns] by [rows]: a login shell in place where the test machine is this one, over ssh otherwise.
  static TerminalOnTheMachine open({int columns = 120, int rows = 30}) {
    final terminal = Terminal(maxLines: 2000)..resize(columns, rows);
    final channel = E2e.host == 'localhost'
        ? Pty.start('bash', ['-l'], columns: columns, rows: rows)
        : Pty.start('ssh', ['-tt', '-o', 'BatchMode=yes', E2e.host], columns: columns, rows: rows);
    final opened = TerminalOnTheMachine._(channel, terminal);
    terminal.onOutput = channel.send;
    opened._reading = channel.output.transform(const Utf8Decoder(allowMalformed: true)).listen(terminal.write);
    return opened;
  }

  final SessionChannel _channel;

  /// What draws it.
  final Terminal terminal;

  StreamSubscription<String>? _reading;

  /// Everything it shows, its scrollback with it, each line without its trailing blanks.
  String get text => lines.join('\n');

  /// The lines it shows, its scrollback with them.
  List<String> get lines => terminal.buffer.getText().split('\n').map((each) => each.trimRight()).toList();

  /// Types [words] and presses Enter.
  void say(String words) {
    terminal.textInput(words);
    terminal.keyInput(TerminalKey.enter);
  }

  /// Ends the shell and the terminal with it.
  Future<void> close() async {
    await _reading?.cancel();
    await _channel.close();
  }
}

/// The story's work as porelo lists it now, or null where it lists none.
Future<Map<String, dynamic>?> theWork() async => (await tasksOf(Played.project)).firstOrNull;

/// Runs [script] in the work's container, as the account that runs it, and answers what it printed.
Future<String> inTheWork(String script) async {
  final container = Played.container ?? fail('no work was started');
  final ran = await Process.run(
    'podman',
    ['exec', container, 'sh', '-c', script],
    environment: {'XDG_RUNTIME_DIR': await theAccountsRuntime()},
  );
  if (ran.exitCode != 0) throw StateError('in $container, `$script` failed with exit ${ran.exitCode}: ${ran.stderr}');
  return ran.stdout as String;
}

/// What the work's terminal session shows on the machine, its history with it: read from the session itself, never
/// from the window.
Future<List<String>> theSessionOfTheWork() async =>
    (await inTheWork('tmux capture-pane -p -J -S -2000 -t porelo'))
        .split('\n')
        .map((each) => each.trimRight())
        .toList();

/// The work's row in `porelo task list` as the machine prints it now: its name and its state, or null where it lists
/// none. The columns are read from the heading, so a wider one moves nothing here.
Future<({String name, String state})?> theListedRow() async {
  final lines = (await inTheAccount('porelo task list')).split('\n');
  final heading = lines.where((each) => each.startsWith('NAME ')).firstOrNull;
  if (heading == null) return null;
  final project = heading.indexOf('PROJECT'), kind = heading.indexOf('CLASS');
  final state = heading.indexOf('STATE'), age = heading.indexOf('AGE');
  String cut(String line, int from, int to) =>
      line.length <= from ? '' : line.substring(from, to < line.length ? to : line.length).trim();
  for (final line in lines.skip(lines.indexOf(heading) + 1)) {
    if (cut(line, project, kind) == Played.project) {
      return (name: cut(line, 0, project), state: cut(line, state, age));
    }
  }
  return null;
}

/// The first word of a state as porelo words it, without the age it may carry: `Up`, `Exited`, `done`.
String stateWord(String state) => state.split(' ').first;

/// Waits until the watch on the terminal beside shows the work's row as `porelo task list` prints it, the age left
/// out, and answers that row; at most [within]. Each try reads the listing again, since the work may move between.
Future<({String name, String state})> untilTheWatchShowsTheRow(
  WidgetTester tester, {
  Duration within = const Duration(seconds: 60),
  bool Function(({String name, String state}) row)? wanted,
}) async {
  final beside = Played.beside ?? fail('no terminal on the machine was opened');
  ({String name, String state})? row;
  var shown = <String>[];
  final by = DateTime.now().add(within);
  while (true) {
    row = await theListedRow();
    shown = beside.lines;
    if (row != null && (wanted == null || wanted(row))) {
      final listed = row;
      final seen = shown.any(
        (line) => line.contains(listed.name) && line.contains(Played.project) && line.contains(stateWord(listed.state)),
      );
      if (seen) return listed;
    }
    if (DateTime.now().isAfter(by)) {
      fail(
        'asked for the row porelo task list prints for ${Played.project} on the watch within ${within.inSeconds}s; '
        'porelo task list printed ${row == null ? 'no such row' : '${row.name} ${row.state}'}, the watch showed: '
        '${shown.where((each) => each.isNotEmpty).join(' / ')}',
      );
    }
    await pumpFor(tester, const Duration(seconds: 2));
  }
}

/// Sends the key [key] with Ctrl held to what has the keyboard, as the keyboard sends it.
Future<void> pressWithCtrl(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    await tester.sendKeyEvent(key);
  } finally {
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
  await pumpFor(tester);
}

/// Gives the work's terminal in the window the keyboard, as a person clicks into it.
Future<Terminal> intoTheTerminalOfTheWork(WidgetTester tester) async {
  final terminal = Played.ofTheWork ?? fail('the window showed no terminal of the work');
  final view = find.byKey(const Key('terminal'));
  if (view.evaluate().isNotEmpty) {
    await tester.tap(view.last);
    await pumpFor(tester);
  }
  return terminal;
}

/// Waits until [done] holds, at most [within]; fails with what [asked] says then, read at the end rather than at the
/// start, so it names what was last seen.
Future<void> until(
  WidgetTester tester,
  FutureOr<bool> Function() done, {
  required Duration within,
  required String Function() asked,
}) async {
  final by = DateTime.now().add(within);
  while (!await done()) {
    if (DateTime.now().isAfter(by)) fail('${asked()}, within ${within.inSeconds}s');
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
}

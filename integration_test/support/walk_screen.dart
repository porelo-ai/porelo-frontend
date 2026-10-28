import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:porelo_frontend/src/ui/terminal_copy.dart';
import 'package:xterm/xterm.dart';

/// How long one thing on screen is waited for.
const deadline = Duration(seconds: 30);

/// A value the walk's runner gives; the walk cannot be walked without it.
String givenByTheRunner(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('$name is required; run tool/walk_on_this_laptop.sh <walk number>');
  }
  return value;
}

/// What a step points at, by its key.
Finder byName(String name) => find.byKey(ValueKey<String>(name));

/// What `keepassxc ~/Porelo/secrets.kdbx` would show, as its command line lists it.
Future<String> listTheSecretsFile(String file, String master) async {
  final list = await Process.start('/usr/bin/keepassxc-cli', ['ls', '-R', file]);
  list.stdin.writeln(master);
  await list.stdin.close();
  final (out, err) = await (
    list.stdout.transform(utf8.decoder).join(),
    list.stderr.transform(utf8.decoder).join(),
  ).wait;
  expect(await list.exitCode, 0, reason: err);
  return out;
}

/// The window as a person walks it: waiting for what shows, pressing what can be pressed, and the walk's panel.
class WalkScreen {
  /// Constructor taking the tester that drives the real window.
  WalkScreen(this.tester);

  final WidgetTester tester;
  WalkSession? walk;

  Future<void> tick() async {
    // The integration binding uses real time, so sockets and the PTY can answer between frames.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump().timeout(deadline);
    final error = tester.takeException();
    if (error != null) throw TestFailure('$error');
  }

  Future<void> until(FutureOr<bool> Function() ready, String what, {Duration patience = deadline}) async {
    final elapsed = Stopwatch()..start();
    while (!await ready()) {
      if (elapsed.elapsed >= patience) fail('Timed out waiting for $what\n${dump()}');
      await tick();
    }
  }

  Future<void> shown(Finder target, {Duration patience = deadline}) =>
      until(() => target.evaluate().isNotEmpty, target.toString(describeSelf: true), patience: patience);

  /// The panel shows [step], moved there by itself, and points at something on screen.
  Future<void> atStep(int step, {Duration patience = deadline}) async {
    await until(() => walk!.index == step, 'the panel at step ${step + 1}', patience: patience);
    final at = walk!.current!.at;
    if (at.isEmpty) return;
    final root = tester.binding.rootElement!;
    final seen = at.where((key) => key.startsWith('walk-') || walkSees(root, key));
    expect(seen, isNotEmpty, reason: 'step ${step + 1} points at ${at.join(', ')}, none on screen\n${dump()}');
  }

  /// The panel does not move on by itself from [step]: it waits for Next.
  Future<void> stays(int step) async {
    for (var i = 0; i < 30; i++) {
      await tick();
    }
    expect(walk!.index, step, reason: 'step ${step + 1} waits for Next');
  }

  /// Next in the panel, as the person clicks it.
  Future<void> panelNext() async {
    final next = byName('walk-next');
    if (next.evaluate().isNotEmpty) {
      await tap(next);
    } else {
      walk!.next();
      await tick();
    }
  }

  void noneLost(String folder) {
    final comments = File('$folder/comments.jsonl');
    final lost = comments.existsSync()
        ? comments.readAsLinesSync().where((line) => line.contains('lost its way'))
        : <String>[];
    expect(lost, isEmpty, reason: 'the walk never lost its way');
  }

  /// What the panel's ball is on now: the first of the step's targets that is on screen.
  String? get pointer {
    final step = walk?.current;
    if (step == null) return null;
    final root = tester.binding.rootElement!;
    return step.at.where((key) => key.startsWith('walk-') || walkSees(root, key)).firstOrNull;
  }

  /// Clicks what is keyed [name], as a person following the ball does: where the step names it among its targets,
  /// the ball is on it before the click.
  Future<void> click(String name) async {
    await see(byName(name));
    // `usable:` and `filled:` say when a target counts; the target is the key after them.
    String bare(String key) => key.replaceFirst(RegExp('^(usable|filled):'), '');
    bool names(String key) =>
        key == name ||
        (key.contains('*') && RegExp('^${key.split('*').map(RegExp.escape).join('.*')}\$').hasMatch(name));
    final at = (walk?.current?.at ?? const <String>[]).map(bare);
    if (at.any(names)) {
      await until(() => pointer != null, 'the ball on a target');
      final on = bare(pointer!);
      expect(names(on), isTrue, reason: 'the ball is on $on, not on $name, which is clicked now');
    }
    await tap(byName(name));
  }

  Future<void> see(Finder target) async {
    await shown(target);
    await tester.ensureVisible(target.first).timeout(deadline);
    await tick();
  }

  Future<void> tap(Finder target) async {
    await see(target);
    await until(
      () => target.hitTestable().evaluate().isNotEmpty,
      '${target.toString(describeSelf: true)} to accept a pointer',
    );
    // As a person does: a button is pressed once it can be.
    await until(() {
      final widget = target.evaluate().first.widget;
      return widget is! ButtonStyleButton || widget.enabled;
    }, '${target.toString(describeSelf: true)} to be enabled');
    await tester.tap(target.first).timeout(deadline);
    // Menus and dialogs must finish growing before the next pointer lands.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tick();
  }

  Future<void> goTo(String place) async {
    final entry = byName('rail $place');
    if (entry.evaluate().isEmpty) await tap(find.byTooltip('Open navigation menu'));
    await tap(entry);
  }

  Future<void> fill(String id, String value) async {
    final field = byName(id);
    await tap(field);
    final input = tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)));
    await until(() => input.widget.focusNode.hasPrimaryFocus, '$id to own keyboard focus');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft).timeout(deadline);
    try {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA).timeout(deadline);
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft).timeout(deadline);
    }
    await tick();
    final before = input.currentTextEditingValue;
    input.updateEditingValue(
      before.copyWith(
        text: before.text.replaceRange(before.selection.start, before.selection.end, value),
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      ),
    );
    await tick();
    expect(tester.widget<TextField>(field).controller?.text, value);
  }

  Terminal get terminal => tester.widget<TerminalView>(byName('unlock-terminal')).terminal;

  String get terminalText {
    final term = terminal;
    return copiedText(term, BufferRangeLine(CellOffset(0, 0), CellOffset(term.viewWidth - 1, term.buffer.height - 1)));
  }

  Future<void> terminalSays(String words) => until(() => terminalText.contains(words), 'terminal: $words');

  /// What the terminal keyed [name] shows.
  String textOf(String name) {
    final term = tester.widget<TerminalView>(byName(name)).terminal;
    return copiedText(term, BufferRangeLine(CellOffset(0, 0), CellOffset(term.viewWidth - 1, term.buffer.height - 1)));
  }

  /// Types [answer] and Enter into the terminal keyed [name], as a person does.
  Future<void> typeInto(String name, String answer) async {
    final term = tester.widget<TerminalView>(byName(name)).terminal;
    term.textInput(answer);
    term.keyInput(TerminalKey.enter);
    await tick();
  }

  Future<void> typeInTerminal(String answer) async {
    terminal.textInput(answer);
    terminal.keyInput(TerminalKey.enter);
    await tick();
  }

  String dump() {
    final lines = <String>['The screen showed:'];
    for (final widget in tester.allWidgets) {
      switch (widget) {
        case Text(:final data, :final textSpan):
          lines.add(data ?? textSpan?.toPlainText() ?? '');
        case SelectableText(:final data, :final textSpan):
          lines.add(data ?? textSpan?.toPlainText() ?? '');
        case EditableText(:final controller, :final obscureText):
          lines.add(obscureText ? '[obscured]' : '[${controller.text}]');
      }
    }
    if (byName('unlock-terminal').evaluate().isNotEmpty) lines.add('Terminal:\n$terminalText');
    return lines.where((line) => line.isNotEmpty).join('\n');
  }
}

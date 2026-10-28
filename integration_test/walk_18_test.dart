import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:integration_test/integration_test.dart';
import 'package:porelo_frontend/main.dart' as app;
import 'package:porelo_frontend/src/ui/terminal_copy.dart';
import 'package:xterm/xterm.dart';

import 'support/e2e.dart' show choose;

// Harm: a walk handed to a person that stalls, points at nothing, or asks for a value it never gives. Walk 18
// is walked here as the person walks it: the real interface, the real keepassxc-cli, the local Porelo and
// the test machine, and at each step the panel is where the walk says, pointing at something on screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk 18 can be walked through its panel from its first step to its last', (tester) async {
    final screen = _Screen(tester);
    final folder = _required('PORELO_WALK');
    try {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final interface = await app.porelo().timeout(_deadline);
      final walk = interface.walk!;
      screen.walk = walk;
      await tester.pumpWidget(interface).timeout(_deadline);
      await screen.shown(_key('shell-rail'));

      // 6d-1: what it needs is in place; the panel stays until Next.
      await screen.atStep(0);
      await screen.stays(0);
      await screen.panelNext();

      // 6d-2.
      await screen.atStep(1);
      await screen.goTo('projects');
      await screen.tap(_key('project sprint5'));
      await screen.tap(_key('project-menu'));
      await screen.tap(_key('project.server'));

      // 6d-3: the fields as remembered, Next three times, stopping at the secrets file.
      await screen.atStep(2);
      await screen.fill('host-scaleway-project', _required('PORELO_WALK_SCALEWAY_PROJECT'));
      await screen.fill('host-account', 'porelo');
      await screen.tap(_key('wizard-next'));
      await screen.fill('host-signing-key', _required('PORELO_WALK_SIGNING_KEY'));
      await screen.tap(_key('wizard-next'));
      await screen.fill('host-identity', '$folder/keys/walk_ed25519');
      await screen.tap(_key('wizard-next'));

      // 6d-4: the file's place, and the button.
      await screen.atStep(3);
      final home = Platform.environment['HOME']!;
      expect(tester.widget<TextField>(_key('host-secrets-file')).controller?.text, '$home/Porelo/secrets.kdbx');
      await screen.see(find.text('It is not there yet: setup makes it, with a master password you choose.'));
      expect(find.text('Make it now'), findsOneWidget);
      expect(_key('host-secrets-file-refused'), findsNothing, reason: 'keepassxc-cli is installed here');
      await screen.tap(_key('host-secrets-open'));

      // 6d-5.
      await screen.atStep(4);
      await screen.terminalSays('password');
      const master = 'invented-walk-18-master';
      await screen.typeInTerminal(master);
      await screen.typeInTerminal(master);
      await screen.terminalSays('The secrets file is ready');
      expect(screen.terminalText, isNot(contains(master)), reason: 'the master password is never shown');
      await screen.tap(_key('unlock-done'));

      // 6d-6.
      await screen.atStep(5);
      await screen.see(find.text('Ready: the file keeps the server’s keys.'));
      await screen.tap(_key('wizard-leave'));
      await screen.tap(_key('wizard-confirm-leave'));

      // 6d-7: what KeePassXC shows, read with its command line; the panel stays until Next.
      await screen.atStep(6);
      final listed = await _listTheFile('$home/Porelo/secrets.kdbx', master);
      for (final entry in ['shared/', 'hosts/', 'sprint5/', 'wireguard', 'vault-passphrase']) {
        expect(listed, contains(entry), reason: 'the file keeps $entry');
      }
      await screen.stays(6);
      await screen.panelNext();

      // 6d-8: the test machine, every value as the step gives it.
      await screen.atStep(7);
      await screen.goTo('machines');
      await screen.tap(_key('machines-add'));
      await screen.fill('machine-name', 'vm');
      await choose(tester, 'machine-admin', 'machine-admin-no');
      await choose(tester, 'machine-kind-choice', 'machine-raise-it');
      await screen.tap(_key('wizard-next'));
      await screen.fill('machine-host', 'frontend@192.168.122.174');
      await screen.fill('machine-remote-socket', '/run/user/1006/porelo/porelod.sock');
      await screen.tap(_key('try-it'));
      await screen.shown(_key('trial-result'), patience: const Duration(seconds: 60));
      debugPrint('Try the connection said: ${tester.widget<SelectableText>(_key('trial-result')).data}');
      await screen.tap(_key('watch-it'));
      await screen.shown(find.byKey(const ValueKey<String>('machines-row vm')));

      // 6d-9.
      await screen.atStep(8);
      await screen.until(
        () => find.descendant(of: _key('machines-row vm'), matching: find.text('Connected')).evaluate().isNotEmpty,
        'vm to be Connected',
        patience: const Duration(seconds: 60),
      );
      await screen.goTo('projects');
      await screen.tap(_key('project f148walk'));
      // vm shown for the first time: its first check opens over the project, and is closed.
      await screen.see(_key('check-again'));
      await screen.tap(find.byTooltip('Close (Esc)'));
      await screen.tap(_key('project-menu'));
      await screen.tap(_key('project.startAgents'));

      // 6d-10.
      await screen.atStep(9, patience: const Duration(seconds: 60));
      for (final row in ['alpha', 'beta', 'gamma']) {
        await screen.see(find.byKey(ValueKey<String>('start-agents-row $row')));
      }
      expect(find.descendant(of: _key('start-agents-row alpha'), matching: find.text('Agent Alpha')), findsOneWidget);
      expect(
        tester.widget(_key('start-agents-row gamma')),
        isNot(isA<CheckboxListTile>()),
        reason: 'gamma is not offered',
      );
      await screen.see(find.text('gamma names no agent'));
      await screen.tap(find.descendant(of: _key('start-agents-row beta'), matching: find.byType(Checkbox)));
      await screen.tap(_key('wizard-next'));

      // 6d-11: the stub's sign-in, where nothing is stored for it yet.
      await screen.atStep(10, patience: const Duration(seconds: 60));
      final canStart = find.text('The machine says every agent to start can start.');
      await screen.until(
        () => canStart.evaluate().isNotEmpty || _key('start-agents-sign-in stub').evaluate().isNotEmpty,
        'the sign-ins to be asked',
        patience: const Duration(seconds: 60),
      );
      if (canStart.evaluate().isEmpty) {
        await screen.tap(_key('start-agents-sign-in stub'));
        await screen.until(
          () => find
              .text('Signed in to Stub Agent: the credential is stored on vm. You can close this.')
              .evaluate()
              .isNotEmpty,
          'the stub to be signed in',
          patience: const Duration(minutes: 15),
        );
        await screen.tap(_key('unlock-done'));
        await screen.until(
          () => canStart.evaluate().isNotEmpty,
          'the stub signed in and the step asking again by itself',
          patience: const Duration(minutes: 15),
        );
        debugPrint('Signed in to the stub; the step asked again by itself.');
      }
      await screen.tap(_key('wizard-next'));

      // 6d-12.
      await screen.atStep(11);
      await screen.see(find.text('beta is left out'));
      await screen.tap(_key('start-it'));
      // In the dialog's own outcome row: the panel beside it says the same words.
      final alpha = _key('start-agents-outcome alpha');
      await screen.until(
        () =>
            find.descendant(of: alpha, matching: find.text('Agent Alpha started')).evaluate().isNotEmpty ||
            find.descendant(of: alpha, matching: find.textContaining('was not started')).evaluate().isNotEmpty,
        'Alpha to start',
        patience: const Duration(minutes: 15),
      );
      expect(
        find.descendant(of: alpha, matching: find.text('Agent Alpha started')),
        findsOneWidget,
        reason: screen.dump(),
      );
      expect(_key('start-agents-outcome beta'), findsNothing, reason: 'beta was left out');

      // 6d-13.
      await screen.tap(_key('wizard-leave'));
      final confirm = _key('wizard-confirm-leave');
      if (confirm.evaluate().isNotEmpty) await screen.tap(confirm);
      await screen.atStep(12);
      await screen.tap(_key('project-menu'));
      await screen.tap(_key('project.startAgents'));
      await screen.see(find.byKey(const ValueKey<String>('start-agents-row beta')));
      expect(
        tester.widget(_key('start-agents-row beta')),
        isA<CheckboxListTile>(),
        reason: 'beta, left out, is offered',
      );
      expect(tester.widget(_key('start-agents-row alpha')), isNot(isA<CheckboxListTile>()), reason: 'Alpha runs');
      await screen.see(find.text('Agent Alpha runs already, as alpha'));
      screen.noneLost(folder);
    } catch (error, stack) {
      debugPrint('Walk 18 failed at step ${screen.walk?.index}: $error\n$stack\n${screen.dump()}');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}

const _deadline = Duration(seconds: 30);

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) throw StateError('$name is required; run tool/walk_18_e2e.sh');
  return value;
}

Finder _key(String name) => find.byKey(ValueKey<String>(name));

/// What `keepassxc ~/Porelo/secrets.kdbx` would show, as its command line lists it.
Future<String> _listTheFile(String file, String master) async {
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

class _Screen {
  _Screen(this.tester);

  final WidgetTester tester;
  WalkSession? walk;

  Future<void> tick() async {
    // The integration binding uses real time, so sockets and the PTY can answer between frames.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump().timeout(_deadline);
    final error = tester.takeException();
    if (error != null) throw TestFailure('$error');
  }

  Future<void> until(FutureOr<bool> Function() ready, String what, {Duration patience = _deadline}) async {
    final elapsed = Stopwatch()..start();
    while (!await ready()) {
      if (elapsed.elapsed >= patience) fail('Timed out waiting for $what\n${dump()}');
      await tick();
    }
  }

  Future<void> shown(Finder target, {Duration patience = _deadline}) =>
      until(() => target.evaluate().isNotEmpty, target.toString(describeSelf: true), patience: patience);

  /// The panel shows [step], moved there by itself, and points at something on screen.
  Future<void> atStep(int step, {Duration patience = _deadline}) async {
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
    final next = _key('walk-next');
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

  Future<void> see(Finder target) async {
    await shown(target);
    await tester.ensureVisible(target.first).timeout(_deadline);
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
    await tester.tap(target.first).timeout(_deadline);
    // Menus and dialogs must finish growing before the next pointer lands.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tick();
  }

  Future<void> goTo(String place) async {
    final entry = _key('rail $place');
    if (entry.evaluate().isEmpty) await tap(find.byTooltip('Open navigation menu'));
    await tap(entry);
  }

  Future<void> fill(String id, String value) async {
    final field = _key(id);
    await tap(field);
    final input = tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)));
    await until(() => input.widget.focusNode.hasPrimaryFocus, '$id to own keyboard focus');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft).timeout(_deadline);
    try {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA).timeout(_deadline);
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft).timeout(_deadline);
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

  Terminal get terminal => tester.widget<TerminalView>(_key('unlock-terminal')).terminal;

  String get terminalText {
    final term = terminal;
    return copiedText(term, BufferRangeLine(CellOffset(0, 0), CellOffset(term.viewWidth - 1, term.buffer.height - 1)));
  }

  Future<void> terminalSays(String words) => until(() => terminalText.contains(words), 'terminal: $words');

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
    if (_key('unlock-terminal').evaluate().isNotEmpty) lines.add('Terminal:\n$terminalText');
    return lines.where((line) => line.isNotEmpty).join('\n');
  }
}

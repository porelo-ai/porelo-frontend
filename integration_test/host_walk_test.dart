import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:porelo_frontend/main.dart' as app;
import 'package:porelo_frontend/src/ui/terminal_copy.dart';
import 'package:xterm/xterm.dart';

// Guards the host setup stop against exposing secrets or resuming without the person's terminal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the host walk prepares files, refuses unsafe input and completes through its terminal', (tester) async {
    final screen = _Screen(tester);
    try {
      final walk = _required('PORELO_WALK');
      final config = _required('XDG_CONFIG_HOME');
      final settings = File('$config/porelo/frontend.json');
      await settings.parent.create(recursive: true).timeout(_deadline);
      await settings
          .writeAsString(
            jsonEncode({
              'tresorFolders': {'checkout': '$walk/tresor'},
            }),
          )
          .timeout(_deadline);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(await app.porelo().timeout(_deadline)).timeout(_deadline);
      await screen.shown(_key('shell-rail'));

      await screen.goTo('machines');
      await screen.shown(_key('machines-row first.sock'));
      expect(find.text('first.sock'), findsWidgets);
      await screen.goTo('projects');
      await screen.tap(_key('project checkout'));
      await screen.tap(_key('project-menu'));
      await screen.shown(_key('project.server'));
      expect(
        find.descendant(of: _key('project.server'), matching: find.text('Put this project on a server…')),
        findsOneWidget,
      );
      await screen.tap(_key('project.server'));

      expect(_key('host-up'), findsNothing, reason: 'the review cannot be reached on half an answer');
      expect(tester.widget<FilledButton>(_key('wizard-next')).onPressed, isNull);
      await screen.fill('host-scaleway-project', 'walk');
      await screen.tap(_key('wizard-next'));

      await screen.see(find.text('$walk/tresor'));
      await screen.chooseBeside('host-folder');
      expect(tester.widget<TextField>(_key('host-tresor')).controller?.text, 'tresor');
      await screen.see(_key('host-folder'));
      expect(find.descendant(of: _key('host-folder'), matching: find.text('Choose…')), findsOneWidget);
      await screen.field('host-repository', 'Project repository address');
      await screen.field('host-signing-key', 'Public key for signing commits (.pub)');
      await screen.chooseBeside('host-signing-key');
      await screen.fill('host-tresor', 'walk');
      await screen.fill('host-repository', 'https://example.org/walk.git');
      await screen.fill('host-signing-key', '$walk/keys/walk_ed25519.pub');
      await screen.tap(_key('wizard-next'));

      await screen.chooseBeside('host-identity');
      await screen.chooseBeside('host-public-key');
      await screen.fill('host-identity', '~nobody/key');
      expect(tester.widget<FilledButton>(_key('wizard-next')).onPressed, isNull);
      await screen.see(find.text('Cannot use ~nobody; only ~/ is understood.'));
      expect(_steps(), findsNothing, reason: 'a refused path must not start host setup');
      expect(_key('host-stop'), findsNothing);
      expect(_key('host-up'), findsNothing);
      await screen.fill('host-identity', '$walk/keys/walk_ed25519.pub');
      expect(tester.widget<FilledButton>(_key('wizard-next')).onPressed, isNull);
      await screen.see(find.textContaining('Choose the private ssh key'));
      await screen.fill('host-identity', '$walk/keys/walk_ed25519');
      // Harm: a home-relative key path must resolve before renting, without using an account key.
      expect(Platform.environment['HOME'], '$walk/home');
      await screen.fill('host-public-key', '~/../keys/walk_ed25519.pub');
      await screen.tap(_key('wizard-next'));

      await screen.chooseBeside('host-collection');
      await screen.fill('host-collection', '$walk/porelo-host');
      await screen.fill('host-collection-sha256', _required('PORELO_WALK_COLLECTION_SHA256'));
      await screen.tap(_key('wizard-next'));
      await screen.tap(_key('host-up'));
      await screen.shown(_key('host-stop'));
      for (final name in ['rent', 'ssh', 'copy', 'ansible', 'play', 'person']) {
        await screen.see(_key('host-step-$name'));
        expect(find.descendant(of: _key('host-step-$name'), matching: find.text(name)), findsOneWidget);
      }
      await screen.see(find.text('The host needs a Tresorit login.'));
      await screen.see(find.text('The host needs a passphrase for its new vault.'));
      await screen.field('host-drive-email', 'Tresorit e-mail');
      expect(find.descendant(of: _key('host-stop'), matching: find.byType(TextField)), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is EditableText && widget.obscureText),
        findsNothing,
        reason: 'host secrets belong only in the terminal',
      );

      await screen.fill('host-drive-email', "walk'x@example.org");
      await screen.tap(_key('host-open-terminal'));
      await screen.see(find.text('Enter a plain Tresorit e-mail address with no spaces, quotes or shell characters.'));
      expect(_key('unlock-terminal'), findsNothing);
      expect(find.text('Complete setup on checkout server'), findsNothing);

      await screen.fill('host-drive-email', 'walk@example.org');
      await screen.tap(_key('host-open-terminal'));
      await screen.see(_key('unlock-terminal'));
      expect(find.text('Complete setup on checkout server'), findsOneWidget);
      await screen.terminalSays('The one-time code will show as you type it.');
      await screen.terminalSays('Password:');
      const password = 'invented-walk-password';
      const passphrase = 'invented-walk-passphrase';
      void noSecrets() {
        expect(screen.terminalText, isNot(contains(password)), reason: 'the password must never echo');
        expect(screen.terminalText, isNot(contains(passphrase)), reason: 'the passphrase must never echo');
      }

      await screen.typeInTerminal(password);
      await screen.terminalSays('Enter your one-time password:');
      noSecrets();
      await screen.typeInTerminal('123456');
      await screen.terminalSays('123456');
      await screen.terminalSays('Logged in to Tresorit; the vault comes next.');
      await screen.terminalSays('New vault passphrase:');
      noSecrets();
      await screen.typeInTerminal(passphrase);
      await screen.terminalSays('New vault passphrase again:');
      noSecrets();
      await screen.typeInTerminal(passphrase);
      await screen.terminalSays('Vault initialized; close this terminal to continue host setup.');
      await screen.shown(_key('unlock-done'));
      noSecrets();
      expect(screen.terminalText, contains('123456'));
      expect(find.descendant(of: _key('unlock-done'), matching: find.text('Done')), findsOneWidget);

      await screen.tap(_key('unlock-done'));
      await screen.until(() {
        expect(_key('host-stop'), findsNothing, reason: 'resuming must not ask for a second stop');
        return _key('host-done').evaluate().isNotEmpty;
      }, 'host setup to finish without another stop');
      await screen.see(_key('host-done'));
      expect(tester.widget<Text>(_key('host-done')).data, 'Done.');
      for (final name in ['rent', 'ssh', 'copy', 'ansible', 'play', 'drive', 'vault', 'up']) {
        expect(_key('host-step-$name'), findsOneWidget, reason: 'the resumed run includes $name');
      }
      expect(_key('host-step-person'), findsNothing);
      expect(_key('unlock-terminal'), findsNothing);

      await screen.see(_key('host-export-tunnel'));
      expect(
        find.descendant(of: _key('host-export-tunnel'), matching: find.text('Save the VPN connection to this server')),
        findsOneWidget,
      );
      final info = find.byIcon(Icons.info_outline).last;
      await screen.tap(info);
      await screen.shown(find.textContaining('sudo install -m 600 <saved file> /etc/wireguard/porelo.conf'));
      expect(find.textContaining('sudo wg-quick up porelo'), findsOneWidget);
    } catch (error, stack) {
      debugPrint('Host walk failed: $error\n$stack\n${screen.dump()}');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

const _deadline = Duration(seconds: 30);

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) throw StateError('$name is required; run tool/walk_e2e.sh');
  return value;
}

Finder _key(String name) => find.byKey(Key(name));

Finder _steps() => find.byWidgetPredicate(
  (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('host-step-'),
);

class _Screen {
  _Screen(this.tester);

  final WidgetTester tester;

  Future<void> tick() async {
    // The integration binding uses real time, so sockets and the PTY can answer between frames.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump().timeout(_deadline);
    final error = tester.takeException();
    if (error != null) throw TestFailure('$error');
  }

  Future<void> until(bool Function() ready, String what) async {
    final elapsed = Stopwatch()..start();
    while (!ready()) {
      if (elapsed.elapsed >= _deadline) fail('Timed out waiting for $what\n${dump()}');
      await tick();
    }
  }

  Future<void> shown(Finder target) => until(() => target.evaluate().isNotEmpty, '$target');

  Future<void> see(Finder target) async {
    await shown(target);
    await tester.ensureVisible(target).timeout(_deadline);
    await tick();
  }

  Future<void> tap(Finder target) async {
    await see(target);
    await until(() => target.hitTestable().evaluate().isNotEmpty, '$target to accept a pointer');
    await tester.tap(target).timeout(_deadline);
    // Menus and dialogs must finish growing before the next pointer lands.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tick();
  }

  Future<void> goTo(String place) async {
    final entry = _key('rail $place');
    if (entry.evaluate().isEmpty) await tap(find.byTooltip('Open navigation menu'));
    await tap(entry);
  }

  Future<void> chooseBeside(String id) async {
    final row = find.ancestor(of: _key(id), matching: find.byType(Row)).first;
    final choose = find.descendant(of: row, matching: find.text('Choose…'));
    await see(choose);
    expect(choose.hitTestable(), findsOneWidget, reason: '$id has its own reachable Choose… button');
  }

  Future<void> field(String id, String label) async {
    await see(_key(id));
    expect(tester.widget<TextField>(_key(id)).decoration?.labelText, label);
  }

  Future<void> fill(String id, String value) async {
    final field = _key(id);
    await tap(field);
    final input = tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)));
    expect(tester.widget<TextField>(field).enabled, isTrue, reason: '$id must allow editing');
    expect(input.widget.readOnly, isFalse, reason: '$id must allow editing');
    await until(() => input.widget.focusNode.hasPrimaryFocus, '$id to own keyboard focus');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft).timeout(_deadline);
    try {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA).timeout(_deadline);
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft).timeout(_deadline);
    }
    await tick();
    final before = input.currentTextEditingValue;
    expect(before.selection.start, 0, reason: 'Ctrl+A must select the start of $id');
    expect(before.selection.end, before.text.length, reason: 'Ctrl+A must select all of $id');
    expect(input.widget.focusNode.hasPrimaryFocus, isTrue, reason: '$id must still own keyboard focus');
    // Use the focused field's platform-input handler, avoiding the test binding's cached client.
    input.updateEditingValue(
      before.copyWith(
        text: before.text.replaceRange(before.selection.start, before.selection.end, value),
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      ),
    );
    await tick();
    expect(tester.widget<TextField>(_key(id)).controller?.text, value);
  }

  Terminal get terminal => tester.widget<TerminalView>(_key('unlock-terminal')).terminal;

  String get terminalText {
    final term = terminal;
    return copiedText(term, BufferRangeLine(CellOffset(0, 0), CellOffset(term.viewWidth - 1, term.buffer.height - 1)));
  }

  Future<void> terminalSays(String words) => until(() => terminalText.contains(words), 'terminal: $words');

  Future<void> typeInTerminal(String answer) async {
    // TerminalView feeds these same methods; Session.onOutput sends their bytes to the real PTY.
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
        case TextField(:final decoration):
          lines.add('Field: ${decoration?.labelText}');
        case EditableText(:final controller, :final obscureText):
          lines.add(obscureText ? '[obscured]' : '[${controller.text}]');
      }
    }
    if (_key('unlock-terminal').evaluate().isNotEmpty) lines.add('Terminal:\n$terminalText');
    return lines.where((line) => line.isNotEmpty).join('\n');
  }
}

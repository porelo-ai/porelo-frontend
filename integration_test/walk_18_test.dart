import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:porelo_frontend/main.dart' as app;

import 'support/e2e.dart' show choose;
import 'support/walk_screen.dart';

// Harm: a walk handed to a person that stalls, points at nothing, or asks for a value it never gives. Walk 18
// is walked here as the person walks it: the real interface, the real keepassxc-cli, the local Porelo and
// the test machine, and at each step the panel is where the walk says, pointing at something on screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk 18 can be walked through its panel from its first step to its last', (tester) async {
    final screen = WalkScreen(tester);
    final folder = givenByTheRunner('PORELO_WALK');
    try {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final interface = await app.porelo().timeout(deadline);
      final walk = interface.walk!;
      screen.walk = walk;
      await tester.pumpWidget(interface).timeout(deadline);
      await screen.shown(byName('shell-rail'));

      // 6d-1: what it needs is in place; the panel stays until Next.
      await screen.atStep(0);
      await screen.stays(0);
      await screen.panelNext();

      // 6d-2.
      await screen.atStep(1);
      await screen.goTo('projects');
      await screen.tap(byName('project ${givenByTheRunner('PORELO_WALK_PROJECT')}'));
      await screen.click('project-menu');
      await screen.click('project.server');

      // 6d-3: the fields as remembered, Next three times, stopping at the secrets file.
      await screen.atStep(2);
      await screen.fill('host-scaleway-project', givenByTheRunner('PORELO_WALK_SCALEWAY_PROJECT'));
      await screen.fill('host-account', 'porelo');
      await screen.click('wizard-next');
      await screen.fill('host-signing-key', givenByTheRunner('PORELO_WALK_SIGNING_KEY'));
      await screen.click('wizard-next');
      await screen.fill('host-identity', '$folder/keys/walk_ed25519');
      await screen.click('wizard-next');

      // 6d-4: the file's place, and the button.
      await screen.atStep(3);
      final home = Platform.environment['HOME']!;
      expect(tester.widget<TextField>(byName('host-secrets-file')).controller?.text, '$home/Porelo/secrets.kdbx');
      await screen.see(find.text('It is not there yet: setup makes it, with a master password you choose.'));
      expect(find.text('Make it now'), findsOneWidget);
      expect(byName('host-secrets-file-refused'), findsNothing, reason: 'keepassxc-cli is installed here');
      await screen.click('host-secrets-open');

      // 6d-5.
      await screen.atStep(4);
      await screen.terminalSays('password');
      const master = 'invented-walk-18-master';
      await screen.typeInTerminal(master);
      await screen.typeInTerminal(master);
      await screen.terminalSays('The secrets file is ready');
      expect(screen.terminalText, isNot(contains(master)), reason: 'the master password is never shown');
      await screen.click('unlock-done');

      // 6d-6.
      await screen.atStep(5);
      await screen.see(find.text('Ready: the file keeps the server’s keys.'));
      await screen.click('wizard-leave');
      await screen.click('wizard-confirm-leave');

      // 6d-7: what KeePassXC shows, read with its command line; the panel stays until Next.
      await screen.atStep(6);
      final listed = await listTheSecretsFile('$home/Porelo/secrets.kdbx', master);
      for (final entry in [
        'shared/',
        'hosts/',
        '${givenByTheRunner('PORELO_WALK_PROJECT')}/',
        'wireguard',
        'vault-passphrase',
      ]) {
        expect(listed, contains(entry), reason: 'the file keeps $entry');
      }
      await screen.stays(6);
      await screen.panelNext();

      // 6d-8: the test machine, every value as the step gives it.
      await screen.atStep(7);
      await screen.goTo('machines');
      await screen.click('machines-add');
      await screen.fill('machine-name', 'vm');
      await choose(tester, 'machine-admin', 'machine-admin-no');
      await choose(tester, 'machine-kind-choice', 'machine-raise-it');
      await screen.click('wizard-next');

      // 6d-9: the two values; the panel moves on once both are there.
      await screen.atStep(8);
      await screen.fill('machine-host', 'frontend@192.168.122.174');
      await screen.fill('machine-remote-socket', '/run/user/1006/porelo/porelod.sock');

      // 6d-10.
      await screen.atStep(9);
      await screen.click('try-it');
      await screen.shown(byName('trial-result'), patience: const Duration(seconds: 60));
      debugPrint('Try the connection said: ${tester.widget<SelectableText>(byName('trial-result')).data}');

      // 6d-11.
      await screen.atStep(10);
      await screen.click('watch-it');
      await screen.shown(find.byKey(const ValueKey<String>('machines-row vm')));

      // 6d-12.
      await screen.atStep(11);
      await screen.until(
        () => find.descendant(of: byName('machines-row vm'), matching: find.text('Connected')).evaluate().isNotEmpty,
        'vm to be Connected',
        patience: const Duration(seconds: 60),
      );
      await screen.goTo('projects');
      await screen.click('project f148walk');
      // vm shown for the first time: its first check opens over the project, and is closed.
      await screen.see(byName('check-again'));
      await screen.tap(find.byTooltip('Close (Esc)'));
      await screen.click('project-menu');
      await screen.click('project.startAgents');

      // 6d-13.
      await screen.atStep(12, patience: const Duration(seconds: 60));
      for (final row in ['alpha', 'beta', 'gamma']) {
        await screen.see(find.byKey(ValueKey<String>('start-agents-row $row')));
      }
      expect(find.descendant(of: byName('start-agents-row alpha'), matching: find.text('Agent Alpha')), findsOneWidget);
      expect(
        tester.widget(byName('start-agents-row gamma')),
        isNot(isA<CheckboxListTile>()),
        reason: 'gamma is not offered',
      );
      await screen.see(find.text('gamma names no agent'));
      await screen.tap(find.descendant(of: byName('start-agents-row beta'), matching: find.byType(Checkbox)));
      await screen.click('wizard-next');

      // 6d-14: the stub's sign-in, where nothing is stored for it yet.
      await screen.atStep(13, patience: const Duration(seconds: 60));
      final canStart = find.text('The machine says every agent to start can start.');
      await screen.until(
        () => canStart.evaluate().isNotEmpty || byName('start-agents-sign-in stub').evaluate().isNotEmpty,
        'the sign-ins to be asked',
        patience: const Duration(seconds: 60),
      );
      if (canStart.evaluate().isEmpty) {
        await screen.click('start-agents-sign-in stub');
        await screen.until(
          () => find
              .text('Signed in to Stub Agent: the credential is stored on vm. You can close this.')
              .evaluate()
              .isNotEmpty,
          'the stub to be signed in',
          patience: const Duration(minutes: 15),
        );
        await screen.click('unlock-done');
        await screen.until(
          () => canStart.evaluate().isNotEmpty,
          'the stub signed in and the step asking again by itself',
          patience: const Duration(minutes: 15),
        );
        debugPrint('Signed in to the stub; the step asked again by itself.');
      }
      await screen.click('wizard-next');

      // 6d-15.
      await screen.atStep(14);
      await screen.see(find.text('beta is left out'));
      await screen.click('start-it');
      // In the dialog's own outcome row: the panel beside it says the same words.
      final alpha = byName('start-agents-outcome alpha');
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
      expect(byName('start-agents-outcome beta'), findsNothing, reason: 'beta was left out');

      // 6d-16.
      await screen.click('wizard-leave');
      final confirm = byName('wizard-confirm-leave');
      if (confirm.evaluate().isNotEmpty) await screen.tap(confirm);
      await screen.atStep(15);
      await screen.click('project-menu');
      await screen.click('project.startAgents');
      await screen.see(find.byKey(const ValueKey<String>('start-agents-row beta')));
      expect(
        tester.widget(byName('start-agents-row beta')),
        isA<CheckboxListTile>(),
        reason: 'beta, left out, is offered',
      );
      expect(tester.widget(byName('start-agents-row alpha')), isNot(isA<CheckboxListTile>()), reason: 'Alpha runs');
      await screen.see(find.text('Agent Alpha runs already, as alpha'));
      screen.noneLost(folder);
    } catch (error, stack) {
      debugPrint('Walk 18 failed at step ${screen.walk?.index}: $error\n$stack\n${screen.dump()}');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:porelo_frontend/main.dart' as app;

import 'support/e2e.dart' show choose;
import 'support/walk_screen.dart';

// Harm: a walk handed to a person that stalls, points at nothing, or asks for a value it never gives. Walk 20 is
// walked here on the test machine as root, as the person walks it, up to the Tresorit sign-in, which is theirs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk 20 can be walked through its panel up to the Tresorit sign-in', (tester) async {
    final screen = WalkScreen(tester);
    final folder = givenByTheRunner('PORELO_WALK');
    final home = Platform.environment['HOME']!;
    final user = givenByTheRunner('PORELO_WALK_WORK_USER');
    try {
      // The key root on the test machine takes, where the wizard looks for keys: linked, never copied.
      final ssh = Directory('$home/.ssh')..createSync(recursive: true);
      final key = givenByTheRunner('PORELO_WALK_KEY');
      Link('${ssh.path}/porelo-vm-admin').createSync(key);
      Link('${ssh.path}/porelo-vm-admin.pub').createSync('$key.pub');

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final interface = await app.porelo().timeout(deadline);
      screen.walk = interface.walk;
      await tester.pumpWidget(interface).timeout(deadline);
      await screen.shown(byName('shell-rail'));

      // 6g-0: what it needs; the panel stays until Next.
      await screen.atStep(0);
      await screen.stays(0);
      await screen.panelNext();

      // 6g-1: the wizard's first page.
      await screen.atStep(1);
      await screen.goTo('machines');
      await screen.click('machines-add');
      await screen.fill('machine-name', 'vm-drive');
      await choose(tester, 'machine-admin', 'machine-admin-yes');
      await choose(tester, 'machine-kind-choice', 'machine-new-user');
      await screen.fill('work-user-name', user);
      await screen.click('wizard-next');

      // 6g-2 to 6: root's key, then root logging in.
      await screen.atStep(2);
      await screen.click('existing-key');
      await screen.tap(find.text('porelo-vm-admin').last);
      await screen.click('use-key');
      await screen.atStep(3);
      await screen.click('setup-next');
      await screen.atStep(4);
      await screen.fill('new-host', '192.168.122.174');
      await screen.atStep(5);
      await screen.click('try-root-login');
      await screen.until(
        () => byName('host-key-accept').evaluate().isNotEmpty || screen.walk!.index == 6,
        'root to log in, or its host key to be shown',
        patience: const Duration(seconds: 60),
      );
      if (byName('host-key-accept').evaluate().isNotEmpty) await screen.tap(byName('host-key-accept'));
      await screen.atStep(6, patience: const Duration(seconds: 60));
      await screen.click('setup-next');

      // 6g-7 to 9: the setup script shown, then run as root.
      await screen.atStep(7);
      await screen.click('show-setup');
      await screen.atStep(8, patience: const Duration(minutes: 2));
      await screen.click('run-setup');
      await screen.atStep(9, patience: const Duration(minutes: 15));
      await screen.click('setup-next');

      // 6g-10, 11.
      await screen.atStep(10);
      await screen.click('finish-setup');
      await screen.atStep(11, patience: const Duration(minutes: 5));
      await screen.click('setup-next');

      // 6g-12, 13: the vault, its passphrase typed twice.
      await screen.atStep(12);
      await screen.click('open-vault-terminal');
      const passphrase = 'invented-walk-20-vault';
      await screen.until(() => screen.textOf('vault-terminal').contains('assphrase'), 'the vault to ask');
      await screen.typeInto('vault-terminal', passphrase);
      await screen.typeInto('vault-terminal', passphrase);
      await screen.atStep(13, patience: const Duration(minutes: 2));
      expect(screen.textOf('vault-terminal'), isNot(contains(passphrase)), reason: 'the passphrase is never shown');
      await screen.click('setup-next');

      // 6g-14: the drive offered, and Tresorit installed for the user; the sign-in is the person's.
      await screen.atStep(14);
      await screen.see(byName('drive-explained'));
      await screen.click('drive-install');
      await screen.atStep(15, patience: const Duration(minutes: 10));
      screen.noneLost(folder);
    } catch (error, stack) {
      debugPrint('Walk 20 failed at step ${screen.walk?.index}: $error\n$stack\n${screen.dump()}');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

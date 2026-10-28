import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:porelo_frontend/main.dart' as app;

import 'support/walk_screen.dart';

// Harm: a walk handed to a person that stalls, points at nothing, or asks for a value it never gives. Walk 19 is
// walked here as the person starts it, after walk 18: sprint5 with its last setup remembered, the secrets file there,
// the collection fetched. Nothing is rented: the walk is walked up to Put it on a server, which is not pressed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk 19 can be walked through its panel up to Put it on a server', (tester) async {
    final screen = WalkScreen(tester);
    final folder = givenByTheRunner('PORELO_WALK');
    final home = Platform.environment['HOME']!;
    const master = 'invented-walk-19-master';
    const scaleway = '5075079b-230c-41ea-8e71-1627ff0c8f08';
    const sha256 = '8ef7122ccb0f9ae34dee22c0ccf1e59b98734a4a1eb7eabaa7dd145992b72f9b';
    try {
      await _asAfterWalk18(home: home, folder: folder, master: master, scaleway: scaleway);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final interface = await app.porelo().timeout(deadline);
      screen.walk = interface.walk;
      await tester.pumpWidget(interface).timeout(deadline);
      await screen.shown(byName('shell-rail'));

      // 0-1: what it needs; the panel stays until Next.
      await screen.atStep(0);
      await screen.stays(0);
      await screen.panelNext();

      // 6e-1.
      await screen.atStep(1);
      await screen.goTo('projects');
      await screen.click('project sprint5');
      await screen.click('project-menu');
      await screen.click('project.server');

      // 6e-2: the values the step names, filled from the last setup.
      await screen.atStep(2);
      expect(tester.widget<TextField>(byName('host-scaleway-project')).controller?.text, scaleway);
      expect(tester.widget<TextField>(byName('host-account')).controller?.text, 'porelo');
      await screen.click('wizard-next');
      expect(
        tester.widget<TextField>(byName('host-signing-key')).controller?.text,
        givenByTheRunner('PORELO_WALK_SIGNING_KEY'),
      );
      await screen.see(byName('host-old-drive'));
      expect(byName('host-folder'), findsNothing, reason: 'no Tresorit folder is asked');
      expect(byName('host-tresor'), findsNothing, reason: 'no tresor name is asked');
      await screen.click('wizard-next');

      // 6e-3: the private key as remembered, its public half filled from its .pub.
      await screen.atStep(3);
      expect(tester.widget<TextField>(byName('host-identity')).controller?.text, '$home/.ssh/porelo-host');
      await screen.until(
        () => tester.widget<TextField>(byName('host-public-key')).controller?.text == '$home/.ssh/porelo-host.pub',
        'the public key filled from its .pub',
      );
      await screen.click('wizard-next');

      // 6e-4: the file from walk 18, opened with its master password once.
      await screen.atStep(4);
      expect(tester.widget<TextField>(byName('host-secrets-file')).controller?.text, '$home/Porelo/secrets.kdbx');
      await screen.see(find.text('It is there: setup opens it with its master password.'));
      expect(find.text('Open it now'), findsOneWidget);
      await screen.click('host-secrets-open');
      await screen.terminalSays('password');
      await screen.typeInTerminal(master);
      await screen.terminalSays('The secrets file is ready');
      expect(screen.terminalText, isNot(contains(master)), reason: 'the master password is never shown');
      await screen.click('unlock-done');
      await screen.see(find.text('Ready: the file keeps the server’s keys.'));
      await screen.atStep(5);
      await screen.click('wizard-next');

      // 6e-6, 7: the collection the step names; Check and start is reached, and Put it on a server is not pressed.
      await screen.atStep(6);
      await screen.fill('host-collection', '$home/.porelo/walk/porelo-host-0.5.7.tar.gz');
      await screen.fill('host-collection-sha256', sha256);
      await screen.atStep(7);
      await screen.click('wizard-next');
      await screen.see(byName('host-up'));
      expect(screen.pointer, 'host-up', reason: 'the ball is on Put it on a server');
      expect(tester.widget<ButtonStyleButton>(byName('host-up')).enabled, isTrue, reason: 'it could be put up');
      await screen.see(find.text('Scaleway project id: $scaleway'));
      expect(screen.walk!.index, 7, reason: 'the panel stays at 6e-7 until the server is put up');
      screen.noneLost(folder);
    } catch (error, stack) {
      debugPrint('Walk 19 failed at step ${screen.walk?.index}: $error\n$stack\n${screen.dump()}');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// The state walk 19 starts from: sprint5's last setup remembered, an ssh key pair, the secrets file of walk 18 and
/// the collection fetched, all in this run's own home.
Future<void> _asAfterWalk18({
  required String home,
  required String folder,
  required String master,
  required String scaleway,
}) async {
  final keys = Directory('$home/.ssh')..createSync(recursive: true);
  final made = await Process.run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-f', '${keys.path}/porelo-host']);
  expect(made.exitCode, 0, reason: '${made.stderr}');

  final settings = File('${Platform.environment['XDG_CONFIG_HOME']}/porelo/frontend.json');
  final stored = jsonDecode(settings.readAsStringSync()) as Map<String, dynamic>;
  // Shaped as the person's own record from an earlier setup: a drive folder and a VPN peer it once had.
  final drive = Directory('$home/Tresorit/PORELO_HOST')..createSync(recursive: true);
  stored['hostUps'] = {
    'sprint5': {
      'scalewayProject': scaleway,
      'account': 'porelo',
      'tresor': 'PORELO_HOST',
      'folder': drive.path,
      'signingKey': givenByTheRunner('PORELO_WALK_SIGNING_KEY'),
      'identity': '${keys.path}/porelo-host',
      'publicKey': '${keys.path}/porelo-host.pub',
      'collection': '',
      'vpnPeerPublicKey': 'aW52ZW50ZWQtd2Fsay0xOS1wZWVyLWtleS1ub3QtcmVhbA=',
      'vpnPeerAddress': '10.73.0.2/32',
    },
  };
  settings.writeAsStringSync(jsonEncode(stored));

  // The file walk 18 made, made here the same way: opened once with a new master password, twice on stdin.
  Directory('$home/Porelo').createSync(recursive: true);
  final create = await Process.start('/usr/bin/keepassxc-cli', ['db-create', '-p', '$home/Porelo/secrets.kdbx']);
  create.stdin
    ..writeln(master)
    ..writeln(master);
  await create.stdin.close();
  final (out, err) = await (
    create.stdout.transform(utf8.decoder).join(),
    create.stderr.transform(utf8.decoder).join(),
  ).wait;
  expect(await create.exitCode, 0, reason: '$out$err');

  final fetched = await Process.run('tool/fetch_collection.sh', [
    '0.5.7',
    '8ef7122ccb0f9ae34dee22c0ccf1e59b98734a4a1eb7eabaa7dd145992b72f9b',
    '$home/.porelo/walk',
  ]);
  expect(fetched.exitCode, 0, reason: '${fetched.stderr}');
}

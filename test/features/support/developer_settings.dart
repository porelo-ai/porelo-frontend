import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_frontend/src/ui/project_developers_dialog.dart';

import 'world.dart';

const developerSsh = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
final developerWg = base64Encode(List.filled(32, 1));
final developerBlock = 'ssh_public_key: "$developerSsh laptop-comment"\nwireguard_public_key: "$developerWg"\n';

class DeveloperSettingsFixture extends ProjectDevelopers {
  DeveloperSettingsFixture()
    : super(
        access: AccessCheckout(
          root: '/unused',
          project: 'demo',
          repository: 'https://example.org/team/access.git',
          signingKey: File('/unused/signer.pub'),
        ),
        forge: null,
        repository: 'team/access',
        sync: (_, _, {String? bundle}) => throw StateError('No host call before review.'),
      ) {
    listed = parseAccessDevelopers('''host: {network: 10.77.0.0/24, ssh_host_key: "$developerSsh"}
developers:
  alice:
    forge_login: alice-login
    laptops:
      - ssh_public_key: "$developerSsh"
        wireguard_public_key: "$developerWg"
        vpn_address: 10.77.0.2
''');
  }
  final removals = <String>[];
  final additions = <AccessDeveloper>[];
  @override
  Future<void> remove(String account) async => removals.add(account);
  @override
  Future<void> addDeveloper(AccessDeveloper developer) async => additions.add(developer);
}

late DeveloperSettingsFixture developerSettings;

Future<void> openDeveloperFixture(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  developerSettings = DeveloperSettingsFixture();
  addTearDown(developerSettings.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ProjectDevelopersDialog(developers: developerSettings)),
    ),
  );
  await World.settle(tester);
}

Future<void> developerTap(WidgetTester tester, Finder target) async {
  await World.settle(tester);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await World.settle(tester);
}

Future<void> developerLaptopStep(WidgetTester tester) async {
  await developerTap(tester, find.byKey(const Key('developers.add')));
  await tester.enterText(find.byKey(const Key('developer-account')), 'developer');
  await developerTap(tester, find.byKey(const Key('wizard-next')));
  await tester.enterText(find.byKey(const Key('developer-forge-login')), 'dev-login');
  await developerTap(tester, find.byKey(const Key('wizard-next')));
}

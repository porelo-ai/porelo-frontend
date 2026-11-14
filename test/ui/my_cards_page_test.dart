import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/identity.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/step/i_open_the_command_finder.dart';
import '../features/step/i_pick_in_the_finder.dart';
import '../features/support/world.dart';

/// The person's key and card as Core shows them: one key the agent holds, filed in one organization.
const _card = {
  'login': 'rowan-example',
  'name': 'Rowan Example',
  'email': null,
  'fingerprint': 'SHA256:CardOnThePageCardOnThePageCardOnThePage',
  'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPageKey',
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "rowan-example"\n',
  'agent': 'holds',
  'agent_holds_key': true,
  'revoked': false,
  'card_refused': null,
  'organization': <Object?>[],
  'forge': null,
  'pending': <Object?>[],
};

/// The window with an identity whose Core shows [_card] and refuses everything else.
Future<void> _start(WidgetTester tester) async {
  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async => arguments[1] == 'show' ? (code: 0, out: jsonEncode(_card), err: '') : (code: 70, out: '', err: '');
  await World.startBackend(World.work);
  await World.startApp(tester, identity: IdentityModel(Identity(run: run)));
}

void main() {
  // Harm: My cards & keys opens an empty page and shows the person's key in a dialog over it, which hides the page it
  // is about and is gone once closed (seen live).
  testWidgets('My cards & keys shows the key and card in its own body, opening no dialog', (tester) async {
    await _start(tester);
    await tester.tap(find.byKey(const ValueKey('rail cards')));
    await World.settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('SHA256:CardOnThePageCardOnThePageCardOnThePage'), findsOneWidget);
    expect(find.textContaining('Rowan Example'), findsOneWidget);
    expect(find.text('Your SSH agent holds this key.'), findsOneWidget);
    expect(find.text('Change my key…'), findsOneWidget);
  });

  // Harm: the title bar's way to the key opens a dialog over whatever page is open, not the page about it.
  testWidgets("the title bar's My key and card opens the page", (tester) async {
    await _start(tester);
    await World.tapInView(tester, 'options-menu');
    await tester.tap(find.text('My key and card…').last);
    await World.settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(World.shell.section, Section.cards);
    expect(find.text('SHA256:CardOnThePageCardOnThePageCardOnThePage'), findsOneWidget);
  });

  // Harm: the finder's way to the key opens a dialog over whatever page is open, or nothing, not the page about it.
  testWidgets("the finder's My key and card opens the page, and no dialog stays", (tester) async {
    await _start(tester);
    await iOpenTheCommandFinder(tester);
    await iPickInTheFinder(tester, 'My key and card…');
    expect(find.byType(Dialog), findsNothing);
    expect(World.shell.section, Section.cards);
    expect(find.text('SHA256:CardOnThePageCardOnThePageCardOnThePage'), findsOneWidget);
  });
}

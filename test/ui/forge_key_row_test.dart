import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/forge_key_check.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/ui/forges_page.dart';

import '../features/support/world.dart';
import '../support/forge_key_check.dart';

ForgeKeyAnswered _answered(ForgeKeyListed listed, {String? cardProblem}) => ForgeKeyAnswered(
  forge: ForgeKeyState(
    login: 'alice',
    listed: listed,
    keysUrl: Uri.parse('https://forge.example.org/alice.keys'),
    accountUrl: Uri.parse('https://forge.example.org/settings/keys'),
  ),
  cardProblem: cardProblem,
);

Future<void> _forgesPage(WidgetTester tester, ForgeKeyCheck check) async {
  tester.view
    ..physicalSize = const Size(1280, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final forges = ForgeConnection(MemoryForgeTokens());
  addTearDown(forges.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ForgesPage(forges: forges, usedBy: (_) => [], onOpen: (_) {}, keyCheck: check),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _subtitle(WidgetTester tester, String key) =>
    (tester.widget<ListTile>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(ListTile))).subtitle!
            as Text)
        .data!;

void main() {
  // Harm: a listing nobody could ask would tell the person their key is on the forge.
  testWidgets('a key listing that could not be asked shows no good check', (tester) async {
    await _forgesPage(tester, FakeForgeKeyCheck(_answered(ForgeKeyListed.unknown)));
    expect(find.byKey(const Key('forge-key-listed')), findsNothing);
    expect(_subtitle(tester, 'forge-key-check'), contains('could not be asked'));
  });

  // Harm: an unknown answer from Core must not read as a listed key.
  testWidgets('an unreadable identity answer shows no good check', (tester) async {
    await _forgesPage(tester, FakeForgeKeyCheck(const ForgeKeyUnavailable('Core answered in an unknown form.')));
    expect(find.byKey(const Key('forge-key-listed')), findsNothing);
    expect(_subtitle(tester, 'forge-key-check'), contains('not known'));
  });

  // Harm: a revoked card or no card at all must not show the forge check as good.
  testWidgets('a revoked card or no identity shows no good check', (tester) async {
    final check = FakeForgeKeyCheck(_answered(ForgeKeyListed.listed, cardProblem: 'Your key is revoked.'));
    await _forgesPage(tester, check);
    expect(find.byKey(const Key('forge-key-listed')), findsNothing);
    expect(_subtitle(tester, 'forge-key-check'), contains('revoked'));
    check.reading = const ForgeKeyNoIdentity('No card is kept here.');
    await World.tapInView(tester, 'forge-key-menu');
    await World.tapInView(tester, 'forge.keyCheck');
    expect(check.reads, 2);
    expect(find.byKey(const Key('forge-key-listed')), findsNothing);
    expect(_subtitle(tester, 'forge-key-check'), contains('No card is kept here.'));
  });

  // Harm: a listed key on a good card must say so, and adding a key must open the forge's own account page.
  testWidgets('a listed key shows as listed and the menu opens the account page', (tester) async {
    final opened = <Uri>[];
    final previous = openLink;
    openLink = (address) async => opened.add(address);
    addTearDown(() => openLink = previous);
    await _forgesPage(tester, FakeForgeKeyCheck(_answered(ForgeKeyListed.listed)));
    expect(find.byKey(const Key('forge-key-listed')), findsOneWidget);
    await World.tapInView(tester, 'forge-key-menu');
    await World.tapInView(tester, 'forge.keyAdd');
    await World.tapInView(tester, 'forge-key-menu');
    await World.tapInView(tester, 'forge.keyList');
    expect(opened, [
      Uri.parse('https://forge.example.org/settings/keys'),
      Uri.parse('https://forge.example.org/alice.keys'),
    ]);
  });
}

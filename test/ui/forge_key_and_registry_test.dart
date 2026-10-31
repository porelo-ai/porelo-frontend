import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/forge_key_check.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';
import 'package:porelo_frontend/src/ui/forges_page.dart';

import '../features/support/world.dart';
import '../support/forge_key_check.dart';
import '../support/registry_page_source.dart';

const _registry = 'https://forge.example.org/acme/registry';

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

Future<void> _forgePage(WidgetTester tester, RegistryPages? registry) async {
  tester.view
    ..physicalSize = const Size(1280, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final forges = ForgeConnection(MemoryForgeTokens());
  addTearDown(forges.dispose);
  await forges.addIdentity(name: 'Central', address: 'forge.example.org');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ForgePage(forges: forges, usedBy: (_) => [], usedOn: (_) => [], registry: registry),
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

  // Harm: without a chosen registry, no row may suggest a verified registry state.
  testWidgets('no chosen registry shows no registry row', (tester) async {
    await _forgePage(tester, RegistryPages());
    expect(find.byKey(const Key('forge-registry-chosen')), findsNothing);
    expect(find.text('Verified registry state has not been supplied.'), findsOneWidget);
  });

  // Harm: a chosen registry not yet read must not show counts as if verified.
  testWidgets('a chosen registry not read yet shows no verified counts', (tester) async {
    final source = FakeRegistryPageSource(const RegistryPageSnapshot())..failRead = true;
    final registry = RegistryPages(source: source, address: () => _registry);
    addTearDown(registry.dispose);
    await _forgePage(tester, registry);
    expect(_subtitle(tester, 'forge-registry-chosen'), contains('Not read yet'));
    expect(_subtitle(tester, 'forge-registry-chosen'), isNot(contains('persons')));
  });

  // Harm: the chosen registry's row must show its read persons and hosts and Refresh must read again.
  testWidgets('the chosen registry row shows persons and hosts and refreshes', (tester) async {
    const machine = Machine(name: 'first', socketPath: '/first');
    final source = FakeRegistryPageSource(
      const RegistryPageSnapshot(
        items: [
          RegistryPageItem(
            target: (registry: _registry, host: 'h1', project: null),
            machine: machine,
            role: '',
            state: 'admitted',
            revision: 'r1',
          ),
        ],
        people: [
          RegistryPerson(login: 'alice', name: 'Alice'),
          RegistryPerson(login: 'bob', name: 'Bob'),
        ],
      ),
    );
    final registry = RegistryPages(
      source: source,
      address: () => _registry,
      features: const RegistryPageFeatures(operations: {RegistryOperation.refresh}),
    );
    addTearDown(registry.dispose);
    await _forgePage(tester, registry);
    await World.tapInView(tester, 'forge-registry-chosen-menu');
    await World.tapInView(tester, 'registry.refresh');
    expect(registry.loaded, isTrue);
    expect(_subtitle(tester, 'forge-registry-chosen'), '2 persons · hosts h1');
  });
}

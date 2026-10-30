import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/ui/forges_page.dart';
import 'package:porelo_frontend/src/ui/forges_view.dart';

import '../features/support/world.dart';

class _IdentityForge extends FakeForge {
  bool failRead = false;
  @override
  Future<ForgeAccount> whoAmI() async => const ForgeAccount('alice');
  @override
  Future<List<ForgeRepository>> repositories() async {
    if (failRead) throw const ForgeRefused('The forge cannot be read.');
    return super.repositories();
  }
}

const _repository = ForgeRepository(
  fullName: 'acme/api',
  sshUrl: 'git@forge.example.org:acme/api.git',
  httpsUrl: 'https://forge.example.org/acme/api.git',
  defaultBranch: 'main',
  admin: true,
  push: true,
  private: true,
);

void main() {
  late OpenLink previousOpenLink;
  setUp(() => previousOpenLink = openLink);
  tearDown(() => openLink = previousOpenLink);
  // Harm: equal repository names on loopback ports must not navigate to another host's project.
  test('host forge matching keeps the tunnel port in repository identity', () {
    final entry = ForgeEntry(
      id: 'host/first',
      kind: 'forgejo',
      name: 'First',
      address: 'public.example.org',
      hostMachine: 'first',
      tunnelAddress: Uri.parse('http://127.0.0.1:3001/'),
      gitAddress: Uri.parse('http://127.0.0.1:4001/'),
    );
    expect(forgeHoldsUrl(entry, 'http://127.0.0.1:3001/acme/api.git'), isTrue);
    expect(forgeHoldsUrl(entry, 'http://127.0.0.1:3002/acme/api.git'), isFalse);
    expect(forgeHoldsUrl(entry, 'http://127.0.0.1:4001/acme/api.git'), isTrue);
    expect(forgeHoldsUrl(entry, 'http://127.0.0.1:4002/acme/api.git'), isFalse);
    expect(forgeHoldsUrl(entry, 'https://127.0.0.1:3001/acme/api.git'), isFalse);
  });

  // Harm: matching owner/repository names on another forge must not open the wrong project.
  testWidgets('a repository menu does not offer a project followed from another forge', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({
        'name': 'checkout',
        'file': '/srv/checkout/project.yml',
        'following': {'url': 'git@other.example.org:acme/api.git'},
      }),
    ];
    await World.startApp(tester);
    World.forges.current = const ForgeEntry(
      id: 'central',
      kind: 'github',
      name: 'Central',
      address: 'forge.example.org',
    );
    World.forges.account = const ForgeAccount('alice');
    World.forges.repositories = [_repository];
    World.shell.goTo(Section.forge);
    await World.settle(tester);
    await World.tapInView(tester, 'forge-repository-menu acme/api');
    expect(find.byKey(const Key('repository.project')), findsNothing);
  });

  // Harm: starting work must not remove a repository that is already in default.
  testWidgets('working without a project preserves an already listed repository', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final forge = _IdentityForge()..repositoriesHere.add(_repository);
    final backend = FakeBackend([])
      ..inDefault = [DefaultRepository(name: 'api', upstream: _repository.httpsUrl, checkout: '', claimedBy: '')];
    addTearDown(backend.stop);
    final forges = ForgeConnection(MemoryForgeTokens(), identityAccess: (_) async => forge);
    addTearDown(forges.dispose);
    await forges.addIdentity(name: 'Central', address: 'forge.example.org');
    final starts = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgePage(
            forges: forges,
            usedBy: (_) => [],
            usedOn: (_) => [],
            machine: backend,
            inDefault: (_) => true,
            onStartWork: (project) async {
              starts.add(project);
            },
          ),
        ),
      ),
    );
    await World.settle(tester);
    await World.tapInView(tester, 'forge-repository-menu acme/api');
    await World.tapInView(tester, 'repository.default');
    expect(backend.inDefault.map((repository) => repository.name), ['api']);
    expect(starts, ['default']);
  });

  // Harm: a delayed access response must not re-enable an endpoint after tunnel loss.
  test('a delayed host access result cannot restore a withdrawn tunnel', () async {
    final answer = Completer<Forge>();
    final forges = ForgeConnection(MemoryForgeTokens(), identityAccess: (_) => answer.future);
    addTearDown(forges.dispose);
    final entry = ForgeEntry(
      id: 'host/first',
      kind: 'forgejo',
      name: 'First',
      address: 'public.example.org',
      hostMachine: 'first',
      tunnelAddress: Uri.parse('http://first.localhost:3001/'),
    );
    forges.setHostEntries([entry]);
    final checking = forges.choose(entry);
    forges.setHostEntries([]);
    answer.complete(_IdentityForge());
    await checking;
    expect(forges.current?.browserAddress, isNull);
    expect(forges.connected, isFalse);
  });

  // Harm: a lost tunnel leaves an old endpoint that a different local process can take over.
  test('a host forge loses its old browser endpoint when its tunnel is withdrawn', () async {
    final forge = _IdentityForge();
    final forges = ForgeConnection(MemoryForgeTokens(), identityAccess: (_) async => forge);
    addTearDown(forges.dispose);
    final entry = ForgeEntry(
      id: 'host/first',
      kind: 'forgejo',
      name: 'First',
      address: 'public.example.org',
      hostMachine: 'first',
      tunnelAddress: Uri.parse('http://first.localhost:3001/'),
    );
    forges.setHostEntries([entry]);
    await forges.choose(entry);
    expect(forges.current!.browserAddress, entry.tunnelAddress);
    forges.setHostEntries([]);
    expect(forges.current?.browserAddress, isNull);
    expect(forges.connected, isFalse);
  });

  // Harm: merely opening a forge must not solicit or transport a token.
  testWidgets('opening a forge defaults to identity and leaves token entry to its explicit menu', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final terminals = <List<String>>[];
    final forges = ForgeConnection(
      MemoryForgeTokens(),
      openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
        terminals.add([executable, ...arguments]);
        return FakeTerminal([]);
      },
    );
    addTearDown(forges.dispose);
    final entry = await forges.addIdentity(name: 'Central', address: 'forge.example.org');
    expect(entry!.authentication, 'ssh');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgePage(forges: forges, usedBy: (_) => [], usedOn: (_) => []),
        ),
      ),
    );
    await World.settle(tester);
    expect(find.byType(ForgeForm), findsNothing);
    expect(terminals, isEmpty);
    await World.tapInView(tester, 'forges-menu Central');
    await World.tapInView(tester, 'forge.useToken');
    await World.tapInView(tester, 'forge-connect');
    expect(terminals, [
      [poreloHost(), 'key', 'set', 'forge.example.org'],
    ]);
    expect(
      find.byWidgetPredicate((widget) => widget is TextField && widget.obscureText),
      findsNothing,
      reason: 'the terminal takes the token instead of a secret field',
    );
    await tester.pumpWidget(const SizedBox());
  });

  // Harm: opening a host forge at its public address bypasses the SSH tunnel.
  testWidgets('a host forge browser operation uses only its confirmed tunnel address', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previous = desk;
    final opened = <List<String>>[];
    desk = Desk.of(
      'linux',
      const {},
      startDetached: (program, arguments) async {
        opened.add([program, ...arguments]);
      },
    );
    addTearDown(() => desk = previous);
    final entry = ForgeEntry(
      id: 'host/first',
      kind: 'forgejo',
      name: 'First forge',
      address: 'public.example.org',
      hostMachine: 'first',
      tunnelAddress: Uri.parse('http://first.localhost:3001/'),
    );
    final forges = ForgeConnection(MemoryForgeTokens())..setHostEntries([entry]);
    addTearDown(forges.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgesPage(forges: forges, usedBy: (_) => [], onOpen: (_) {}),
        ),
      ),
    );
    await World.settle(tester);
    await World.tapInView(tester, 'forges-menu First forge');
    await World.tapInView(tester, 'forge.browser');
    expect(opened, [
      ['xdg-open', 'http://first.localhost:3001/'],
    ]);
    for (final address in [
      'http://remote.example.org:3001/',
      'http://person@first.localhost:3001/',
      'http://first.localhost:3001/?credential=value',
      'https://first.localhost:3001/',
    ]) {
      expect(
        ForgeEntry(
          id: 'host/first',
          kind: 'forgejo',
          name: 'First',
          address: 'public.example.org',
          hostMachine: 'first',
          tunnelAddress: Uri.parse(address),
        ).browserAddress,
        isNull,
      );
    }
  });

  // Harm: failed access checks must not erase the last verified repositories.
  test('a failed identity refresh retains the last confirmed repository list', () async {
    final forge = _IdentityForge()..repositoriesHere.add(_repository);
    final forges = ForgeConnection(MemoryForgeTokens(), identityAccess: (_) async => forge);
    addTearDown(forges.dispose);
    await forges.addIdentity(name: 'Central', address: 'forge.example.org');
    expect(forges.repositories!.map((repository) => repository.fullName), ['acme/api']);
    forge.failRead = true;
    await forges.refresh();
    expect(forges.repositories!.map((repository) => repository.fullName), ['acme/api']);
    expect(forges.problem, isNotNull);
  });
}

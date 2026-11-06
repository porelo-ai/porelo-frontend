import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
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

/// A token declared on the machine for the organization's address and kept in its vault, as `Credentials` answers it.
const _declared = Connection(
  id: 'git.token.github.com',
  kind: 'TOKEN',
  match: 'https://github.com/porelo-ai/',
  purpose: 'git',
  source: 'VAULT',
  present: true,
);

void main() {
  // Harm: a person who set up by the command line is told the machine holds nothing, and to paste a token again.
  group('what the machine already holds', () {
    test('a forge declared on the machine is listed once, beside one set up here for the same host', () {
      const setUp = ForgeEntry(id: 'github.com', kind: 'github', name: 'GitHub', address: 'github.com');
      const registry = Connection(
        id: 'registry.token',
        kind: 'TOKEN',
        match: 'https://ghcr.io/',
        purpose: 'registry',
        source: 'VAULT',
      );
      final alone = listedForges(const [], const [_declared, registry]);
      String ids(ListedForge forge) => [for (final held in forge.held) held.id].join(' ');
      expect([for (final each in alone) (each.address, each.entry, ids(each))], [('github.com', null, _declared.id)]);
      final both = listedForges(const [setUp], const [_declared, registry]);
      expect(
        [for (final each in both) (each.address, each.entry?.id, ids(each))],
        [('github.com', 'github.com', _declared.id)],
      );
    });

    testWidgets('My forges says where it comes from, marks the organization, and asks for no token', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final forges = ForgeConnection(MemoryForgeTokens());
      addTearDown(forges.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgesPage(
              forges: forges,
              usedBy: (_) => [],
              onOpen: (_) {},
              held: const [_declared],
              heldOn: 'build',
              organizationForge: 'github.com',
            ),
          ),
        ),
      );
      await World.settle(tester);
      final row = find.byKey(const ValueKey('forges-row held github.com'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.textContaining('declared on build: a token in the vault as git.token')),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: find.textContaining("organization's forge")), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byType(CommandMenu)),
        findsNothing,
        reason: 'nothing to sign in',
      );
    });
  });

  // Harm: right after creating a Porelo organization on GitHub, *My forges* said 0 and asked for the token again.
  group('creating a Porelo organization lists its forge', () {
    ForgeConnection forges(ForgeTokens tokens) {
      final made = ForgeConnection(tokens);
      addTearDown(made.dispose);
      return made;
    }

    test('from the address of its repository, in either form, once', () async {
      for (final address in ['git@forge.example.org:acme/org.git', 'https://forge.example.org/acme/org.git']) {
        final each = forges(MemoryForgeTokens());
        await each.enterForgeOf(address);
        await each.enterForgeOf(address);
        expect([for (final entry in each.entries) entry.address], ['forge.example.org']);
      }
    });

    test('and leaves open the forge the person has open', () async {
      final tokens = MemoryForgeTokens();
      final each = ForgeConnection(tokens, identityAccess: (_) async => throw const ForgeRefused('no'));
      addTearDown(each.dispose);
      final open = await each.addIdentity(name: 'Mine', address: 'mine.example.org');
      await each.enterForgeOf('git@forge.example.org:acme/org.git');
      expect(each.current?.id, open?.id);
      expect(each.entries, hasLength(2));
    });

    test('and says why where no token is kept here, asking for nothing', () async {
      final each = forges(MemoryForgeTokens());
      await each.enterForgeOf('git@forge.example.org:acme/org.git');
      expect(each.entries, hasLength(1));
      expect(each.problem, isNotNull);
    });
  });

  group('a forge\'s token in the machine\'s vault', () {
    Future<List<List<String>>> pump(WidgetTester tester, String address, {ForgeTokenVault? vault}) async {
      tester.view
        ..physicalSize = const Size(1280, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final terminals = <List<String>>[];
      final forges = ForgeConnection(MemoryForgeTokens());
      addTearDown(forges.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => forgeMenu(
                context,
                forges,
                ForgeEntry(id: 'f', kind: 'github', name: 'Central', address: address),
                (_) => [],
                said: (_) {},
                tokenVault:
                    vault ??
                    ForgeTokenVault(
                      machine: Machine.local(),
                      answers: true,
                      open: (executable, arguments, {int columns = 80, int rows = 24}) {
                        terminals.add([executable, ...arguments]);
                        return FakeTerminal([]);
                      },
                    ),
              ),
            ),
          ),
        ),
      );
      await World.settle(tester);
      await World.tapInView(tester, 'forges-menu Central');
      return terminals;
    }

    PopupMenuItem<String> item(WidgetTester tester) =>
        tester.widget<PopupMenuItem<String>>(find.byKey(const ValueKey<String>('forge.storeToken')));

    // Harm: the token entered in a form of this interface, or stored under a name no Git transfer finds.
    testWidgets('is typed in a terminal on the machine, under the forge\'s own entry', (tester) async {
      final terminals = await pump(tester, 'Forge.Example.org');
      await World.tapInView(tester, 'forge.storeToken');
      expect(terminals, [
        ['porelo', 'vault', 'put', 'git.token.forge.example.org'],
      ]);
      expect(find.byType(TextField), findsNothing);
    });

    // Harm: a hostile address becomes an option of the command, or names another forge's entry.
    for (final hostile in [
      '--help',
      '--help.example.org',
      '-x.example.org',
      'forge.example.org other.example.org',
      'forge.example.org/../other',
      'forge.example.org\nother',
      'forge.example.org:3000',
      'user@forge.example.org',
      'forge.example.org;reboot',
      r'$(reboot).example.org',
      '',
      'nodots',
    ]) {
      testWidgets('the address "$hostile" names no entry and no command', (tester) async {
        final terminals = await pump(tester, hostile);
        expect(item(tester).enabled, isFalse);
        expect(find.textContaining('no plain server name'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey<String>('forge.storeToken')), warnIfMissed: false);
        await World.settle(tester);
        expect(terminals, isEmpty);
      });
    }

    testWidgets('says why when the selected machine does not answer', (tester) async {
      await pump(tester, 'forge.example.org', vault: ForgeTokenVault(machine: Machine.local(), answers: false));
      expect(item(tester).enabled, isFalse);
      expect(find.textContaining('does not answer'), findsOneWidget);
    });
  });

  // Harm: a removed menu entry strands a repository in default with no way to stop working on it.
  testWidgets('the repository menu removes work in the Default project and preserves other repositories', (
    tester,
  ) async {
    await World.startBackend(World.work);
    World.backend.inDefault = [
      const DefaultRepository(
        name: 'api',
        upstream: 'https://forge.example.org/acme/api.git',
        checkout: '',
        claimedBy: '',
      ),
      const DefaultRepository(
        name: 'other',
        upstream: 'https://forge.example.org/acme/other.git',
        checkout: '',
        claimedBy: '',
      ),
    ];
    World.backend.theProjectsItHas.add(
      Project.from({
        'name': defaultProject,
        'repositories': [
          {'name': 'api', 'upstream': 'https://forge.example.org/acme/api.git'},
          {'name': 'other', 'upstream': 'https://forge.example.org/acme/other.git'},
        ],
      }),
    );
    await World.startApp(tester);
    await World.forgeTokens.write('forge.example.org', World.forge.accepts);
    World.forge.repositoriesHere.add(_repository);
    await World.forges.add(name: 'Central', address: 'forge.example.org');
    World.shell.goTo(Section.forge);
    await World.settle(tester);
    await World.tapInView(tester, 'forge-repository-menu acme/api');
    await World.tapInView(tester, 'repository.defaultRemove');
    expect(World.backend.inDefault.map((repository) => repository.name), ['other']);
  });

  // Harm: hiding trusted-machine tools prevents removal of obsolete message-signing access.
  testWidgets('the repository menu opens its trusted-machine tools', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.forgeTokens.write('forge.example.org', World.forge.accepts);
    World.forge.repositoriesHere.add(_repository);
    await World.forges.add(name: 'Central', address: 'forge.example.org');
    World.shell.goTo(Section.forge);
    await World.settle(tester);
    await World.tapInView(tester, 'forge-repository-menu acme/api');
    await World.tapInView(tester, 'repository.tools');
    expect(find.byKey(const Key('project-forge-dialog')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // Harm: renaming a forge must not replace its SSH authentication or create a second connection.
  testWidgets('renaming an identity forge preserves its connection without opening a token terminal', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final terminals = <List<String>>[];
    final forge = _IdentityForge();
    final forges = ForgeConnection(
      MemoryForgeTokens(),
      identityAccess: (_) async => forge,
      openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
        terminals.add([executable, ...arguments]);
        return FakeTerminal([]);
      },
    );
    addTearDown(forges.dispose);
    final entry = await forges.addIdentity(name: 'Central', address: 'forge.example.org');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgePage(forges: forges, usedBy: (_) => [], usedOn: (_) => []),
        ),
      ),
    );
    await World.settle(tester);
    await World.tapInView(tester, 'forges-menu Central');
    await World.tapInView(tester, 'forge.rename');
    await tester.enterText(find.byKey(const Key('forge-name')), 'Work');
    await World.tapInView(tester, 'forge-connect');
    expect(forges.entries.map((each) => (each.id, each.name, each.authentication)), [(entry!.id, 'Work', 'ssh')]);
    expect(forges.connected, isTrue);
    expect(terminals, isEmpty);
  });

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
  testWidgets('a repository menu does not offer a project on another forge', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({
        'name': 'checkout',
        'file': '/srv/checkout/project.yml',
        'repositories': [
          {'name': 'checkout', 'own': true, 'upstream': 'git@other.example.org:acme/api.git'},
        ],
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
  testWidgets('working in the Default project preserves an already listed repository', (tester) async {
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

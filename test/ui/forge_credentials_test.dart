import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/ui/binding_view.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/machine_binding.dart';
import 'package:porelo_frontend/src/app/machine_clearing.dart';
import 'package:porelo_frontend/src/ui/forges_view.dart';

import '../features/support/world.dart';

const repository = ForgeRepository(
  fullName: 'acme/api',
  sshUrl: 'git@github.com:acme/api.git',
  httpsUrl: 'https://github.com/acme/api.git',
  defaultBranch: 'main',
  admin: false,
  push: true,
  private: true,
);

Future<void> _connectToAddress(WidgetTester tester, String address) async {
  final field = find.byKey(const Key('forge-address'));
  await tester.enterText(field, address);
  expect(
    tester.widget<TextField>(field).controller!.text,
    address,
    reason: 'the validation case must reach the form without input normalization',
  );
  final connect = find.byKey(const Key('forge-connect'));
  await tester.ensureVisible(connect);
  await tester.tap(connect);
  await World.settle(tester);
}

void main() {
  // Harm: a token in a form can enter widget state, captures and diagnostics.
  testWidgets('connecting and changing a forge offer no token field', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final forges = ForgeConnection(MemoryForgeTokens());
    addTearDown(forges.dispose);
    for (final editing in <ForgeEntry?>[
      null,
      const ForgeEntry(id: 'github.com', kind: 'github', name: 'GitHub', address: 'github.com'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeForm(forges: forges, editing: editing, onDone: (_) {}),
          ),
        ),
      );
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(editing == null ? 2 : 1), reason: 'only the public name and address belong in the form');
      expect(
        fields.any((each) => each.obscureText),
        isFalse,
        reason: 'a secret must be entered only at the terminal prompt',
      );
    }
  });

  for (final address in [
    'https://github.com',
    'github.com/path',
    'github.com;id',
    '-github.com',
    // A line break cannot reach this single-line field; forgeAddress refuses it (porelo_host's forge_key_test).
    'user@github.com',
    'github.com:443',
    r'$(id).com',
  ]) {
    // Harm: a forge address must not select another command or credential entry.
    testWidgets('invalid forge address ${address.codeUnits} opens no terminal', (tester) async {
      final commands = <List<String>>[];
      final terminals = <FakeTerminal>[];
      final forges = ForgeConnection(
        MemoryForgeTokens(),
        openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
          commands.add([executable, ...arguments]);
          final terminal = FakeTerminal([]);
          terminals.add(terminal);
          return terminal;
        },
      );
      addTearDown(forges.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeForm(useToken: true, forges: forges, onDone: (_) {}),
          ),
        ),
      );
      await _connectToAddress(tester, 'Git.Example.org');
      final validCommand = <String>[poreloHost(), 'key', 'set', 'git.example.org'];
      expect(commands, <List<String>>[validCommand], reason: 'the positive control must reach the injected terminal');
      expect(find.byKey(const Key('unlock-terminal')), findsOneWidget);
      expect(find.byKey(const Key('forge-form-problem')), findsNothing);
      // An unsuccessful exit returns to the form without reading or saving a token.
      terminals.single.endsWith(1);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('unlock-done')));
      await World.settle(tester);
      expect(find.byKey(const Key('unlock-terminal')), findsNothing);

      await _connectToAddress(tester, address);
      expect(commands, <List<String>>[validCommand], reason: 'the invalid address must start no additional process');
      expect(terminals, hasLength(1), reason: 'only the valid positive control may open a terminal');
      expect(find.byKey(const Key('unlock-terminal')), findsNothing);
      expect(find.byKey(const Key('forge-form-problem')), findsOneWidget);
    });
  }

  // Harm: a UI must not pipe a token to a process or use a shell to interpret its address.
  testWidgets('connecting opens the local helper with one host argument and waits for the store', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final commands = <List<String>>[];
    final terminal = FakeTerminal([]);
    final tokens = MemoryForgeTokens();
    final forge = FakeForge();
    final forges = ForgeConnection(
      tokens,
      forgeFor: (_, _) => forge,
      openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
        commands.add([executable, ...arguments]);
        return terminal;
      },
    );
    addTearDown(forges.dispose);
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeForm(useToken: true, forges: forges, onDone: (_) => saved = true),
        ),
      ),
    );
    await _connectToAddress(tester, 'Git.Example.org');
    expect(commands.single, [poreloHost(), 'key', 'set', 'git.example.org']);
    expect(terminal.typed, isEmpty, reason: 'the interface sends no secret to the prompt');
    expect(saved, isFalse);
    terminal.endsWith(0);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-done')));
    await World.settle(tester);
    expect(saved, isFalse, reason: 'exit zero cannot replace checking the stored entry');
    expect(forges.entries, isEmpty);
  });

  // Harm: binding must not grant separate repository access through deploy keys.
  test('binding and unbinding leave forge keys alone', () async {
    final backend = FakeBackend([]);
    await backend.open();
    backend.theStoreIs = const VaultState(
      vault: '',
      exists: true,
      readable: true,
      credentials: [Credential(name: 'git.token.github.com', type: 'api-key', characters: 12)],
    );
    final forge = FakeForge()..repositoriesHere.add(repository);
    final workspace = FakeWorkspace()
      ..repository = repository
      ..onTheForge =
          'project:\n  name: api\nrepositories:\n  backend:\n    upstream: https://github.com/acme/backend.git\n';
    final binding = MachineBinding(forge, workspace, backend, machineName: 'vm', login: 'alice');
    addTearDown(binding.dispose);
    await binding.bind(workspace.agentKeys.single);
    expect(binding.problem, isNull);
    expect(binding.bound, 'api');
    expect(backend.deployKeysMade, isEmpty, reason: 'binding must never ask the daemon for a deploy key');
    expect(forge.keysOf, isEmpty, reason: 'binding must never register a deploy key');
    await binding.remove(workspace.agentKeys.single);
    expect(binding.problem, isNull);
    expect(binding.bound, isNull);
    expect(forge.keyCalls, isEmpty, reason: 'no deploy-key read, check, creation or removal may run');
  });

  // Harm: binding must not send a secret over the socket or follow before the vault confirms it.
  testWidgets('binding prompts on the chosen machine and confirms the entry by name', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend([])
      ..theStoreIs = const VaultState(vault: '', exists: true, readable: true, credentials: []);
    final forge = FakeForge()..repositoriesHere.add(repository);
    final workspace = FakeWorkspace()
      ..repository = repository
      ..onTheForge = 'project:\n  name: api\n';
    final binding = MachineBinding(forge, workspace, backend, machineName: 'runner', login: 'alice');
    addTearDown(binding.dispose);
    const machine = Machine(
      name: 'runner',
      socketPath: '/forwarded',
      host: 'person@runner.example.org',
      remoteSocket: '/run/user/1000/porelo.sock',
    );
    final terminal = FakeTerminal([]);
    final commands = <List<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BindingDialog(
            binding: binding,
            terminalMachine: machine,
            openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
              commands.add([executable, ...arguments]);
              return terminal;
            },
          ),
        ),
      ),
    );
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('binding-bind')));
    await World.settle(tester);
    expect(commands.single.skip(1), [
      '-t',
      'person@runner.example.org',
      inTheLoginShell('porelo vault put git.token.github.com'),
    ]);
    expect(terminal.typed, isEmpty);
    expect(backend.follows, isEmpty, reason: 'a running terminal has not confirmed a vault entry');
    backend.theStoreIs = const VaultState(
      vault: '',
      exists: true,
      readable: true,
      credentials: [Credential(name: 'git.token.github.com', type: 'token', characters: 12)],
    );
    terminal.endsWith(0);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-done')));
    await World.settle(tester);
    expect(binding.problem, isNull);
    expect(binding.bound, 'api');
    expect(backend.follows.single.url, repository.httpsUrl);
    expect(
      backend.storeAsked.where((each) => each == 'credentials').length,
      2,
      reason: 'the vault is listed before and after the terminal',
    );
    expect(backend.deployKeysMade, isEmpty);
    expect(forge.keyCalls, isEmpty);
  });

  for (final readable in [false, true]) {
    // Harm: an unreadable vault or absent token must never be treated as usable credentials.
    test('binding refuses an unconfirmed vault entry when readable is $readable', () async {
      final backend = FakeBackend([])
        ..theStoreIs = VaultState(vault: '', exists: true, readable: readable, credentials: []);
      final workspace = FakeWorkspace()
        ..repository = repository
        ..onTheForge = 'project:\n  name: api\n';
      final binding = MachineBinding(FakeForge(), workspace, backend, machineName: 'vm', login: 'alice');
      addTearDown(binding.dispose);
      var prompts = 0;
      await binding.bind(
        workspace.agentKeys.single,
        storeToken: () async {
          prompts++;
        },
      );
      expect(binding.problem, isNotNull);
      expect(backend.follows, isEmpty);
      expect(prompts, readable ? 1 : 0);
      expect(backend.deployKeysMade, isEmpty);
    });
  }

  // Harm: clearing must not revoke forge access outside the machine being cleared.
  test('clearing leaves legacy deploy keys at the forge', () async {
    final backend = FakeBackend([]);
    await backend.open();
    backend.theStoreIs = const VaultState(
      vault: '',
      exists: true,
      readable: true,
      credentials: [Credential(name: 'git.token.github.com', type: 'api-key', characters: 12)],
    );
    final old = await backend.deployKey('api', upstream: repository.sshUrl);
    final forge = FakeForge();
    await forge.addDeployKey('acme/api', title: old.title, key: old.publicKey, readOnly: true);
    forge.keyCalls.clear();
    final tokens = MemoryForgeTokens();
    await tokens.write('github.com', 'ghp_accepted');
    final forges = ForgeConnection(
      tokens,
      forgeFor: (token, _) {
        forge.tokensTried.add(token);
        return forge;
      },
      workspaceFor: (_, _) => FakeWorkspace(),
    );
    addTearDown(forges.dispose);
    await forges.load();
    final clearing = MachineClearing(backend, forges, machineName: 'vm');
    addTearDown(clearing.dispose);
    await clearing.look();
    await clearing.clearIt();
    expect(clearing.problem, isNull);
    expect(clearing.cleared?.refused, isFalse);
    expect(forge.keyCalls, isEmpty, reason: 'clearing must not even list or check deploy keys');
    expect(backend.deployKeysMade, hasLength(1), reason: 'the preexisting legacy key is the entire reference set');
    expect(
      forge.keysOf['acme/api'],
      hasLength(1),
      reason: 'only the daemon reports legacy keys; the interface never removes them',
    );
  });
}

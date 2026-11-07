import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_check_run.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_token_sources.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/server_first_login.dart';
import 'package:porelo_frontend/src/app/server_setup.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/server_setup_wizard.dart';

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_organization.dart';
import '../support/signed_host.dart';

const _serverKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl';
const _changedKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI';
const _fingerprint = 'SHA256:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';

/// The server as `ssh-keyscan` and `ssh-keygen` see it: it answers once [ready], with [key].
class _Server {
  bool ready = true;
  String key = _serverKey;
  final scans = <List<String>>[];

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    if (program.endsWith('ssh-keyscan')) {
      scans.add(arguments);
      return ready ? (code: 0, out: '192.0.2.7 $key\n', err: '') : (code: 1, out: '', err: 'Connection refused\n');
    }
    if (program.endsWith('ssh-keygen')) return (code: 0, out: '256 $_fingerprint 192.0.2.7 (ED25519)\n', err: '');
    return (code: 127, out: '', err: 'not here');
  }
}

final _passing = (
  code: 0,
  out: jsonEncode({
    'v': 1,
    'ok': true,
    'complete': true,
    'findings': [
      {'id': 'memory', 'state': 'pass', 'found': 8192, 'unit': 'MiB', 'asked': 2048},
    ],
  }),
  err: '',
);

class _Walk {
  final server = _Server();
  final terminals = <List<String>>[];
  final forgotten = <KnownWithAnother>[];
  final roots = <RootLogin>[
    (state: RootLoginState.providersLine, words: 'The bootstrap line has not run: root still answers.'),
    (state: RootLoginState.open, words: 'Root logs in with your Machine Admin card key.'),
  ];
  var started = 0;
  late ServerSetup setup;
}

Future<_Walk> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final walk = _Walk();
  final settings = Settings(MemorySettingsStore());
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
  final access = await HostFixture().access(settings);
  final runs = HostRuns(machines, hostAccess: access);
  walk.setup = ServerSetup(
    access: access,
    runs: runs,
    settings: settings,
    runKeyCommand: walk.server.run,
    hostCheck: HostCheckRun(
      executable: 'porelo-host',
      run: (_, _, {inDirectory, environment = const {}, input}) async => _passing,
    ),
    knownWithAnother: (address, key) async => const KnownWithAnother(
      host: '192.0.2.7',
      files: ['/home/tester/.ssh/known_hosts'],
      fingerprints: ['256 SHA256:theOldServersKeyxxxxxxxxxxxxxxxxxxxxxxxxxxx 192.0.2.7 (ED25519)'],
    ),
    forgetOldKey: (known) async => walk.forgotten.add(known),
    rootLogin: ({required address, required pin, required cardKey}) async =>
        walk.roots.length > 1 ? walk.roots.removeAt(0) : walk.roots.first,
    makePin: (address, key) async =>
        ComparedKeyPin.at(Directory('/nonexistent-pin'), File('/nonexistent-pin/known_hosts')),
    startHost: (_, _) async {
      walk.started++;
      throw const ProcessException('porelo-host', [], 'nothing is prepared here');
    },
  );
  addTearDown(() {
    walk.setup.dispose();
    runs.dispose();
    machines.dispose();
    settings.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ServerSetupWizard(
          setup: walk.setup,
          openTerminal: (context, command) async => walk.terminals.add(command),
        ),
      ),
    ),
  );
  await World.settle(tester);
  return walk;
}

Finder get _next => find.byKey(const Key('wizard-next'));

bool _nextIsGrey(WidgetTester tester) => tester.widget<FilledButton>(_next).onPressed == null;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await World.settle(tester);
}

Future<void> _type(WidgetTester tester, Key key, String value) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(find.byKey(key), value);
  await World.settle(tester);
}

Future<void> _chooseOrchard(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('setup-machine')));
  await _tap(tester, find.text('orchard').last);
}

Future<void> _toTheKey(WidgetTester tester) async {
  await _chooseOrchard(tester);
  await _tap(tester, _next);
  await _type(tester, const Key('setup-address'), '192.0.2.7');
  await _type(tester, const Key('setup-first-login'), 'ubuntu');
  await _tap(tester, find.byKey(const Key('setup-provider-ready')));
  await _tap(tester, _next);
}

void main() {
  // Harm: a page opens before what it builds on holds, and a key the window could not yet know to be the server's is
  // trusted, root's login is never handed over, or a machine is prepared that the check did not pass.
  testWidgets('every page opens only once its answer holds, and each grey Next says why', (tester) async {
    final walk = await _open(tester);
    expect(find.textContaining('Step 1 of'), findsOneWidget);
    expect(_nextIsGrey(tester), isTrue);
    expect(find.text('Choose the machine.'), findsOneWidget);
    await _chooseOrchard(tester);
    expect(_nextIsGrey(tester), isFalse);
    await _tap(tester, _next);

    expect(find.textContaining('Step 2 of'), findsOneWidget);
    expect(find.text("Give the server's address, as the provider shows it."), findsOneWidget);
    await _type(tester, const Key('setup-address'), '192.0.2.7');
    expect(walk.server.scans, isEmpty, reason: 'typing an address fetches nothing');
    await _type(tester, const Key('setup-first-login'), 'ubuntu');
    expect(find.textContaining('Tick that your provider reports the server ready'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('setup-provider-ready')));
    walk.server.ready = false;
    await _tap(tester, _next);
    expect(find.textContaining('Step 2 of'), findsOneWidget, reason: 'a server not answering SSH keeps page 2');
    expect(find.byKey(const Key('setup-ssh-problem')), findsOneWidget);
    walk.server.ready = true;
    await _tap(tester, _next);

    expect(find.textContaining('Step 3 of'), findsOneWidget);
    expect(find.text('Fetch the SSH host key, or paste it.'), findsWidgets);
    expect(walk.server.scans.where((each) => each.contains('ed25519')), isEmpty, reason: 'nothing fetched by itself');
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    expect(
      find.descendant(of: find.byKey(const Key('setup-key-box')), matching: find.text(_fingerprint)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('setup-key-box')),
        matching: find.byKey(const Key('setup-compare-command')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('setup-old-key')), findsOneWidget);
    expect(find.textContaining('theOldServersKey'), findsOneWidget);
    expect(_nextIsGrey(tester), isTrue);
    await _tap(tester, find.byKey(const Key('setup-compared')));
    await _tap(tester, _next);
    expect(walk.forgotten, isEmpty, reason: 'the old key stays until preparing starts; going back leaves it');

    expect(find.textContaining('Step 4 of'), findsOneWidget);
    await _tap(tester, _next);

    expect(find.textContaining('Step 5 of'), findsOneWidget);
    expect(find.byKey(const Key('host-bootstrap-command')), findsOneWidget);
    expect(_nextIsGrey(tester), isTrue);
    await _tap(tester, find.byKey(const Key('setup-open-terminal')));
    expect(walk.terminals.single.last, 'ubuntu@192.0.2.7');
    expect(walk.terminals.single, contains('UserKnownHostsFile="/nonexistent-pin/known_hosts"'));
    expect(find.text('The bootstrap line has not run: root still answers.'), findsWidgets);
    expect(_nextIsGrey(tester), isTrue);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    expect(_nextIsGrey(tester), isFalse);
    await _tap(tester, _next);

    expect(find.textContaining('Step 6 of'), findsOneWidget);
    expect(find.text('Check the machine first. It only reads, and changes nothing on it.'), findsWidgets);
    await _tap(tester, find.byKey(const Key('host-check-run')));
    expect(_nextIsGrey(tester), isFalse);
    await _tap(tester, _next);

    expect(find.text('Machine: orchard'), findsOneWidget);
    expect(find.textContaining(_fingerprint), findsWidgets);
    expect(walk.started, 0, reason: 'nothing is prepared before the summary is confirmed');
    expect(walk.forgotten, isEmpty);

    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.forgotten.single.files, ['/home/tester/.ssh/known_hosts'], reason: 'taken out as preparing starts');
    expect(walk.started, 1);
  });

  // Harm: a key that changed between comparing and preparing is taken, which is the installer's or a stranger's.
  testWidgets('a key changed since it was compared starts nothing and returns to the key', (tester) async {
    final walk = await _open(tester);
    await _toTheKey(tester);
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    await _tap(tester, _next);
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('host-check-run')));
    await _tap(tester, _next);
    walk.server.key = _changedKey;
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 0);
    expect(find.textContaining('Step 3 of'), findsOneWidget);
    expect(walk.setup.compared, isFalse);
    expect(walk.setup.key, isNull, reason: 'the old comparison no longer holds');
    expect(find.textContaining('changed since you compared it'), findsWidgets, reason: 'the key page says why');
    expect(walk.forgotten, isEmpty, reason: 'nothing of the old key is taken out for a start that did not happen');
  });

  // Harm: going back and changing the address keeps the old server's key and root login as proven.
  testWidgets('a new address drops the key and the root login proven for the old one', (tester) async {
    final walk = await _open(tester);
    await _toTheKey(tester);
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    expect(walk.setup.whyNotKey, isNull);
    walk.setup.address = '192.0.2.8';
    expect(walk.setup.key, isNull);
    expect(walk.setup.compared, isFalse);
    expect(walk.setup.sshAnswered, isFalse);
  });

  // Harm: a server that answers with no key reads as a fetched key.
  testWidgets('a fetch that fails says so, and the page stays', (tester) async {
    final walk = await _open(tester);
    await _toTheKey(tester);
    walk.server.ready = false;
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    expect(find.byKey(const Key('setup-key-problem')), findsOneWidget);
    expect(_nextIsGrey(tester), isTrue);
  });

  // Harm: a vault that could not be asked reads as holding no token, so the person is sent to sign in, or the token is
  // given before the person chose its source.
  testWidgets('the token page names each source with its answer, and gives only the one chosen', (tester) async {
    final given = <TokenSource>[];
    final step = HostTokenStep(
      host: 'orchard',
      sources: HostTokenSources(
        forge: 'GitHub',
        repository: 'https://github.com/acme/porelo.git',
        address: 'github.com',
        declarations: () async => throw const DeclarationsUnread("This computer's Porelo (porelod) did not answer."),
        hasKept: (_) async => true,
        secrets: () => null,
      ),
      connect: () async {},
      give: (answer) async {
        given.add(answer.source);
        return null;
      },
    );
    addTearDown(step.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HostTokenPanel(step: step)),
      ),
    );
    await step.ask();
    await World.settle(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('token-source-declared')),
        matching: find.text("This computer's Porelo (porelod) did not answer."),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('token-source-kept')), findsOneWidget);
    expect(find.byKey(const Key('token-source-secretsFile')), findsOneWidget);
    expect(given, isEmpty);
    await _tap(tester, find.byKey(const Key('token-give')));
    expect(given, [TokenSource.kept]);
    expect(find.byKey(const Key('token-given')), findsOneWidget);
  });
}

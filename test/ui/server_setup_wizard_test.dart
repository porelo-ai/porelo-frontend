import 'dart:async';
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
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_process.dart';
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
  final logins = <List<String>>[];
  Ran login = (code: 0, out: '', err: '');
  Completer<void>? loginHeld;

  /// Holds `ssh-keyscan` until the test lets it go, as a server slow to show its key.
  Completer<void>? scanHeld;

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    if (program.endsWith('ssh-keyscan')) {
      scans.add(arguments);
      await scanHeld?.future;
      return ready ? (code: 0, out: '192.0.2.7 $key\n', err: '') : (code: 1, out: '', err: 'Connection refused\n');
    }
    if (program.endsWith('ssh-keygen')) return (code: 0, out: '256 $_fingerprint 192.0.2.7 (ED25519)\n', err: '');
    if (program.endsWith('ssh')) {
      logins.add(arguments);
      await loginHeld?.future;
      return login;
    }
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

  /// Holds porelo-host's start until the test lets it go, as a command that has not said its first line.
  Completer<Process>? hostHeld;
  late ServerSetup setup;
  late HostFixture fixture;

  /// Whether the test put [setup] away itself, as the window does once the wizard returns.
  bool disposed = false;

  void dispose() {
    disposed = true;
    setup.dispose();
  }
}

Future<_Walk> _open(WidgetTester tester, {bool shown = false}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final walk = _Walk();
  final settings = Settings(MemorySettingsStore());
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
  walk.fixture = HostFixture();
  final access = await walk.fixture.access(settings);
  final runs = HostRuns(machines, hostAccess: access);
  walk.setup = ServerSetup(
    access: access,
    runs: runs,
    settings: settings,
    runKeyCommand: walk.server.run,
    runFirstLogin: walk.server.run,
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
      if (walk.hostHeld case final held?) return held.future;
      throw const ProcessException('porelo-host', [], 'nothing is prepared here');
    },
  );
  addTearDown(() {
    if (!walk.disposed) walk.setup.dispose();
    runs.dispose();
    machines.dispose();
    settings.dispose();
  });
  Future<void> openTerminal(BuildContext context, List<String> command) async => walk.terminals.add(command);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: shown
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => showServerSetupWizard(context, setup: walk.setup, openTerminal: openTerminal),
                  child: const Text('Set up a machine'),
                ),
              )
            : ServerSetupWizard(setup: walk.setup, openTerminal: openTerminal),
      ),
    ),
  );
  if (shown) await tester.tap(find.text('Set up a machine'));
  await World.settle(tester);
  return walk;
}

Finder get _next => find.byKey(const Key('wizard-next'));

/// Walks the wizard to its review, with the key compared, root's login open and the check passed.
Future<void> _toTheReview(WidgetTester tester) async {
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
}

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
  // Harm: the wizard's card floats in a second, empty dialog around it.
  testWidgets('the wizard is shown as the one dialog it is', (tester) async {
    await _open(tester, shown: true);
    expect(find.byKey(const Key('setup-machine')), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget, reason: 'the AlertDialog is the only dialog');
  });

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

  Future<void> toTheLogin(WidgetTester tester) async {
    await _toTheKey(tester);
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    await _tap(tester, _next);
    await _tap(tester, _next);
    expect(find.textContaining('Step 5 of'), findsOneWidget);
  }

  // Harm: root's keys are replaced on a machine without the person's press, or the line runs where the pin does not
  // hold, or waits for a password nobody can type.
  testWidgets('Run it for me runs the line unasked on a press, then tries root', (tester) async {
    final walk = await _open(tester);
    walk.roots
      ..clear()
      ..add((state: RootLoginState.open, words: 'Root logs in with your Machine Admin card key.'));
    await toTheLogin(tester);
    expect(walk.server.logins, isEmpty, reason: 'nothing runs on entering the page');
    await _tap(tester, find.byKey(const Key('setup-run-bootstrap')));
    final login = walk.server.logins.single;
    expect(login, containsAll(['BatchMode=yes', 'UserKnownHostsFile="/nonexistent-pin/known_hosts"']));
    expect(login[login.length - 2], 'ubuntu@192.0.2.7');
    expect(login.last, startsWith('sudo -n install -d -m 700 /root/.ssh && '));
    expect(login.last, contains('| sudo -n tee /root/.ssh/authorized_keys'));
    expect(login.last, contains('&& sudo -n chmod 600'));
    expect(walk.terminals, isEmpty);
    expect(find.text('Root logs in with your Machine Admin card key.'), findsWidgets);
    expect(_nextIsGrey(tester), isFalse);
  });

  // Harm: a sudo that wants a password reads as a run, or leaves the person without the terminal.
  testWidgets('a sudo that wants a password is said, and the terminal stays the way', (tester) async {
    final walk = await _open(tester);
    walk.server.login = (code: 1, out: '', err: 'sudo: a password is required\n');
    await toTheLogin(tester);
    await _tap(tester, find.byKey(const Key('setup-run-bootstrap')));
    expect(find.textContaining('sudo on the server wants your password'), findsWidgets);
    expect(walk.roots, hasLength(2), reason: 'root is not tried after a line that did not run');
    expect(_nextIsGrey(tester), isTrue);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('setup-open-terminal'))).onPressed, isNotNull);
  });

  // Harm: a run answered for a server or login no longer asked about opens the way for the new one.
  testWidgets('a run still going when the address changes says nothing of the new one', (tester) async {
    final walk = await _open(tester);
    walk.roots
      ..clear()
      ..add((state: RootLoginState.open, words: 'Root logs in with your Machine Admin card key.'));
    await toTheLogin(tester);
    walk.server.loginHeld = Completer<void>();
    await tester.ensureVisible(find.byKey(const Key('setup-run-bootstrap')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('setup-run-bootstrap')));
    await tester.pump();
    expect(walk.setup.runningBootstrap, isTrue);
    walk.setup.address = '192.0.2.8';
    walk.server.loginHeld!.complete();
    await World.settle(tester);
    expect(walk.setup.bootstrapRun, isNull);
    expect(walk.setup.root, isNull, reason: 'root is not tried for the old address');
    expect(walk.setup.runningBootstrap, isFalse);
  });

  // Harm: words of an earlier try stand beside, or against, what the last one found.
  testWidgets('each try replaces what the other said', (tester) async {
    final walk = await _open(tester);
    walk.roots
      ..clear()
      ..add((state: RootLoginState.open, words: 'Root logs in with your Machine Admin card key.'));
    walk.server.login = (code: 1, out: '', err: 'sudo: a password is required\n');
    await toTheLogin(tester);
    await _tap(tester, find.byKey(const Key('setup-run-bootstrap')));
    expect(find.byKey(const Key('setup-bootstrap-answer')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    expect(find.byKey(const Key('setup-bootstrap-answer')), findsNothing);
    expect(_nextIsGrey(tester), isFalse);
    await _tap(tester, find.byKey(const Key('setup-run-bootstrap')));
    expect(find.byKey(const Key('setup-root-answer')), findsNothing, reason: 'a failed run takes back the root answer');
    expect(_nextIsGrey(tester), isTrue);
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

  // Harm: on the Prepare step Back races a setup that goes on, Leave warns about the way it is meant to go on, and its
  // protocol stays black until the command's first line.
  testWidgets('a running preparation offers no Back, leaves without asking, and waits for its first line', (
    tester,
  ) async {
    final walk = await _open(tester, shown: true);
    walk.hostHeld = Completer<Process>();
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
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 1);
    expect(find.textContaining('— Prepare'), findsOneWidget);
    expect(find.text('Waiting for the first line'), findsOneWidget);
    expect(find.byKey(const Key('wizard-back')), findsNothing);
    await _tap(tester, find.byKey(const Key('wizard-leave')));
    expect(find.byKey(const Key('wizard-confirm-leave')), findsNothing, reason: 'its line says it goes on, and where');
    expect(find.byType(ServerSetupWizard), findsNothing);
    expect(walk.setup.preparing, isTrue, reason: 'leaving does not stop the preparation');
  });

  // Harm: the window puts the setup away once the wizard returns, and the preparation that goes on throws into it
  // when it ends.
  testWidgets('a preparation left while it runs ends quietly after its setup was put away', (tester) async {
    final walk = await _open(tester, shown: true);
    final held = walk.hostHeld = Completer<Process>();
    await _toTheReview(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    await _tap(tester, find.byKey(const Key('wizard-leave')));
    expect(find.byType(ServerSetupWizard), findsNothing);
    final run = walk.setup.run!;
    walk.dispose();
    final process = HostProcess();
    held.complete(process);
    await World.settle(tester);
    process
      ..line(const host.Step('rent', host.StepState.started, text: 'Take the server as given'))
      ..end(65);
    await run.finished;
    await World.settle(tester);
    expect(tester.takeException(), isNull);
    expect(run.session.protocol.join('\n'), contains('Take the server as given'), reason: 'the run went on');
  });

  // Harm: a Leave before the preparation started drops every answer without asking, and the setup put away then
  // still starts the machine's preparation that nobody follows.
  testWidgets('leaving before the preparation started asks, and a setup put away then starts nothing', (tester) async {
    final walk = await _open(tester, shown: true);
    await _toTheReview(tester);
    final scan = walk.server.scanHeld = Completer<void>();
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(find.text('Waiting for the first line'), findsOneWidget, reason: 'the pane says so before the command');
    await _tap(tester, find.byKey(const Key('wizard-leave')));
    expect(find.byKey(const Key('wizard-confirm-leave')), findsOneWidget, reason: 'nothing runs on by design yet');
    await _tap(tester, find.byKey(const Key('wizard-confirm-leave')));
    walk.dispose();
    scan.complete();
    await World.settle(tester);
    expect(tester.takeException(), isNull);
    expect(walk.started, 0);
    expect(walk.forgotten, isEmpty, reason: 'nothing of the old key is taken out for a start that did not happen');
  });

  // Harm: a preparation refused before it started reads as one that goes on, and Leave drops the answers unasked.
  testWidgets('a preparation refused before it started asks before leave', (tester) async {
    final walk = await _open(tester, shown: true);
    await _toTheReview(tester);
    walk.fixture.readRefusal = 'The organization could not be read.';
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 0);
    expect(find.byKey(const Key('setup-prepare-problem')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('wizard-leave')));
    expect(find.byKey(const Key('wizard-confirm-leave')), findsOneWidget);
  });

  // Harm: the pane keeps saying it waits after the machine's first line came.
  testWidgets("the waiting line goes once the machine's first line comes", (tester) async {
    final walk = await _open(tester, shown: true);
    final held = walk.hostHeld = Completer<Process>();
    await _toTheReview(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(find.text('Waiting for the first line'), findsOneWidget);
    final process = HostProcess();
    held.complete(process);
    await World.settle(tester);
    expect(find.text('Waiting for the first line'), findsOneWidget, reason: 'a started command has said nothing yet');
    process.line(const host.Step('rent', host.StepState.started, text: 'Take the server as given'));
    await World.settle(tester);
    expect(find.text('Waiting for the first line'), findsNothing);
    expect(find.textContaining('Take the server as given'), findsOneWidget);
    process.end(65);
    await World.settle(tester);
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

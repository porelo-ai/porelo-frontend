import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_access.dart' show HostAccess;
import 'package:porelo_frontend/src/app/host_check_run.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
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
import '../support/host_rental.dart';
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
  late Settings settings;
  late HostRuns runs;
  late HostAccess access;
  FixtureProof? proof;

  /// What porelo-host was started with, in order.
  final arguments = <List<String>>[];

  /// Each porelo-host started while [live], to be answered by the test.
  final processes = <HostProcess>[];
  bool live = false;
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

/// Opens the wizard; [shown] as its dialog, [once] by a button that opens it through the one guard of preparing.
Future<_Walk> _open(
  WidgetTester tester, {
  bool shown = false,
  bool once = false,
  Size size = const Size(1280, 800),
  bool readHeld = false,
  FutureOr<Ran> Function(List<String> arguments)? check,
  void Function(HostFixture fixture)? organization,
  Future<void> Function(_Walk walk)? before,
  Future<HostPreparation> Function(_Walk walk)? startingOver,
  String? machineName,
  HostTokenStep Function(String host)? token,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final walk = _Walk();
  final settings = walk.settings = Settings(MemorySettingsStore());
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
  walk.fixture = HostFixture();
  organization?.call(walk.fixture);
  final proof = walk.proof = readHeld ? (FixtureProof(walk.fixture)..hold = Completer<void>()) : null;
  final access = walk.access = await walk.fixture.access(settings, proof: proof);
  final runs = walk.runs = HostRuns(machines, hostAccess: access);
  await before?.call(walk);
  final earlier = await startingOver?.call(walk);
  walk.setup = ServerSetup(
    access: access,
    runs: runs,
    settings: settings,
    runKeyCommand: walk.server.run,
    runFirstLogin: walk.server.run,
    startingOver: earlier,
    machineName: machineName,
    hostCheck: HostCheckRun(
      executable: 'porelo-host',
      run: (_, arguments, {inDirectory, environment = const {}, input}) async =>
          check == null ? _passing : check(arguments),
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
    startHost: (_, arguments) async {
      walk.started++;
      walk.arguments.add(arguments);
      if (walk.live) return (walk.processes..add(HostProcess())).last;
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
        body: shown || once
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => once
                      ? access.prepare(
                          () => showServerSetupWizard(
                            context,
                            setup: walk.setup,
                            openTerminal: openTerminal,
                            token: token,
                          ),
                        )
                      : showServerSetupWizard(context, setup: walk.setup, openTerminal: openTerminal, token: token),
                  child: const Text('Set up a machine'),
                ),
              )
            : ServerSetupWizard(setup: walk.setup, openTerminal: openTerminal, token: token),
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

Map<String, Object?> _finding(String id, String state, {Object? found, String? unit, Object? asked, String? todo}) => {
  'id': id,
  'state': state,
  'found': found,
  'unit': unit,
  'asked': asked,
  'do': todo,
};

Ran _answer(List<Map<String, Object?>> findings, {bool complete = true}) {
  final fails = findings.any((each) => each['state'] == 'fail');
  final ok = !fails && complete;
  return (code: ok ? 0 : 1, out: jsonEncode({'v': 1, 'ok': ok, 'complete': complete, 'findings': findings}), err: '');
}

Finder _within(String id, String text) =>
    find.descendant(of: find.byKey(ValueKey('host-check-finding-$id')), matching: find.textContaining(text));

/// Walks to *What it will run*, with the key compared.
Future<void> _toTheChoices(WidgetTester tester) async {
  await _toTheKey(tester);
  await _tap(tester, find.byKey(const Key('setup-fetch-key')));
  await _tap(tester, find.byKey(const Key('setup-compared')));
  await _tap(tester, _next);
  expect(find.textContaining('Step 4 of'), findsOneWidget);
}

/// Walks to the check's page, with root's login open.
Future<void> _toTheCheck(WidgetTester tester) async {
  await _toTheChoices(tester);
  await _tap(tester, _next);
  await _tap(tester, find.byKey(const Key('setup-try-root')));
  await _tap(tester, find.byKey(const Key('setup-try-root')));
  await _tap(tester, _next);
  expect(find.textContaining('Step 6 of'), findsOneWidget);
}

Future<void> _pressCheck(WidgetTester tester) => _tap(tester, find.byKey(const Key('host-check-run')));

Future<void> _openMoreSettings(WidgetTester tester) => _tap(tester, find.text('More settings'));

Future<void> _typeSetting(WidgetTester tester, String key, String value) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.enterText(find.byKey(Key(key)), value);
  await World.settle(tester);
}

/// A preparation of orchard that the machine refused for its key, with nothing of it on the machine.
Future<HostPreparation> _refusedForItsKey(
  WidgetTester tester,
  _Walk walk, {
  host.HostPreparationSettings settings = const host.HostPreparationSettings(),
}) async {
  final process = HostProcess();
  final run = walk.runs.start(
    project: 'orchard',
    record: HostUpRecord(
      hostName: 'orchard',
      host: 'orchard',
      givenAddress: '192.0.2.7',
      givenHostKey: _changedKey,
      preparationSettings: settings,
      machineFile: signedSetup.machineFile,
      publicKey: signedSetup.publicKey,
    ),
    session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
  );
  await tester.pump();
  process
    ..line(
      const host.Step(
        'ssh',
        host.StepState.refused,
        fix: '${host.hostKeyNotFiled}, so this try changed nothing on it.',
      ),
    )
    ..end(69);
  await run.finished;
  expect(walk.runs.mayStartOver(run), isTrue);
  return run;
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

  // Harm: a second press while the first hand-over runs hands the machine the token twice.
  testWidgets('a press while the token is handed over gives nothing a second time', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var gives = 0;
    final held = Completer<String?>();
    final step = HostTokenStep(
      host: 'orchard',
      sources: HostTokenSources(
        forge: 'GitHub',
        repository: 'https://github.com/acme/porelo.git',
        address: 'github.com',
        declarations: () async => const [],
        hasKept: (_) async => true,
        secrets: () => null,
      ),
      connect: () async {},
      give: (_) {
        gives++;
        return held.future;
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
    await _tap(tester, find.byKey(const Key('token-give')));
    await _tap(tester, find.byKey(const Key('token-give')));
    unawaited(step.giveFrom(step.offered!));
    expect(gives, 1);
    held.complete(null);
    await World.settle(tester);
    expect(find.byKey(const Key('token-given')), findsOneWidget);
  });

  // Harm: a run refused for its key can be given its key only in the old form, or is let go before a new one starts,
  // and Leave loses the only record of what was tried.
  testWidgets('a run refused for its key opens the wizard at the key, and is let go only once a new one starts', (
    tester,
  ) async {
    late HostPreparation earlier;
    final walk = await _open(
      tester,
      shown: true,
      startingOver: (walk) async => earlier = await _refusedForItsKey(tester, walk),
    );
    expect(find.textContaining('Step 3 of'), findsOneWidget, reason: 'it opens at the key');
    expect(walk.setup.name, 'orchard');
    expect(walk.setup.address, '192.0.2.7');
    expect(walk.setup.hostCheck, isNotNull);
    expect(tester.widget<FilledButton>(find.byKey(const Key('setup-fetch-key'))).onPressed, isNotNull);
    await _tap(tester, find.byKey(const Key('wizard-leave')));
    expect(find.byType(ServerSetupWizard), findsNothing);
    expect(walk.runs.of('orchard'), same(earlier), reason: 'leaving leaves the stopped run as it was');
    expect(walk.settings.hostUp('orchard'), isNotNull);

    await tester.tap(find.text('Set up a machine'));
    await World.settle(tester);
    expect(find.textContaining('Step 3 of'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    await _tap(tester, _next);
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, _next);
    await _pressCheck(tester);
    await _tap(tester, _next);
    expect(find.text('Machine: orchard'), findsOneWidget);
    expect(find.text('Give the first login the provider gave you, such as ubuntu.'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('wizard-change-1')));
    await _type(tester, const Key('setup-first-login'), 'ubuntu');
    await _tap(tester, find.byKey(const Key('setup-provider-ready')));
    await _tap(tester, _next);
    expect(walk.setup.whyNotLogin, isNull, reason: 'root logs in without the first login, so it stays proven');
    expect(walk.runs.of('orchard'), same(earlier), reason: 'nothing started yet');
    walk.live = true;
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 1);
    expect(walk.runs.of('orchard'), isNot(same(earlier)));
    expect(walk.arguments.single, containsAllInOrder(['--given', '192.0.2.7', '--host-key', _serverKey]));
    walk.processes.single.end(1);
    await World.settle(tester);
  });

  // Harm: a stopped preparation leaves the Prepare step with nothing to press, and no word of the way on.
  testWidgets('a preparation stopped for root shows its line again, and Prepare again tries it once more', (
    tester,
  ) async {
    final walk = await _open(tester, shown: true);
    walk.live = true;
    await _toTheReview(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    walk.processes.last
      ..line(const host.Step('ssh', host.StepState.refused, fix: '${host.rootStillClosed} Nothing changed.'))
      ..end(65);
    await World.settle(tester);
    expect(find.byKey(const Key('preparation-root-command')), findsOneWidget);
    expect(find.byKey(const Key('setup-prepare-again')), findsOneWidget);
    expect(find.byKey(const Key('preparation-another-key')), findsNothing);
    await _tap(tester, find.byKey(const Key('setup-prepare-again')));
    expect(walk.started, 2, reason: 'the same run, tried once more');
    expect(find.byKey(const Key('preparation-root-command')), findsNothing, reason: 'the new try is under way');
    walk.processes.last.end(1);
    await World.settle(tester);
  });

  // Harm: a preparation refused for its key can only be tried again with the same wrong key.
  testWidgets('a preparation refused for its key goes back to the key, and keeps the run until a new one starts', (
    tester,
  ) async {
    final walk = await _open(tester, shown: true);
    walk.live = true;
    await _toTheReview(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    final run = walk.setup.run!;
    walk.processes.last
      ..line(
        const host.Step(
          'ssh',
          host.StepState.refused,
          fix: '${host.hostKeyNotFiled}, so this try changed nothing on it.',
        ),
      )
      ..end(69);
    await World.settle(tester);
    expect(find.byKey(const Key('setup-prepare-again')), findsNothing, reason: 'it would be refused the same way');
    await _tap(tester, find.byKey(const Key('preparation-another-key')));
    expect(find.textContaining('Step 3 of'), findsOneWidget);
    expect(walk.setup.key, isNull);
    expect(walk.runs.of('orchard'), same(run));
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    await _tap(tester, _next);
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, _next);
    await _pressCheck(tester);
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 2);
    expect(walk.runs.of('orchard'), isNot(same(run)));
    walk.processes.last.end(1);
    await World.settle(tester);
  });

  // Harm: a limit typed under More settings and never used is dropped unsaid, and the machine is prepared without it.
  testWidgets('an edit under More settings not used yet, or refused, holds Next and says why, and is kept', (
    tester,
  ) async {
    final asked = <List<String>>[];
    final walk = await _open(
      tester,
      check: (arguments) {
        asked.add(arguments);
        return _passing;
      },
    );
    await _toTheChoices(tester);
    await _openMoreSettings(tester);
    await _typeSetting(tester, 'forge_job_cpus', 'x');
    expect(_nextIsGrey(tester), isTrue);
    expect(find.textContaining('More settings: '), findsOneWidget);
    await _typeSetting(tester, 'forge_job_cpus', '4');
    expect(_nextIsGrey(tester), isTrue);
    expect(find.textContaining('not used yet'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('wizard-back')));
    await _tap(tester, _next);
    expect(tester.widget<TextFormField>(find.byKey(const Key('forge_job_cpus'))).controller!.text, '4');
    expect(_nextIsGrey(tester), isTrue, reason: 'leaving the page dropped nothing');
    await _tap(tester, find.text('Use settings'));
    expect(_nextIsGrey(tester), isFalse);
    expect(walk.setup.chosen.forgeJobCpus, 4);
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, _next);
    await _pressCheck(tester);
    expect(asked.last, containsAllInOrder(['--forge-job-cpus', '4']));
  });

  // Harm: the field keeps a name the organization no longer offers, and throws while it draws.
  testWidgets('a machine no longer offered is taken out of the choice, without a throw', (tester) async {
    final walk = await _open(tester);
    await _chooseOrchard(tester);
    walk.fixture.adminHosts = {'demo'};
    await walk.access.readAgain();
    await World.settle(tester);
    expect(tester.takeException(), isNull);
    expect(walk.setup.name, isEmpty);
    expect(find.text('orchard'), findsNothing);
    expect(find.text('Choose the machine.'), findsOneWidget);
    expect(_nextIsGrey(tester), isTrue);
  });

  // Harm: a key fetched and compared is wiped by clearing the paste box, text pasted but never taken is dropped
  // unsaid, or a key pasted for one server stays for another.
  testWidgets('the paste box keeps a compared key, says what it holds untaken, and is cleared with the address', (
    tester,
  ) async {
    final walk = await _open(tester);
    await _toTheKey(tester);
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    await _type(tester, const Key('setup-pasted-key'), backupKey);
    expect(_nextIsGrey(tester), isTrue);
    expect(find.textContaining('Take the pasted key'), findsWidgets);
    await _type(tester, const Key('setup-pasted-key'), '');
    expect(walk.setup.key?.key, _serverKey, reason: 'clearing the box wipes no fetched key');
    expect(walk.setup.compared, isTrue);
    expect(_nextIsGrey(tester), isFalse);
    await _type(tester, const Key('setup-pasted-key'), _serverKey);
    await _tap(tester, find.byKey(const Key('setup-take-pasted')));
    expect(walk.setup.pasted, isTrue);
    await _tap(tester, find.byKey(const Key('wizard-back')));
    await _type(tester, const Key('setup-address'), '192.0.2.8');
    await _tap(tester, _next);
    expect(find.textContaining('Step 3 of'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('setup-pasted-key'))).controller!.text, isEmpty);
    expect(walk.setup.key, isNull);
  });

  // Harm: repeated clicks open competing setup wizards.
  testWidgets('quick clicks through the guard of preparing open one wizard', (tester) async {
    await _open(tester, once: true, readHeld: true);
    final open = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Set up a machine')).onPressed!;
    open();
    open();
    await World.settle(tester);
    open();
    await World.settle(tester);
    expect(find.byType(ServerSetupWizard), findsOneWidget);
    expect(find.text('Reading your identity and the Porelo organization…'), findsWidgets);
  });

  // Harm: a reused name erases the recovery of a machine set up already, or of a preparation going or waiting.
  for (final collision in ['saved', 'active', 'waiting']) {
    testWidgets('a machine with a $collision preparation of its own is not offered', (tester) async {
      final process = HostProcess();
      HostPreparation? previous;
      final walk = await _open(
        tester,
        before: (walk) async {
          if (collision == 'saved') return walk.settings.rememberHostUp('orchard', signedSetup);
          previous = walk.runs.start(
            project: 'orchard',
            record: signedSetup,
            session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
          );
          await tester.pump();
          if (collision == 'waiting') {
            process
              ..line(const host.Step('person', host.StepState.waiting, needs: ['matrix']))
              ..end(75);
            await previous!.finished;
          }
        },
      );
      final kept = walk.settings.hostUp('orchard')?.stored;
      await _tap(tester, find.byKey(const Key('setup-machine')));
      expect(find.text('orchard'), findsNothing, reason: 'it has a preparation of its own');
      expect(find.text('demo'), findsWidgets);
      await _tap(tester, find.text('demo').last);
      expect(walk.settings.hostUp('orchard')?.stored, kept);
      if (previous != null) expect(walk.runs.of('orchard'), same(previous));
      if (collision == 'active') {
        process.end(65);
        await previous!.finished;
      }
    });
  }

  // Harm: a person with no machine meets a page that can only refuse them, or a machine alice is no admin of is offered,
  // or one is offered before the organization was read.
  testWidgets('only machines read as this person\'s to set up are offered, and none before the read', (tester) async {
    final walk = await _open(tester, readHeld: true, organization: (fixture) => fixture.adminHosts = {'orchard'});
    expect(find.byKey(const Key('setup-machine')), findsNothing);
    expect(find.text('Reading your identity and the Porelo organization…'), findsWidgets);
    walk.proof!.hold!.complete();
    walk.proof!.hold = null;
    await World.settle(tester);
    await _tap(tester, find.byKey(const Key('setup-machine')));
    expect(find.text('demo'), findsNothing, reason: 'alice is no Machine Admin of it');
    expect(find.text('orchard'), findsWidgets);
  });

  testWidgets('with no machine to choose it says who lists one', (tester) async {
    await _open(
      tester,
      organization: (fixture) => fixture
        ..organizationAdmin = true
        ..admin = false,
    );
    expect(find.byKey(const Key('setup-machine')), findsNothing);
    expect(find.textContaining('There is no machine to set up'), findsOneWidget);
  });

  // Harm: a retained start after revocation starts root's preparation.
  testWidgets('the start reads the Machine Admin again, and a revoked one starts nothing', (tester) async {
    final walk = await _open(tester, shown: true);
    await _toTheReview(tester);
    walk.fixture.admin = false;
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 0);
    expect(walk.runs.of('orchard'), isNull);
    expect(find.byKey(const Key('setup-prepare-problem')), findsOneWidget);
  });

  // Harm: preparation must use the chosen pinned host and limits, and the build's own collection, and keep the host on
  // its card; a server reached by name or IPv6 address cannot be prepared or read back after a restart.
  for (final address in ['192.0.2.7', 'orchard.example.org', '2001:db8::7']) {
    testWidgets('preparing passes the choices and the machine file, and keeps the host on its card at $address', (
      tester,
    ) async {
      final walk = await _open(tester, shown: true);
      walk.live = true;
      await _chooseOrchard(tester);
      await _tap(tester, _next);
      await _type(tester, const Key('setup-address'), address);
      await _type(tester, const Key('setup-first-login'), 'ubuntu');
      await _tap(tester, find.byKey(const Key('setup-provider-ready')));
      await _tap(tester, _next);
      await _tap(tester, find.byKey(const Key('setup-fetch-key')));
      await _tap(tester, find.byKey(const Key('setup-compared')));
      await _tap(tester, _next);
      await _openMoreSettings(tester);
      for (final entry in {'forge_runner_capacity': '1', 'forge_job_cpus': '1', 'forge_job_memory': '768m'}.entries) {
        await _typeSetting(tester, entry.key, entry.value);
      }
      await _tap(tester, find.text('Use settings'));
      await _tap(tester, _next);
      await _tap(tester, find.byKey(const Key('setup-try-root')));
      await _tap(tester, find.byKey(const Key('setup-try-root')));
      await _tap(tester, _next);
      await _pressCheck(tester);
      await _tap(tester, _next);
      await _tap(tester, find.byKey(const Key('wizard-start')));
      final run = walk.runs.of('orchard')!;
      final arguments = walk.arguments.single;
      expect(arguments, ['up', ...hostArguments(run.record, 'orchard')]);
      expect(arguments, containsAllInOrder(['--given', address, '--host-key', _serverKey]));
      expect(arguments, contains('--machine-file'));
      expect(
        arguments,
        containsAllInOrder(['--forge-runner-capacity', '1', '--forge-job-cpus', '1', '--forge-job-memory', '768m']),
      );
      expect(arguments, isNot(contains('--collection')), reason: 'The collection is the one the build knows.');
      walk.processes.single
        ..line(host.Step('up', host.StepState.done, address: address, admin: 'root'))
        ..line(
          host.Step(
            'host',
            host.StepState.host,
            host: host.PreparedHost.read({...sshCompletion(), 'address': address}),
          ),
        )
        ..end(0);
      await run.finished;
      await World.settle(tester);
      expect(run.ready, isTrue);
      expect(walk.settings.hostUp('orchard')!.preparedHost!.address, address);
      expect(walk.fixture.writes.single.input['address'], address);
      final restored = HostUpRecord.fromStored(walk.settings.hostUp('orchard')!.stored)!;
      expect(restored.givenAddress, address);
      expect(restored.givenHostKey, _serverKey);
      expect(hostArguments(restored, 'orchard'), isNot(contains('--collection')));
    });
  }

  // Harm: a person installs on a machine that cannot carry it, or sees one fault at a time, rented hour by rented hour.
  testWidgets('several faults stand at once with their value, what was asked and what to do, and hold Next', (
    tester,
  ) async {
    await _open(
      tester,
      check: (_) => _answer([
        _finding('memory', 'pass', found: 8192, unit: 'MiB', asked: 2048),
        _finding('cpus', 'fail', found: 1, unit: 'CPUs', asked: 2, todo: 'Choose a machine with more CPUs.'),
        _finding('virtualization', 'fail', found: false, asked: true, todo: 'Turn off VMs in its jobs.'),
        _finding('disk', 'warn', found: 20, unit: 'GiB'),
        _finding('kvm.works', 'unknown', todo: 'It shows once a VM runs.'),
        _finding('never.heard.of', 'fail', found: {'a': 1}, todo: 'Its own words.'),
      ]),
    );
    await _toTheCheck(tester);
    await _pressCheck(tester);
    expect(_within('cpus', 'Found: 1 CPUs'), findsOneWidget);
    expect(_within('cpus', 'Asked: 2 CPUs'), findsOneWidget);
    expect(_within('cpus', 'What to do: Choose a machine with more CPUs.'), findsOneWidget);
    expect(_within('virtualization', 'Found: no'), findsOneWidget);
    expect(_within('virtualization', "This machine's CPU offers no virtualization"), findsOneWidget);
    expect(find.textContaining('turn off This host runs VMs in its jobs'), findsOneWidget);
    expect(_within('disk', 'Warning'), findsOneWidget);
    expect(_within('never.heard.of', 'Fails'), findsOneWidget);
    expect(_within('never.heard.of', '{"a":1}'), findsOneWidget);
    expect(_within('memory', 'Passed'), findsOneWidget, reason: 'what passes reads as passed, not as absent');
    expect(_within('memory', 'Found: 8192 MiB'), findsOneWidget);
    expect(_within('kvm.works', 'Cannot be known beforehand'), findsOneWidget);
    expect(_within('kvm.works', 'Passed'), findsNothing);
    expect(_nextIsGrey(tester), isTrue);
  });

  // Harm: a check that stopped halfway is taken for a whole list, and the machine is installed on.
  testWidgets('a check that did not finish says so and holds Next', (tester) async {
    await _open(tester, check: (_) => _answer([_finding('memory', 'pass')], complete: false));
    await _toTheCheck(tester);
    await _pressCheck(tester);
    expect(find.textContaining('did not run to its end'), findsOneWidget);
    expect(_nextIsGrey(tester), isTrue);
  });

  // Harm: the list stays on what was true of another choice, and a fault is missed or a false one stands.
  testWidgets('a CPU without virtualization is a finding with VMs on and none with VMs off', (tester) async {
    final asked = <List<String>>[];
    await _open(
      tester,
      check: (arguments) {
        asked.add(arguments);
        return arguments[arguments.indexOf('--kvm') + 1] == 'true'
            ? _answer([_finding('virtualization', 'fail', found: false, asked: true)])
            : _passing;
      },
    );
    await _toTheCheck(tester);
    await _pressCheck(tester);
    expect(
      asked.single,
      containsAllInOrder(['check', '--given', '192.0.2.7', '--host-key', _serverKey, '--public-key']),
    );
    expect(find.textContaining('passes the check'), findsOneWidget);
    expect(_nextIsGrey(tester), isFalse);
    await _tap(tester, find.byKey(const Key('wizard-back')));
    await _tap(tester, find.byKey(const Key('wizard-back')));
    await _tap(tester, find.byKey(const Key('host-check-vms')));
    await _tap(tester, _next);
    await _tap(tester, _next);
    expect(_nextIsGrey(tester), isTrue, reason: 'the answer was about the other choice');
    await _pressCheck(tester);
    expect(_within('virtualization', 'Fails'), findsOneWidget);
    expect(_nextIsGrey(tester), isTrue);
  });

  // Harm: a host without a forge still offers its jobs and VMs, as if they meant something there.
  testWidgets('without a forge, neither its jobs nor VMs stand there, and it asks accordingly', (tester) async {
    final asked = <List<String>>[];
    await _open(
      tester,
      check: (arguments) {
        asked.add(arguments);
        return _passing;
      },
    );
    await _toTheChoices(tester);
    expect(find.textContaining('builds run here'), findsOneWidget, reason: 'what each choice costs');
    await _tap(tester, find.byKey(const Key('host-check-vms')));
    await _tap(tester, find.byKey(const Key('host-forge')));
    expect(find.byKey(const Key('host-check-vms')), findsNothing);
    await _openMoreSettings(tester);
    expect(find.byKey(const Key('forge_runner_capacity')), findsNothing);
    expect(find.byKey(const Key('matrix_port')), findsOneWidget);
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, _next);
    await _pressCheck(tester);
    expect(asked.last[asked.last.indexOf('--forge') + 1], 'false');
    expect(asked.last[asked.last.indexOf('--kvm') + 1], 'false', reason: 'VMs mean nothing without a forge here');
  });

  // Harm: an answer about the old choices, arriving late, opens the way for the new ones.
  testWidgets('an answer that arrives after a change is not taken', (tester) async {
    final first = Completer<Ran>();
    final walk = await _open(tester, check: (_) => first.future);
    await _toTheCheck(tester);
    await tester.tap(find.byKey(const Key('host-check-run')));
    await tester.pump();
    expect(find.byKey(const Key('host-check-running')), findsOneWidget);
    walk.setup.chosen = walk.setup.chosen.withPlainChoices(forge: true, kvm: true);
    first.complete(_passing);
    await World.settle(tester);
    expect(walk.setup.checkAnswer, isNull);
    expect(find.textContaining('passes the check'), findsNothing);
    expect(_nextIsGrey(tester), isTrue);
  });

  // Harm: a check that could not speak reads as a machine with nothing wrong, and root runs an installation on it.
  final silent = <String, FutureOr<Ran> Function(List<String>)>{
    'a machine refusing the login': (_) => (
      code: 2,
      out: jsonEncode({
        'v': 1,
        'ok': false,
        'complete': false,
        'findings': <Object>[],
        'said': 'The machine refused the login as root with your key.',
      }),
      err: '',
    ),
    'a broken answer': (_) => (code: 0, out: 'Traceback', err: ''),
    'an answer with exit 1 that says ok': (_) => (
      code: 1,
      out: jsonEncode({
        'v': 1,
        'ok': true,
        'complete': true,
        'findings': [_finding('memory', 'pass')],
      }),
      err: '',
    ),
    'an answer of another version': (_) => (
      code: 0,
      out: jsonEncode({
        'v': 2,
        'ok': true,
        'complete': true,
        'findings': [_finding('memory', 'pass')],
      }),
      err: '',
    ),
    'no answer at all': (_) => (code: 2, out: '', err: ''),
    'a command that refused its options': (_) => (code: 64, out: '', err: 'porelo-host: unknown'),
    'a command that cannot be started': (_) => throw const ProcessException('porelo-host', []),
    'a command that hung': (_) => throw const WorkspaceRefused('`porelo-host check` gave no answer within 5 minutes.'),
  };
  for (final entry in silent.entries) {
    testWidgets('${entry.key} reads as the check not having answered, and holds Next', (tester) async {
      await _open(tester, check: entry.value);
      await _toTheCheck(tester);
      await _pressCheck(tester);
      expect(find.textContaining('The check did not answer'), findsOneWidget);
      if (entry.key == 'a machine refusing the login') {
        expect(find.textContaining('refused the login as root'), findsWidgets);
      }
      expect(_nextIsGrey(tester), isTrue);
      expect(tester.widget<FilledButton>(find.byKey(const Key('host-check-run'))).onPressed, isNotNull);
    });
  }

  // Harm: in a short window a page of the wizard overflows, and what it asks or its Next is cut off.
  testWidgets('every page fits a short window, with More settings open and the check\'s findings shown', (
    tester,
  ) async {
    // The wizard owns the step it made, and puts it away itself.
    final walk = await _open(
      tester,
      shown: true,
      size: const Size(1280, 480),
      token: (name) => HostTokenStep(
        host: name,
        sources: HostTokenSources(
          forge: 'GitHub',
          repository: 'https://github.com/acme/porelo.git',
          address: 'github.com',
          declarations: () async => const [],
          hasKept: (_) async => false,
          secrets: () => null,
        ),
        connect: () async {},
        give: (_) async => null,
      ),
      check: (_) => _answer([
        for (var each = 0; each < 12; each++) _finding('finding$each', 'pass', found: each, unit: 'GiB', asked: 1),
      ]),
    );
    walk.live = true;
    void fits(String page) {
      expect(tester.takeException(), isNull, reason: page);
      expect(
        tester.getRect(_next.evaluate().isEmpty ? find.byKey(const Key('wizard-start')) : _next).bottom,
        lessThanOrEqualTo(480),
        reason: page,
      );
      // The footer's reason under Next, where it stands, fits as well.
      final said = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((widget) => widget is Text && widget.textAlign == TextAlign.end),
      );
      for (final each in said.evaluate()) {
        expect(tester.getRect(find.byWidget(each.widget)).bottom, lessThanOrEqualTo(480), reason: page);
      }
    }

    fits('which machine');
    await _chooseOrchard(tester);
    await _tap(tester, _next);
    await _type(tester, const Key('setup-address'), '192.0.2.7');
    await _type(tester, const Key('setup-first-login'), 'ubuntu');
    await _tap(tester, find.byKey(const Key('setup-provider-ready')));
    fits('where it is');
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    fits('its key');
    await _tap(tester, _next);
    await _openMoreSettings(tester);
    fits('what it will run');
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    await _tap(tester, find.byKey(const Key('setup-try-root')));
    fits('hand the login over');
    await _tap(tester, _next);
    await _pressCheck(tester);
    expect(_within('finding11', 'Passed'), findsOneWidget);
    fits('the check');
    await _tap(tester, _next);
    fits('the review');
    await _tap(tester, find.byKey(const Key('wizard-start')));
    walk.processes.single
      ..line(const host.Step('ssh', host.StepState.refused, fix: '${host.rootStillClosed} Nothing changed.'))
      ..end(65);
    await World.settle(tester);
    expect(find.byKey(const Key('preparation-root-command')), findsOneWidget);
    fits('prepare');
    await _tap(tester, find.byKey(const Key('setup-prepare-again')));
    walk.processes.last
      ..line(const host.Step('up', host.StepState.done, address: '192.0.2.7', admin: 'root'))
      ..line(
        host.Step(
          'host',
          host.StepState.host,
          host: host.PreparedHost.read({...sshCompletion(), 'address': '192.0.2.7'}),
        ),
      )
      ..end(0);
    await World.settle(tester);
    expect(walk.setup.prepared, isTrue);
    await _tap(tester, _next);
    expect(find.textContaining('— Give it your token'), findsOneWidget);
    fits('give it your token');
  });

  /// Goes from a stopped Prepare step back to the review with VMs turned on, the check run again for them.
  Future<void> backWithVms(WidgetTester tester) async {
    await _tap(tester, find.byKey(const Key('wizard-back')));
    expect(find.text('Check and start'), findsNothing);
    await _tap(tester, find.byKey(const Key('wizard-change-3')));
    await _tap(tester, find.byKey(const Key('host-check-vms')));
    await _tap(tester, _next);
    await _tap(tester, find.byKey(const Key('wizard-change-5')));
    await _pressCheck(tester);
    await _tap(tester, _next);
  }

  // Harm: answers changed after a stop are dropped unsaid, and the old run is tried again with its old arguments.
  testWidgets('a run refused for its key, asked again with other answers, starts over with them', (tester) async {
    final walk = await _open(tester, shown: true);
    walk.live = true;
    await _toTheReview(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    final first = walk.setup.run!;
    walk.processes.last
      ..line(
        const host.Step(
          'ssh',
          host.StepState.refused,
          fix: '${host.hostKeyNotFiled}, so this try changed nothing on it.',
        ),
      )
      ..end(69);
    await World.settle(tester);
    await backWithVms(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 2, reason: 'never a silent no-op');
    expect(walk.arguments.last, containsAllInOrder(['--kvm', 'true']));
    expect(walk.runs.of('orchard'), isNot(same(first)));
    walk.processes.last.end(1);
    await World.settle(tester);
  });

  // Harm: a run that stands on the machine is resumed with arguments the review no longer shows.
  testWidgets('a stopped run is resumed only with its own answers, and other answers are refused in words', (
    tester,
  ) async {
    final walk = await _open(tester, shown: true);
    walk.live = true;
    await _toTheReview(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    final first = walk.setup.run!;
    void stopForRoot() => walk.processes.last
      ..line(const host.Step('ssh', host.StepState.refused, fix: '${host.rootStillClosed} Nothing changed.'))
      ..end(65);
    stopForRoot();
    await World.settle(tester);
    await _tap(tester, find.byKey(const Key('wizard-back')));
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 2, reason: 'the same answers try the same run again');
    expect(walk.setup.run, same(first));
    stopForRoot();
    await World.settle(tester);
    await backWithVms(tester);
    await _tap(tester, find.byKey(const Key('wizard-start')));
    expect(walk.started, 2, reason: 'not with arguments the review no longer shows');
    expect(walk.runs.of('orchard'), same(first));
    expect(
      tester.widget<Text>(find.byKey(const Key('setup-prepare-problem'))).data,
      contains('the answers it started with'),
    );
  });

  // Harm: a start-over runs the bootstrap line as an empty login, and cannot reach the page where the login is given.
  testWidgets('a start-over without a first login offers no line to run, and reaches the page to give it', (
    tester,
  ) async {
    final walk = await _open(tester, shown: true, startingOver: (walk) => _refusedForItsKey(tester, walk));
    walk.roots
      ..clear()
      ..add((state: RootLoginState.providersLine, words: 'The bootstrap line has not run: root still answers.'));
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    await _tap(tester, find.byKey(const Key('setup-compared')));
    await _tap(tester, _next);
    await _tap(tester, _next);
    expect(find.textContaining('Step 5 of'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('setup-run-bootstrap'))).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('setup-open-terminal'))).onPressed, isNull);
    expect(find.byKey(const Key('setup-no-first-login')), findsOneWidget);
    for (var page = 0; page < 3; page++) {
      await _tap(tester, find.byKey(const Key('wizard-back')));
    }
    expect(find.textContaining('Step 2 of'), findsOneWidget);
    await _type(tester, const Key('setup-first-login'), 'ubuntu');
    await _tap(tester, find.byKey(const Key('setup-provider-ready')));
    await _tap(tester, _next);
    await _tap(tester, _next);
    await _tap(tester, _next);
    expect(find.textContaining('Step 5 of'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('setup-run-bootstrap'))).onPressed, isNotNull);
    expect(walk.server.logins, isEmpty);
  });

  // Harm: on a start-over's key page, a read still going or failed, or a server not answering, is said nowhere.
  testWidgets('the key page of a start-over says the read and what SSH answered', (tester) async {
    final walk = await _open(
      tester,
      readHeld: true,
      startingOver: (walk) async {
        // The run was made after a read; the wizard's own read is held.
        walk.proof!.hold!.complete();
        walk.proof!.hold = null;
        await walk.access.readAgain();
        final run = await _refusedForItsKey(tester, walk);
        walk.proof!.hold = Completer<void>();
        walk.server.ready = false;
        return run;
      },
    );
    expect(find.textContaining('Step 3 of'), findsOneWidget);
    expect(find.byKey(const Key('setup-access-state')), findsOneWidget);
    walk.proof!.hold!.complete();
    walk.proof!.hold = null;
    await World.settle(tester);
    expect(find.byKey(const Key('setup-access-state')), findsNothing);
    expect(find.byKey(const Key('setup-ssh-problem')), findsOneWidget);
    walk.server.ready = true;
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    expect(walk.setup.key?.key, _serverKey, reason: 'the fetch asks SSH again first');
    expect(find.byKey(const Key('setup-ssh-problem')), findsNothing);
  });

  // Harm: a machine given from its page is refused, and the refusal is replaced by "Choose the machine.".
  testWidgets('a machine given but not offered keeps its name and its refusal', (tester) async {
    final walk = await _open(
      tester,
      machineName: 'orchard',
      before: (walk) => walk.settings.rememberHostUp('orchard', signedSetup),
    );
    await World.settle(tester);
    expect(walk.setup.name, 'orchard');
    expect(find.text('orchard is set up already, or being set up.'), findsOneWidget);
  });

  // Harm: a start-over prepares a machine without a forge, or with its own limits and ports, with the defaults.
  testWidgets('a start-over keeps the choices the stopped run was given', (tester) async {
    const kept = host.HostPreparationSettings(forge: false, matrixPort: 9000);
    final walk = await _open(tester, startingOver: (walk) => _refusedForItsKey(tester, walk, settings: kept));
    expect(walk.setup.chosen.arguments, kept.arguments);
  });

  // Harm: a pasted key stands beside one fetched after it, and is taken for it.
  testWidgets('fetching the key clears the paste box', (tester) async {
    final walk = await _open(tester);
    await _toTheKey(tester);
    await _type(tester, const Key('setup-pasted-key'), _serverKey);
    await _tap(tester, find.byKey(const Key('setup-take-pasted')));
    expect(walk.setup.pasted, isTrue);
    await _tap(tester, find.byKey(const Key('setup-fetch-key')));
    expect(walk.setup.pasted, isFalse);
    expect(tester.widget<TextField>(find.byKey(const Key('setup-pasted-key'))).controller!.text, isEmpty);
    await _tap(tester, find.byKey(const Key('setup-compared')));
    expect(_nextIsGrey(tester), isFalse);
  });
}

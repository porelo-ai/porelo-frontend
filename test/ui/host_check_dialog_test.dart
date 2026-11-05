import 'dart:async';
import 'dart:convert';
import 'dart:io' show ProcessException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_check_run.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_organization.dart';
import '../support/signed_host.dart';

const _otherKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI';

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

final _passing = _answer([_finding('memory', 'pass', found: 8192, unit: 'MiB', asked: 2048)]);

/// The dialog with an address and a pasted key given and a machine chosen, asking [answer] of its check.
Future<void> _open(WidgetTester tester, FutureOr<Ran> Function(List<String> arguments) answer) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = Settings(MemorySettingsStore());
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
  final access = await HostFixture().access(settings);
  final runs = HostRuns(machines, hostAccess: access);
  addTearDown(() {
    runs.dispose();
    machines.dispose();
    settings.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HostDialog(
          project: '',
          machines: machines,
          hostRuns: runs,
          start: (_, _) async => throw StateError('nothing is prepared here'),
          runKeyCommand: (_, _, {inDirectory, environment = const {}, input}) async => (code: 70, out: '', err: ''),
          hostCheck: HostCheckRun(
            executable: 'porelo-host',
            run: (_, arguments, {inDirectory, environment = const {}, input}) async => answer(arguments),
          ),
        ),
      ),
    ),
  );
  await World.settle(tester);
  final field = find.byKey(const Key('preparation-machine-name'));
  await tester.ensureVisible(field);
  await World.settle(tester);
  await tester.tap(field);
  await World.settle(tester);
  await tester.tap(find.text('orchard').last);
  await World.settle(tester);
  await _type(tester, 'SSH host key', hostKey);
  await _type(tester, 'Server address', '192.0.2.7');
  await _rest(tester);
}

Future<void> _type(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

/// Past the wait for typing to rest.
Future<void> _rest(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 501));
  await World.settle(tester);
}

Future<void> _pressCheck(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Check this machine'));
  await tester.pump();
  await tester.tap(find.text('Check this machine'));
  await World.settle(tester);
}

Future<void> _flipVms(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('host-check-vms')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('host-check-vms')));
  await tester.pump();
  await _rest(tester);
}

Finder _within(String id, String text) =>
    find.descendant(of: find.byKey(ValueKey('host-check-finding-$id')), matching: find.textContaining(text));

void _expectNoPrepare() => expect(find.text('Prepare the machine'), findsNothing);

void _expectPrepareOffered(WidgetTester tester) {
  final button = find.widgetWithText(FilledButton, 'Prepare the machine');
  expect(button, findsOneWidget);
  expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
}

void main() {
  // Harm: a person installs on a machine that cannot carry it, or sees one fault at a time, rented hour by rented hour.
  testWidgets('several faults stand at once with their value, what was asked and what to do, and no Prepare', (
    tester,
  ) async {
    await _open(
      tester,
      (_) => _answer([
        _finding('memory', 'pass', found: 8192, unit: 'MiB', asked: 2048),
        _finding('cpus', 'fail', found: 1, unit: 'CPUs', asked: 2, todo: 'Choose a machine with more CPUs.'),
        _finding('virtualization', 'fail', found: false, asked: true, todo: 'Turn off VMs in its jobs.'),
        _finding('disk', 'warn', found: 20, unit: 'GiB'),
        _finding('kvm.works', 'unknown', todo: 'It shows once a VM runs.'),
        _finding('never.heard.of', 'fail', found: {'a': 1}, todo: 'Its own words.'),
      ]),
    );
    expect(find.text('Prepare the machine'), findsNothing, reason: 'the check comes first');
    await _pressCheck(tester);
    expect(_within('cpus', 'Found: 1 CPUs'), findsOneWidget);
    expect(_within('cpus', 'Asked: 2 CPUs'), findsOneWidget);
    expect(_within('cpus', 'What to do: Choose a machine with more CPUs.'), findsOneWidget);
    expect(_within('virtualization', 'Found: no'), findsOneWidget);
    expect(_within('virtualization', "This machine's CPU offers no virtualization"), findsOneWidget);
    expect(_within('disk', 'Warning'), findsOneWidget);
    expect(_within('never.heard.of', 'Fails'), findsOneWidget);
    expect(_within('never.heard.of', '{"a":1}'), findsOneWidget);
    expect(_within('memory', 'Passed'), findsOneWidget, reason: 'what passes reads as passed, not as absent');
    expect(_within('memory', 'Found: 8192 MiB'), findsOneWidget);
    expect(_within('kvm.works', 'Cannot be known beforehand'), findsOneWidget);
    expect(_within('kvm.works', 'Passed'), findsNothing);
    _expectNoPrepare();
  });

  // Harm: a check that stopped halfway is taken for a whole list, and the machine is installed on.
  testWidgets('a check that did not finish says so and offers no Prepare', (tester) async {
    await _open(tester, (_) => _answer([_finding('memory', 'pass')], complete: false));
    await _pressCheck(tester);
    expect(find.textContaining('did not run to its end'), findsOneWidget);
    _expectNoPrepare();
  });

  // Harm: a machine that passes never reaches its installation.
  testWidgets('a passing machine gives Prepare in place of the check', (tester) async {
    await _open(tester, (_) => _passing);
    await _pressCheck(tester);
    _expectPrepareOffered(tester);
    expect(find.text('Check this machine'), findsNothing);
    expect(find.textContaining('passes the check'), findsOneWidget);
  });

  // Harm: the list stays on what was true of another choice, and a fault is missed or a false one stands.
  testWidgets('a CPU without virtualization is a finding with VMs on and none with VMs off', (tester) async {
    final asked = <List<String>>[];
    await _open(tester, (arguments) {
      asked.add(arguments);
      return arguments[arguments.indexOf('--kvm') + 1] == 'true'
          ? _answer([_finding('virtualization', 'fail', found: false, asked: true)])
          : _passing;
    });
    await _pressCheck(tester);
    expect(asked, hasLength(1));
    expect(asked.single, containsAllInOrder(['check', '--given', '192.0.2.7', '--host-key', hostKey, '--public-key']));
    expect(find.byKey(const ValueKey('host-check-finding-virtualization')), findsNothing);
    _expectPrepareOffered(tester);

    await _flipVms(tester);
    expect(asked, hasLength(2), reason: 'the changed choice runs the check again by itself');
    expect(_within('virtualization', 'Fails'), findsOneWidget);
    _expectNoPrepare();

    await _flipVms(tester);
    expect(asked, hasLength(3));
    expect(find.byKey(const ValueKey('host-check-finding-virtualization')), findsNothing);
    _expectPrepareOffered(tester);
  });

  // Harm: a host without a forge still offers its jobs and VMs, as if they meant something there.
  testWidgets('without a forge, neither its jobs nor VMs stand there, and it asks accordingly', (tester) async {
    final asked = <List<String>>[];
    await _open(tester, (arguments) {
      asked.add(arguments);
      return _passing;
    });
    await _pressCheck(tester);
    expect(find.textContaining('builds run here'), findsOneWidget, reason: 'what each choice costs');
    await _flipVms(tester);
    expect(asked.last[asked.last.indexOf('--kvm') + 1], 'true');

    await tester.ensureVisible(find.byKey(const Key('host-forge')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('host-forge')));
    await tester.pump();
    await _rest(tester);
    expect(asked.last[asked.last.indexOf('--forge') + 1], 'false');
    expect(asked.last[asked.last.indexOf('--kvm') + 1], 'false', reason: 'VMs mean nothing without a forge here');
    expect(find.byKey(const Key('host-check-vms')), findsNothing);
    await tester.ensureVisible(find.text('More settings'));
    await tester.tap(find.text('More settings'));
    await World.settle(tester);
    expect(find.byKey(const Key('forge_runner_capacity')), findsNothing);
    expect(find.byKey(const Key('matrix_port')), findsOneWidget);
  });

  // Harm: a refused CPU in the check's own terms, with no way on.
  testWidgets('a CPU without virtualization says so in plain words', (tester) async {
    await _open(tester, (arguments) => _answer([_finding('virtualization', 'fail', found: false, asked: true)]));
    await _pressCheck(tester);
    expect(find.textContaining("This machine's CPU offers no virtualization"), findsOneWidget);
    expect(find.textContaining('turn off This host runs VMs in its jobs'), findsOneWidget);
  });

  // Harm: the check's answer outlives the settings it was given, and Prepare stands on limits never asked about.
  testWidgets('a setting accepted in the form runs the check again with it', (tester) async {
    final asked = <List<String>>[];
    await _open(tester, (arguments) {
      asked.add(arguments);
      return _passing;
    });
    await _pressCheck(tester);
    await tester.ensureVisible(find.text('More settings'));
    await tester.pump();
    await tester.tap(find.text('More settings'));
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('forge_job_cpus')), '4');
    await World.settle(tester);
    await tester.ensureVisible(find.text('Use settings'));
    await World.settle(tester);
    await tester.tap(find.text('Use settings'));
    await tester.pump();
    await _rest(tester);
    expect(asked, hasLength(2));
    expect(asked.last, containsAllInOrder(['--forge-job-cpus', '4']));
  });

  // Harm: a yes about one machine stands as a yes about another.
  testWidgets('changing the address or the key drops the answer and runs the check again', (tester) async {
    final asked = <List<String>>[];
    await _open(tester, (arguments) {
      asked.add(arguments);
      return _passing;
    });
    await _pressCheck(tester);
    _expectPrepareOffered(tester);

    await _type(tester, 'Server address', '192.0.2.8');
    _expectNoPrepare();
    await _rest(tester);
    expect(asked, hasLength(2));
    expect(asked.last, contains('192.0.2.8'));
    _expectPrepareOffered(tester);

    await _type(tester, 'SSH host key', _otherKey);
    _expectNoPrepare();
    await _rest(tester);
    expect(asked, hasLength(3));
    expect(asked.last, contains(_otherKey));
  });

  // Harm: a choice unchanged, or nothing asked yet, starts ssh to a machine before the person pressed anything.
  testWidgets('changing a choice before any answer runs nothing', (tester) async {
    final asked = <List<String>>[];
    await _open(tester, (arguments) {
      asked.add(arguments);
      return _passing;
    });
    await _flipVms(tester);
    expect(asked, isEmpty);
  });

  // Harm: an answer about the old address, arriving late, offers Prepare for the new one.
  testWidgets('an answer that arrives after a change is not taken', (tester) async {
    final first = Completer<Ran>();
    final later = Completer<Ran>();
    var runs = 0;
    await _open(tester, (_) => ++runs == 1 ? first.future : later.future);
    await tester.ensureVisible(find.text('Check this machine'));
    await tester.pump();
    await tester.tap(find.text('Check this machine'));
    await tester.pump();
    expect(find.byKey(const Key('host-check-running')), findsOneWidget);
    await _type(tester, 'Server address', '192.0.2.8');
    await _rest(tester);
    expect(runs, 2);
    first.complete(_passing);
    await World.settle(tester);
    expect(find.textContaining('passes the check'), findsNothing);
    _expectNoPrepare();
    later.complete(_answer([_finding('memory', 'fail', found: 1)]));
    await World.settle(tester);
    expect(_within('memory', 'Fails'), findsOneWidget);
    _expectNoPrepare();
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
    testWidgets('${entry.key} reads as the check not having answered, with no Prepare', (tester) async {
      await _open(tester, entry.value);
      await _pressCheck(tester);
      expect(find.textContaining('The check did not answer'), findsOneWidget);
      _expectNoPrepare();
      expect(find.widgetWithText(FilledButton, 'Check this machine'), findsOneWidget, reason: 'it can be tried again');
    });
  }

  testWidgets('a refused login says what to do', (tester) async {
    await _open(tester, silent['a machine refusing the login']!);
    await _pressCheck(tester);
    expect(find.textContaining('refused the login as root'), findsOneWidget);
  });

  group('whether the check is carried', () {
    Future<HostCheckRun?> carried(FutureOr<Ran> Function() answer) => HostCheckRun(
      executable: 'porelo-host',
      run: (_, arguments, {inDirectory, environment = const {}, input}) async {
        expect(arguments, ['check', '--available']);
        return answer();
      },
    ).ifCarried();

    // Harm: the dialog of today gains a check step that cannot run, on the collection pinned now or an older command.
    test('only exit 0 gives the step; a collection with none, an older command and none at all do not', () async {
      expect(await carried(() => (code: 0, out: '', err: '')), isNotNull);
      expect(await carried(() => (code: 4, out: '', err: '')), isNull);
      expect(await carried(() => (code: 64, out: '', err: 'usage')), isNull);
      expect(await carried(() => throw const ProcessException('porelo-host', [])), isNull);
    });
  });
}

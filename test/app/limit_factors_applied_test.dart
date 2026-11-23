import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/connection_trial.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/newer_version.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';
import 'package:porelo_frontend/src/wire/limit_factors.dart';

/// A machine whose daemon never answers.
class _Silent extends Fake implements FleetBackend {
  @override
  Future<ServiceInfo> open() => Completer<ServiceInfo>().future;
}

void main() {
  tearDown(() {
    machineLimits
      ..forget('slow-box')
      ..forget('here')
      ..local = null;
  });

  // Harm: a slow machine's factor of 2 does not reach the wait for its answer, so the window gives up on it as early
  // as on a fast one.
  test('a services factor of 2 doubles the wait for a machine to answer a trial', () async {
    machineLimits.keep('slow-box', 'services=2.0', LimitFactors.parse('services=2.0'));
    final tunnels = Tunnels();
    addTearDown(tunnels.dispose);
    final waited = Stopwatch()..start();

    final trial = await tryAMachine(
      Machine(name: 'slow-box', socketPath: '/nowhere/slow-box.sock'),
      reach: (_) => _Silent(),
      tunnels: tunnels,
      within: const Duration(milliseconds: 300),
    );

    expect(trial.reached, isFalse);
    expect(waited.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 600)));
  });

  // Harm: every call to a slow machine's daemon gives up as early as on a fast one, so its work reads as broken.
  test('a services factor of 2 doubles the wait for a machine\'s daemon to answer a call', () async {
    machineLimits.keep('slow-box', 'services=2.0', LimitFactors.parse('services=2.0'));
    final daemon = MockDaemon();
    await daemon.start();
    addTearDown(daemon.stop);
    daemon.neverAnswers('List');
    final client = await PoreloClient.connect(
      Backend(socketPath: daemon.socketPath, label: 'mock'),
      answerWithin: const Duration(milliseconds: 300),
      machine: 'slow-box',
    );
    final waited = Stopwatch()..start();

    await expectLater(client.tasks(), throwsA(isA<VarlinkDisconnected>()));
    expect(waited.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 600)));
  });

  // Harm: a factor counts more than once, so a wait for ssh is longer than any factor asks for.
  test('whole seconds and tries follow a factor exactly, rounded up only past a whole one', () {
    machineLimits
      ..local = 'here'
      ..keep('here', 'machines=1.1', LimitFactors.parse('machines=1.1'));
    expect(machineSeconds(10), 11);
    expect(machineTries(50), 55);
    expect(machineSeconds(15), 17);
  });

  // Harm: a computer whose Porelo asks for slower polling is looked at as often as by default all the same.
  test('a polling factor of 2 makes a look every minute one every two', () {
    machineLimits
      ..local = 'here'
      ..keep('here', 'polling=2.0', LimitFactors.parse('polling=2.0'));
    final folder = Directory.systemTemp.createTempSync('newer-version-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final binary = File('${folder.path}/binary')..writeAsStringSync('old');
    binary.setLastModifiedSync(DateTime(2026));

    fakeAsync((time) {
      final newer = NewerVersion(what: binary, every: const Duration(minutes: 1))..watch();
      binary.setLastModifiedSync(DateTime(2026, 2));
      time.elapse(const Duration(seconds: 90));
      expect(newer.arrived, isFalse, reason: 'looked after one minute, the default');
      time.elapse(const Duration(seconds: 31));
      expect(newer.arrived, isTrue, reason: 'not looked after two minutes');
      newer.dispose();
    });
  });

  // Harm: a slow computer's factor of 2 does not reach the wait for a closed terminal's program, which then counts as
  // hanging while it is still ending.
  test('a machines factor of 2 doubles how long a closed terminal\'s program is given to end', () async {
    machineLimits
      ..local = 'here'
      ..keep('here', 'machines=2.0', LimitFactors.parse('machines=2.0'));

    await expectLater(
      endedAfterClose(Completer<int>().future, Completer<Object?>().future, bound: const Duration(milliseconds: 50)),
      throwsA(
        isA<TerminalStillRunning>().having((error) => error.duration, 'bound', const Duration(milliseconds: 100)),
      ),
    );
  });
}

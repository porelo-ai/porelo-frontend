import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_check_run.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/wire/limit_factors.dart';
import 'package:porelo_host/porelo_host.dart' show hostLimits;

import '../support/host_process.dart';

/// porelo-host follows this computer's limits line, whether started as its own program or used in the window.
void main() {
  const line = 'services=2.0,machines=3.0';

  void givenHere() {
    machineLimits
      ..local = 'here'
      ..keep('here', line, LimitFactors.parse(line));
  }

  tearDown(() {
    machineLimits
      ..forget('here')
      ..local = null;
  });

  // Harm: ssh and the check the window runs through the host package give up on a slow machine as early as on a
  // fast one.
  test('the factors of this computer\'s own machine govern the host package in the window', () {
    givenHere();
    expect(hostLimits, LimitFactors.parse(line));
    machineLimits.forget('here');
    expect(hostLimits, LimitFactors.standard);
    machineLimits.keep('elsewhere', 'machines=5.0', LimitFactors.parse('machines=5.0'));
    addTearDown(() => machineLimits.forget('elsewhere'));
    expect(hostLimits, LimitFactors.standard, reason: 'another machine\'s factors are not this computer\'s');
  });

  // Harm: porelo-host started by the window waits for a slow server as briefly as for a fast one.
  test('a setup run is given this computer\'s limits line before its verb', () async {
    givenHere();
    final started = <List<String>>[];
    final session = HostSession(
      executable: 'fake',
      arguments: const ['--host-name', 'orchard'],
      start: (_, arguments) async {
        started.add(arguments);
        return HostProcess()..end(0);
      },
    );
    addTearDown(session.dispose);
    await session.up();
    expect(started.single.take(3), ['--limits', line, 'up']);
  });

  test('the carried check is asked with the line before its verb', () async {
    givenHere();
    final asked = <List<String>>[];
    await HostCheckRun(
      executable: 'fake',
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        asked.add(arguments);
        return (code: 4, out: '', err: '');
      },
    ).carried();
    expect(asked.single, ['--limits', line, 'check', '--available']);
  });

  test('checking the provider key passes the line before its verb', () async {
    givenHere();
    final started = <List<String>>[];
    await checkHostScalewayKey(
      start: (_, arguments) async {
        started.add(arguments);
        return HostProcess()..end(0);
      },
    );
    expect(started.single, ['--limits', line, 'key', 'check', 'scaleway']);
  });

  test('a key set in a terminal is given the line before its verb', () {
    givenHere();
    expect(poreloHostCommandLine(['key', 'set', 'scaleway']).skip(1), ['--limits', line, 'key', 'set', 'scaleway']);
  });

  // Harm: a machine that gave no line is started with one made up here.
  test('without a line of its own machine, porelo-host is given none', () async {
    final started = <List<String>>[];
    await checkHostScalewayKey(
      start: (_, arguments) async {
        started.add(arguments);
        return HostProcess()..end(0);
      },
    );
    expect(started.single, ['key', 'check', 'scaleway']);
  });
}

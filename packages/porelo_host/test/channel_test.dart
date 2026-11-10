import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' as cli;

void main() {
  // Harm: a snapshot, a pre-release or a build with an empty version prepares hosts from releases.
  test('only a plain release version installs from releases', () {
    expect(cli.channelOf('0.6.0'), 'releases');
    expect(cli.channelOf('10.20.30'), 'releases');
    for (final version in [
      '',
      'unreleased',
      '0.5.1-SNAPSHOT',
      '0.6.0~snapshot.41',
      '0.6.0-rc.1',
      '0.6.0~rc1',
      '0.6.0+1',
      'v0.6.0',
      '0.6',
      ' 0.6.0',
      '0.6.0\n',
    ]) {
      expect(cli.channelOf(version), 'snapshots', reason: 'version "$version"');
    }
  });

  // Harm: a build from source says a version it was not built as, or installs from releases.
  test('a build with no version compiled in says unreleased', () async {
    final output = StringBuffer();
    expect(await cli.runHostCommand(['--version'], output: output, errors: StringBuffer()), Exit.done);
    expect(output.toString(), 'unreleased\n');
    expect(cli.channelOf(output.toString().trim()), 'snapshots');
  });

  // Harm: porelo-host says another version than the one it decides its channel by.
  test('porelo-host says the version it was built as', () async {
    final output = StringBuffer();
    expect(
      await cli.runHostCommand(['--version'], output: output, errors: StringBuffer(), version: '0.5.1'),
      Exit.done,
    );
    expect(output.toString(), '0.5.1\n');
  });

  // Harm: a mistyped channel is found only after work started, or never when a host is given back by project.
  test('porelo-host refuses an unknown --distribution as a usage error', () async {
    final errors = StringBuffer();
    expect(
      await cli.runHostCommand(
        ['down', '--project', 'p', '--account', 'a', '--distribution', 'nightly'],
        output: StringBuffer(),
        errors: errors,
      ),
      Exit.usage,
    );
    expect(errors.toString(), contains('--distribution needs snapshots or releases'));
  });

  // Harm: a plan for a project's host goes ahead with a channel no host can install from.
  test('a host plan refuses an unknown distribution with or without a server name', () {
    for (final plan in [
      const HostPlan(project: 'p', account: 'a', publicKey: '', distribution: 'nightly'),
      const HostPlan(hostName: 'h', loginUser: 'root', publicKey: '', distribution: 'nightly'),
    ]) {
      expect(() => plan.check(forSetup: false), throwsFormatException, reason: 'host ${plan.hostName}');
    }
  });
}

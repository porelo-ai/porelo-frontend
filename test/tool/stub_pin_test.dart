// Linux only: it runs tool/stub_pin.sh in Bash.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds tool/stub_pin.sh to saying ahead when the stub the scenarios pin is about to leave its folder, which keeps
/// the newest 20 versions.
///
/// The harm: a pin falls out after 20 Builds, and the scenarios that need the stub go red on a fresh machine with
/// nothing having said so before.
void main() {
  late Directory scratch;

  setUp(() => scratch = Directory.systemTemp.createTempSync('stub-pin-'));
  tearDown(() => scratch.deleteSync(recursive: true));

  /// The pin as the step names it.
  final pin = RegExp(r"version: '([^']+)'")
      .firstMatch(File('integration_test/step/the_test_machine_has_porelos_stub_agent.dart').readAsStringSync())!
      .group(1)!;
  final base = int.parse(pin.split('.').last);
  final prefix = pin.substring(0, pin.lastIndexOf('.') + 1);

  /// Runs it against a listing of the folder holding [versions], as Artifactory answers it.
  ProcessResult run(Iterable<String> versions) {
    final listing = File('${scratch.path}/listing.json')
      ..writeAsStringSync(
        '{"repo":"porelo-dist-test","children":[${versions.map((each) => '{"uri":"/$each","folder":true}').join(',')}]}',
      );
    return Process.runSync('bash', <String>['tool/stub_pin.sh', listing.path]);
  }

  List<String> withNewer(int count) => [for (var each = 0; each <= count; each++) '$prefix${base + each}'];

  test('a pin with few newer versions is said nothing of', () {
    final ran = run(withNewer(5));
    expect(ran.exitCode, 0);
    expect(ran.stderr, isEmpty);
  });

  test('a pin with 15 newer versions is named to move before it falls out', () {
    final ran = run(withNewer(15));
    expect(ran.exitCode, 0, reason: 'it says so, and stops no run');
    expect(ran.stderr, allOf(contains(pin), contains('15 newer'), contains('move')));
  });

  test('a pin the folder no longer holds is said gone', () {
    final ran = run(['$prefix${base + 1}', '$prefix${base + 2}']);
    expect(ran.exitCode, 0);
    expect(ran.stderr, allOf(contains(pin), contains('no longer holds it')));
  });

  test('the newest is told apart by version, not by its spelling', () {
    // By their letters, snapshot.1000 and on sort before a pin of three digits.
    final ran = run([pin, for (var each = 0; each < 15; each++) '$prefix${1000 + base + each}']);
    expect(ran.stderr, contains('15 newer'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// What a machine says about itself, held to the contract rather than to a screen.
///
/// **`ready` is the daemon's answer and is never re-derived here.** It is the same rule the CLI
/// exits non-zero on, so the two cannot come to different conclusions about one machine — and the
/// case that proves it is a daemon newer than this build.
void main() {
  Health healthWith(List<Map<String, dynamic>> probes, {required bool ready}) =>
      Health.from(<String, dynamic>{'probes': probes, 'ready': ready});

  Map<String, dynamic> probe(String name, String state) => <String, dynamic>{
        'name': name,
        'state': state,
        'detail': 'what was found',
        'action': state == 'OK' ? '' : 'do the one thing',
      };

  test('a state this build has never heard of still stops the machine, if the daemon says so', () {
    // A later release adds a state that blocks. This build does not know it and must not decide
    // for itself that the machine is fine — which is exactly what re-deriving `ready` from the
    // probes would do, since only MISSING is known here.
    final health = healthWith(
      <Map<String, dynamic>>[probe('podman', 'OK'), probe('a new check', 'BLOCKED')],
      ready: false,
    );

    expect(health.ready, isFalse);
    // And it renders rather than throwing: an unknown value is shown as itself.
    expect(health.probes.last.label, 'blocked');
    expect(health.worthReading, hasLength(1));
  });

  test('unknown is its own answer, never the good case', () {
    final health = healthWith(
      <Map<String, dynamic>>[probe('SELinux policy', 'UNKNOWN')],
      ready: true,
    );

    // A probe that guesses well is indistinguishable from one that works, so this is not fine.
    expect(health.probes.single.fine, isFalse);
    expect(health.readyWithCaveats, isTrue);
  });

  test('degraded leaves a machine running work', () {
    final health = healthWith(
      <Map<String, dynamic>>[probe('rootless network backend', 'DEGRADED')],
      ready: true,
    );

    expect(health.ready, isTrue);
    expect(health.readyWithCaveats, isTrue);
  });

  test('nothing wrong is told apart from nothing worth reading', () {
    final health = healthWith(
      <Map<String, dynamic>>[probe('podman', 'OK')],
      ready: true,
    );

    expect(health.readyWithCaveats, isFalse);
    expect(health.worthReading, isEmpty);
  });
}

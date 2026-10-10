import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/src/app/newer_version.dart';

/// A package upgrade replaces the binary under a running interface, so what somebody has open is
/// quietly out of date — with a bug they are about to report already fixed in what is installed.
void main() {
  late File binary;

  setUp(() {
    binary = File('${Directory.systemTemp.path}/sokar-build-${DateTime.now().microsecondsSinceEpoch}');
    binary.writeAsStringSync('the build that is running');
    addTearDown(() => binary.existsSync() ? binary.deleteSync() : null);
  });

  test('nothing is claimed while the build is the one that started', () {
    final watching = NewerVersion(what: binary)..watch();

    watching.lookNow();

    expect(watching.arrived, isFalse);
    watching.dispose();
  });

  test('a build installed underneath is noticed', () {
    final watching = NewerVersion(what: binary)..watch();

    binary.setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));
    watching.lookNow();

    expect(watching.arrived, isTrue);
    watching.dispose();
  });

  test('a binary that cannot be read claims nothing either way', () {
    // Running from a place that is gone, or read-only in a way stat cannot see. Saying "up to
    // date" would be as wrong as saying "out of date".
    final watching = NewerVersion(what: File('${Directory.systemTemp.path}/nothing-is-here-at-all'))..watch();

    watching.lookNow();

    expect(watching.arrived, isFalse);
    watching.dispose();
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: porelo doctor will refuse with {'podman 4.9.3 is too old'}
///
/// Shaped like what `doctor` printed on a rented Ubuntu 24.04: the refusal, its advice, and a
/// DEGRADED line that a machine passing `doctor` has as well.
Future<void> poreloDoctorWillRefuseWith(WidgetTester tester, String why) async {
  World.setup.doctorRefuses = ProcessResult(
    0,
    69,
    'podman              MISSING - $why\n'
        '                    -> run podman version as this user and fix what it reports\n'
        'git                 2.43.0\n'
        'configuration key   DEGRADED - none pinned\n',
    '',
  );
}

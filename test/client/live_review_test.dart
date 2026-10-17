import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/gate.dart';

/// Opens a waiting push on a real machine as the interface's gate view does - without naming what to
/// compare it with - and holds that every file the push changes is in the review, not the last
/// commit's alone, which is what a review without `against` used to show.
///
/// Runs only when `PORELO_SOCKET` names a daemon's socket, `PORELO_REVIEW_PROJECT` a project with a
/// waiting push, `PORELO_REVIEW_PUSH` its name, and `PORELO_REVIEW_FILES` the files its commits change,
/// comma-separated.
void main() {
  final socket = Platform.environment['PORELO_SOCKET'] ?? '';
  final project = Platform.environment['PORELO_REVIEW_PROJECT'] ?? '';
  final name = Platform.environment['PORELO_REVIEW_PUSH'] ?? '';
  final files = (Platform.environment['PORELO_REVIEW_FILES'] ?? '')
      .split(',')
      .where((each) => each.isNotEmpty)
      .toList();
  final skip = socket.isEmpty || project.isEmpty || name.isEmpty || files.isEmpty
      ? 'needs PORELO_SOCKET, PORELO_REVIEW_PROJECT, PORELO_REVIEW_PUSH and PORELO_REVIEW_FILES'
      : null;

  test('a push of several commits is reviewed whole, as the gate view opens it', () async {
    final backend = PoreloBackend(Backend(socketPath: socket, label: 'live'));
    await backend.open();
    final listed = (await backend.projects()).singleWhere((each) => each.name == project);
    final gate = Gate();

    await gate.lookAt(backend, listed);
    final push = gate.waiting.singleWhere((each) => each.name == name);
    await gate.look(backend, push);

    // ignore: avoid_print
    print([for (final each in gate.ranked) each.path].join(', '));
    expect(gate.problem, isNull);
    expect([for (final each in gate.ranked) each.path], containsAll(files));
    gate.dispose();
  }, skip: skip);
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/gate.dart';

/// The two refusals a real machine answers by name for work that already exists, said in words.
///
/// Forwards a waiting push onto a branch that already holds other work, as the interface's gate view
/// does, and holds that nothing was forwarded: the push still waits. Runs only when `PORELO_SOCKET`
/// names a daemon's socket, `PORELO_TAKEN_PROJECT` a project with a waiting push, `PORELO_TAKEN_PUSH`
/// its name, and `PORELO_TAKEN_BRANCH` a branch at its upstream that holds a commit the push did not
/// grow from.
///
/// Starts a new task under a name whose earlier work waits at the gate, as the interface starts work,
/// and holds that the start is refused naming that work, before anything is created. Runs only when
/// `PORELO_SOCKET`, `PORELO_EARLIER_PROJECT`, `PORELO_EARLIER_REPOSITORY` and `PORELO_EARLIER_TASK` name
/// such a task: no container of that name, its incoming ref holding a commit, in a class other than
/// online.
void main() {
  final socket = Platform.environment['PORELO_SOCKET'] ?? '';
  final earlierProject = Platform.environment['PORELO_EARLIER_PROJECT'] ?? '';
  final earlierRepository = Platform.environment['PORELO_EARLIER_REPOSITORY'] ?? '';
  final earlierTask = Platform.environment['PORELO_EARLIER_TASK'] ?? '';

  test(
    'a new task whose earlier work waits is refused in words, naming that work',
    () async {
      final backend = PoreloBackend(Backend(socketPath: socket, label: 'live'));
      await backend.open();
      Object? refused;
      try {
        // A shell with a named agent, as new work is started from the interface: with several agents
        // installed one has to be named, and a shell needs no credential, so neither refuses first.
        await backend
            .startTask(
              task: earlierTask,
              project: earlierProject,
              repository: earlierRepository,
              agent: Platform.environment['PORELO_EARLIER_AGENT'],
              mode: Mode.shell,
            )
            .drain<void>();
      } on Object catch (error) {
        refused = error;
      }

      // ignore: avoid_print
      print(refused);
      expect(refused, isA<EarlierWorkWaits>());
      expect('$refused', contains('$earlierTask was not started: its earlier work'));
      expect('$refused', contains('still waits at the gate'));
    },
    skip: socket.isEmpty || earlierProject.isEmpty || earlierRepository.isEmpty || earlierTask.isEmpty
        ? 'needs PORELO_SOCKET, PORELO_EARLIER_PROJECT, PORELO_EARLIER_REPOSITORY and PORELO_EARLIER_TASK'
        : null,
  );

  final project = Platform.environment['PORELO_TAKEN_PROJECT'] ?? '';
  final name = Platform.environment['PORELO_TAKEN_PUSH'] ?? '';
  final branch = Platform.environment['PORELO_TAKEN_BRANCH'] ?? '';
  final skip = socket.isEmpty || project.isEmpty || name.isEmpty || branch.isEmpty
      ? 'needs PORELO_SOCKET, PORELO_TAKEN_PROJECT, PORELO_TAKEN_PUSH and PORELO_TAKEN_BRANCH'
      : null;

  test('a push forwarded onto a taken branch is refused in words, and still waits', () async {
    final backend = PoreloBackend(Backend(socketPath: socket, label: 'live'));
    await backend.open();
    final listed = (await backend.projects()).singleWhere((each) => each.name == project);
    final gate = Gate();

    await gate.lookAt(backend, listed);
    await gate.look(backend, gate.waiting.singleWhere((each) => each.name == name));
    final said = await gate.approve(backend, branch);

    // ignore: avoid_print
    print(said);
    expect(said, contains('$branch already holds'));
    expect(said, contains('Nothing was forwarded'));
    expect(said, contains('such as $branch-2'));
    await gate.lookAt(backend, listed);
    expect(gate.waiting.map((each) => each.name), contains(name));
    gate.dispose();
  }, skip: skip);
}

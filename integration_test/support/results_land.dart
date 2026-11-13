import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'idea_walk.dart';

/// The issues of the story whose reading stopped on blocking findings, as the planner named them once its readings
/// ended: kept in the walk's state from then on, since the planner names them no more once the person chose. Fails
/// where none was kept, as a later step that expects them would otherwise pass over nothing.
Future<List<({String id, String repository})>> theStoppedIssues() async {
  if (Walk.stopped.isEmpty) {
    fail('no issue whose reading stopped on blocking findings was kept by the step that reads the stopped reading');
  }
  return Walk.stopped;
}

/// A fresh clone of the forge's repository [repository], every branch of it, made apart from everything the window and
/// its tasks use, with the run's own git configuration for its credentials; removed when the scenario ends.
Future<Directory> aFreshClone(String repository) async {
  final into = await Directory.systemTemp.createTemp('results-land-');
  addTearDown(() => into.delete(recursive: true));
  await git(['clone', '--quiet', '--no-single-branch', Walk.urlOf(repository), into.path]);
  return into;
}

/// Runs git with [arguments], in [where] where given, and answers what it printed; fails saying what it asked.
Future<String> git(List<String> arguments, {Directory? where}) async {
  final ran = await Process.run(
    'git',
    ['-c', 'credential.interactive=never', ...arguments],
    workingDirectory: where?.path,
    environment: {'GIT_TERMINAL_PROMPT': '0'},
  );
  if (ran.exitCode != 0) fail('asked git ${arguments.join(' ')}; got exit ${ran.exitCode}: ${ran.stderr}');
  return '${ran.stdout}'.trim();
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'idea_walk.dart';

/// What the story of a task's results shares: the issues whose reading stopped on blocking findings.
abstract final class ResultsLand {
  /// The issues whose reading stopped on the reader's blocking findings, with their repositories, once they were read.
  static List<({String id, String repository})> blocked = [];
}

/// The issues of the story whose reading stopped on blocking findings, as the planner says: kept from the step that
/// read them, or asked again on a resume.
Future<List<({String id, String repository})>> theBlockedIssues() async {
  if (ResultsLand.blocked.isNotEmpty) return ResultsLand.blocked;
  return ResultsLand.blocked = [
    for (final issue in Walk.issues)
      if (await probeHolds(['attention', issue.id, 'BLOCKING_FINDINGS'])) (id: issue.id, repository: issue.repository),
  ];
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

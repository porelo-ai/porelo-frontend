import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'idea_walk.dart';

/// What the story of a task's results shares: where the project's setting puts findings, and what was found there.
abstract final class ResultsLand {
  /// The place the project's setting names for findings, relative to a repository's top, once it was read.
  static String? place;

  /// Each issue repository with the commit that added a findings file there, once it was found.
  static Map<String, String> added = {};
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

/// The commits of every branch of [clone] that [filter] (`A` added, `D` deleted) a file under [place], newest first.
Future<List<String>> theCommitsThat(Directory clone, String filter, String place) async {
  final listed = await git(['log', '--remotes', '--diff-filter=$filter', '--format=%H', '--', place], where: clone);
  return listed.isEmpty ? const [] : listed.split('\n');
}

import 'dart:convert';
import 'dart:io';

import 'package:porelo_planning/porelo_planning.dart' show PlannerNotProven, PlanningRefusal;

import 'planner.dart' show LocalPlanner;
import 'planner_call.dart';

/// What a planner that answered says of its own build: the version of its package and the commit it was built from,
/// each null where it names none.
final class PlannerBuild {
  /// Takes what the planner named.
  const PlannerBuild({this.version, this.commit});

  /// The package's version, `x.y.z` or `x.y.z~snapshot.<run>`; null where the planner names none.
  final String? version;

  /// The full commit the planner was built from; null where its build had no checkout or it names no version.
  final String? commit;

  @override
  bool operator ==(Object other) => other is PlannerBuild && other.version == version && other.commit == commit;

  @override
  int get hashCode => Object.hash(version, commit);

  @override
  String toString() => 'PlannerBuild($version, $commit)';
}

/// The planner's line in About: the build [build] names, the commit by its first twelve characters, or in words why
/// it names none, null being no planner reached.
String plannerInAbout(PlannerBuild? build) => switch (build) {
  null => 'planner: not reached',
  PlannerBuild(:final version?, :final commit?) =>
    'planner: ${LocalPlanner.name} $version (${commit.length > 12 ? commit.substring(0, 12) : commit})',
  PlannerBuild(:final version?) => 'planner: ${LocalPlanner.name} $version',
  _ => 'planner: ${LocalPlanner.name} says no version',
};

/// Asks the planner of this account what it was built as, answering null where no planner can be reached.
typedef AskPlannerBuild = Future<PlannerBuild?> Function({String? runtimeDirectory});

/// A planner that can be asked what it was built as.
abstract interface class NamesItsBuild {
  /// What the planner says of its build, or null where the window reaches no planner.
  Future<PlannerBuild?> build();
}

/// The planner's `GET /health`, at the address its `planner.json` under [runtimeDirectory] names: what it says of its
/// build, or null where no planner of this account can be reached.
///
/// Through [callOwnPlanner]: signed under the address file's token, only to a listener that proved it, never through a
/// proxy, so the token itself is never sent; an answer is waited for [within] and read up to 64 KiB.
Future<PlannerBuild?> askPlannerBuild({String? runtimeDirectory, Duration within = const Duration(seconds: 5)}) async {
  try {
    final answer = await callOwnPlanner(
      'GET',
      const ['health'],
      runtimeDirectory: runtimeDirectory,
      within: within,
      maxBody: 64 * 1024,
    );
    return plannerBuildAnswered(answer.status, utf8.decode(answer.body, allowMalformed: true));
  } on PlannerNotProven {
    // A listener that cannot prove the token is no planner of this account's.
    return null;
  } on PlanningRefusal catch (refusal) {
    // A planner that answered past the bound was reached, and names no build.
    return refusal.name == 'AnswerTooLarge' ? const PlannerBuild() : null;
  } on Exception {
    // No address file to read, or none of this account's.
    return null;
  }
}

/// What the planner's answer [status] and [body] to `/health` say of its build: `version` a package version and
/// `commit` 40 hex digits, else none; an older answer, a version of another shape or any other status names none.
PlannerBuild plannerBuildAnswered(int status, String body) {
  if (status != HttpStatus.ok) return const PlannerBuild();
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return const PlannerBuild();
  }
  return switch (json) {
    {'version': final String version} when _version.hasMatch(version) => PlannerBuild(
      version: version,
      // A commit that is no full commit is dropped alone: the version still tells which build answers.
      commit: switch (json['commit']) {
        final String commit when _commit.hasMatch(commit) => commit,
        _ => null,
      },
    ),
    _ => const PlannerBuild(),
  };
}

// The package's version as its .deb and .rpm carry it; anything else is not shown, being text from another program.
final _version = RegExp(r'^[0-9]{1,9}\.[0-9]{1,9}\.[0-9]{1,9}(~snapshot\.[0-9]{1,9})?$');

final _commit = RegExp(r'^[0-9a-f]{40}$');

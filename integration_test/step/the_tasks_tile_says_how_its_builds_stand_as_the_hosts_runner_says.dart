import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: the task's tile says how its builds stand, as the host's runner says
Future<void> theTasksTileSaysHowItsBuildsStandAsTheHostsRunnerSays(WidgetTester tester) => pictured(tester, () async {
  // The host's runner builds the forwarded commit and the host's daemon reads it onto the task; the tile is to say
  // that build, by its commit, and not "not followed" or "no build yet".
  Map<String, dynamic>? build;
  await pumpUntil(
    tester,
    () async {
      final task = (await theProjectsTasksOnTheHost()).where((t) => t['name'] == Rehearsal.waitingTask).firstOrNull;
      final builds = (task?['builds'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
      build = builds.where((b) => b['commit'] == Rehearsal.reviewedCommit).firstOrNull;
      return build != null;
    },
    timeout: const Duration(minutes: 10),
    what: "the host to read the build of ${Rehearsal.reviewedCommit}",
  );
  final short = Rehearsal.reviewedCommit!.substring(0, 12);
  await toThePlace(tester, 'work');
  final tile = theTileOf(Rehearsal.waitingTask!);
  await pumpUntil(tester, () => tile.evaluate().isNotEmpty, what: 'the tile of ${Rehearsal.waitingTask}');
  final line = find.descendant(of: tile.first, matching: find.byKey(const Key('tile-build-headline')));
  await pumpUntil(
    tester,
    () => line.evaluate().isNotEmpty && theWordsUnder(tester, tile.first).contains(short),
    timeout: const Duration(minutes: 2),
    what: 'the tile to say the build of $short (the host: ${build?['verdict']})',
  );
  final said = theWordsUnder(tester, line.first);
  expect(said, isNot(anyOf(contains('Builds not followed'), contains('No build yet'))), reason: 'the host read $build');
  final verdict = build!['verdict'] as String;
  if (verdict == 'failure') expect(said, contains('failed'), reason: 'the host says it failed');
  if (verdict == 'success') expect(said, isNot(contains('failed')), reason: 'the host says it passed');
});

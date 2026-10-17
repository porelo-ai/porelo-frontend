import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/builds.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

/// Follows a running online task's builds on a real machine through `Watch`, as the tile does.
///
/// Runs only when `PORELO_SOCKET` names a daemon's socket, `PORELO_BUILD_TASK` an online task whose
/// pushes a reader follows, and `PORELO_BUILD_TILE` what its tile must come to say; the person running
/// it moves the build along at the forge (or in the stub reader's answers) between runs.
void main() {
  final socket = Platform.environment['PORELO_SOCKET'] ?? '';
  final task = Platform.environment['PORELO_BUILD_TASK'] ?? '';
  final tile = Platform.environment['PORELO_BUILD_TILE'] ?? '';
  final detail = Platform.environment['PORELO_BUILD_DETAIL'] ?? '';

  test('Watch brings the task\'s builds to what its tile must say', () async {
    final backend = PoreloBackend(Backend(socketPath: socket, label: 'live'));
    await backend.open();
    final seen = <String>[];
    final reached = Completer<Task>();
    final watching = backend.watch().listen((tasks) {
      final mine = tasks.where((each) => each.name == task).firstOrNull;
      if (mine == null) return;
      final line = BuildsSaid.onTheTile(mine);
      final said = line == null ? '(nothing about builds)' : '${line.headline} · ${line.detail}';
      if (seen.isEmpty || seen.last != said) seen.add(said);
      if (said.contains(tile) && !reached.isCompleted) reached.complete(mine);
    });
    try {
      // The helper asks the reader every 20 seconds; three rounds and a margin, then it fails.
      final mine = await reached.future.timeout(const Duration(seconds: 75),
          onTimeout: () => fail('the tile never said "$tile"; it said, in turn: ${seen.join(' | ')}'));
      if (detail.isNotEmpty) {
        expect(BuildsSaid.inTheDetail(mine).join('\n'), contains(detail));
      }
    } finally {
      await watching.cancel();
    }
  }, timeout: const Timeout(Duration(seconds: 90)), skip: socket.isEmpty || task.isEmpty || tile.isEmpty
      ? 'needs PORELO_SOCKET, PORELO_BUILD_TASK and PORELO_BUILD_TILE, an online task a reader follows'
      : null);
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/window_log.dart';

import '../features/support/world.dart';

class _Silent extends FakeBackend {
  _Silent() : super(const []);

  @override
  Future<ServiceInfo> open() => throw const VarlinkDisconnected('nothing there');
}

void main() {
  // Harm: a row taken off Needs you leaves no trace, so a person who put it away by mistake, or comes back after a
  // restart, cannot find what it said.
  test('a row Needs you no longer shows is written to the log at INFO, once', () async {
    final scratch = Directory.systemTemp.createTempSync('attention-log-');
    final before = windowLog;
    windowLog = WindowLog('${scratch.path}/logs', keepPrivate: (_) async {});
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => _Silent(), tunnels: FakeTunnels());
    final attention = Attention(machines);
    addTearDown(() {
      attention.dispose();
      machines.dispose();
      settings.dispose();
      windowLog = before;
      scratch.deleteSync(recursive: true);
    });
    const orchard = Machine(name: 'orchard', socketPath: '/tmp/orchard.sock');
    await machines.add(orchard);
    await machines.of(machines.all.firstWhere((each) => each.name == 'orchard')).untilAsked();
    expect(attention.openRows.map((row) => row.id), contains('silent orchard'));

    await attention.markSeen(machines.all.firstWhere((each) => each.name == 'orchard'));
    expect(attention.openRows.map((row) => row.id), isNot(contains('silent orchard')));

    final lines = File('${scratch.path}/logs/${WindowLog.fileName}').readAsLinesSync();
    final said = lines.where((line) => line.contains('silent orchard')).toList();
    expect(said, hasLength(1), reason: 'the row is said once, when it leaves');
    expect(said.single, contains(' INFO  [orchard] '));
  });
}

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
  late Directory scratch;
  late WindowLog before;
  setUp(() {
    scratch = Directory.systemTemp.createTempSync('attention-log-');
    before = windowLog;
    windowLog = WindowLog('${scratch.path}/logs', keepPrivate: (_) async {});
  });
  tearDown(() {
    windowLog = before;
    scratch.deleteSync(recursive: true);
  });

  /// What Needs you wrote to the log.
  List<String> said() {
    final file = File('${scratch.path}/logs/${WindowLog.fileName}');
    if (!file.existsSync()) return const <String>[];
    return file.readAsLinesSync().where((line) => line.contains('Needs you: ')).toList();
  }

  // Harm: a row taken off Needs you leaves no trace, so a person who put it away by mistake, or comes back after a
  // restart, cannot find what it said; and a row that only flickers while its machine is tried again fills the log
  // with rows nobody put away.
  test('a silent machine tried again writes nothing; Seen on it writes once what it said', () async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(
      settings,
      reach: (_) => _Silent(),
      tunnels: FakeTunnels(),
      retryAfter: const Duration(milliseconds: 5),
    );
    final attention = Attention(machines);
    addTearDown(() {
      attention.dispose();
      machines.dispose();
      settings.dispose();
    });
    await machines.add(const Machine(name: 'orchard', socketPath: '/tmp/orchard.sock'));
    final orchard = machines.all.firstWhere((each) => each.name == 'orchard');
    await machines.of(orchard).untilAsked();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(said(), isEmpty, reason: 'nothing was put away or resolved while the machine was tried again');

    await attention.markSeen(orchard);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(said(), hasLength(1));
    expect(said().single, contains(' INFO  [orchard] Needs you: put away '));
    expect(said().single, contains('cannot be reached'), reason: 'the line holds what the row said');
  });

  test('a question answered writes once that it was resolved, with what it asked', () async {
    final backend = FakeBackend(World.work)..nodeId = 'here';
    final settings = Settings(MemorySettingsStore());
    await settings.load();
    final machines = Machines(settings, reach: (_) => backend, tunnels: FakeTunnels());
    await machines.of(machines.current).untilAsked();
    final attention = Attention(machines, settings);
    addTearDown(() {
      attention.dispose();
      machines.dispose();
      settings.dispose();
    });
    final asked = World.blocked('api.example.test:443');
    backend.asking.add(asked);
    await pumpEventQueue();
    backend.asking.add(World.settled(asked, 'allow'));
    await pumpEventQueue();
    backend.publish(backend.tasksNow);
    await pumpEventQueue();
    final resolved = said().where((line) => line.contains('Needs you: resolved ')).toList();
    expect(resolved, hasLength(1), reason: 'said: ${said()}');
    expect(resolved.single, contains('api.example.test'));
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/operations.dart';
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
    scratch = Directory.systemTemp.createTempSync('window-log-lines-');
    before = windowLog;
    windowLog = WindowLog('${scratch.path}/logs', keepPrivate: (_) async {});
  });
  tearDown(() {
    windowLog = before;
    scratch.deleteSync(recursive: true);
  });

  List<String> logged() {
    final file = File('${scratch.path}/logs/${WindowLog.fileName}');
    return file.existsSync() ? file.readAsLinesSync() : const <String>[];
  }

  // Harm: a machine that could not be reached while nobody looked leaves only a status line the next connection
  // overwrites, so why it went silent cannot be found afterwards.
  test('a call to a machine that failed is written at WARN, about that machine', () async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => _Silent(), tunnels: FakeTunnels());
    addTearDown(() {
      machines.dispose();
      settings.dispose();
    });
    await machines.add(const Machine(name: 'orchard', socketPath: '/tmp/orchard.sock'));
    await machines.of(machines.all.firstWhere((each) => each.name == 'orchard')).untilAsked();
    expect(
      logged().where((line) => line.contains(' WARN  [orchard] ') && line.contains('nothing there')),
      hasLength(1),
    );
  });

  // Harm: an operation that failed is put away from Needs you, and then nothing says it ever ran or how it ended.
  test('an operation is written when it starts and when it ends, a failure at WARN', () async {
    final operations = Operations();
    addTearDown(operations.dispose);
    final failing = StreamController<Object>();
    operations.run(title: 'Start review-42', output: failing.stream, machine: 'orchard');
    failing.addError(const FailedSaying('The image could not be built.'));
    await failing.close();
    await pumpEventQueue();
    expect(logged().map((line) => line.substring(25)), <String>[
      'INFO  [orchard] Started: Start review-42.',
      'WARN  [orchard] Failed: Start review-42: The image could not be built.',
    ]);
  });

  /// A machine with work on it, read once, whose lines carry the name orchard.
  Future<(FakeBackend, FleetModel)> reached() async {
    final backend = FakeBackend(World.work);
    final fleet = FleetModel(backend, machine: 'orchard');
    addTearDown(fleet.dispose);
    await fleet.connect();
    return (backend, fleet);
  }

  // Harm: a removal the machine refused reads in the log like any other outcome, so nobody looking for what went
  // wrong finds it.
  test('a removal refused is written at WARN', () async {
    final (backend, fleet) = await reached();
    final task = fleet.tasks.firstWhere((each) => !each.running);
    backend.nextRemove = Removed.from(const <String, dynamic>{
      'outcome': 'HOLDS_WORK',
      'work': 'two commits',
      'rescuedRef': '',
      'removed': false,
      'discarded': 0,
    });
    await fleet.removeWork(task.name);
    expect(logged().where((line) => line.contains(' WARN  [orchard] ${task.name} holds work')), hasLength(1));
  });

  test('a start refused is written at WARN', () async {
    final (backend, fleet) = await reached();
    final task = fleet.tasks.firstWhere((each) => fleet.projectNameOf(each) != null && each.task.isNotEmpty);
    backend.nextStart = const StartProgress(action: StartAction.needsVault);
    await fleet.startAgain(task);
    expect(logged().where((line) => line.contains(' WARN  [orchard] ${task.name} was not started')), hasLength(1));
  });

  // Harm: what a person asked for twice is in the log once, so the log says a refresh never happened.
  test('two refreshes a person asked for are written twice, even in the same words', () async {
    final (_, fleet) = await reached();
    await fleet.refresh();
    await fleet.refresh();
    expect(logged().where((line) => line.contains(' INFO  [orchard] Refreshed ')), hasLength(2));
  });

  // Harm: a machine that stays unreachable is tried every few seconds, and its log would hold nothing else.
  test('the automatic retries of a machine that stays unreachable are written once', () async {
    final fleet = FleetModel(_Silent(), machine: 'orchard', retryAfter: const Duration(milliseconds: 5));
    addTearDown(fleet.dispose);
    await fleet.connect();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(logged().where((line) => line.contains(' WARN  [orchard] ')), hasLength(1));
  });
}

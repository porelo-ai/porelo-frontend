// Linux only: persisted setup protocol uses the private settings writer, which invokes chmod.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_protocol.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/host_registry.dart';

const _record = HostUpRecord(scalewayProject: 'provider', hostName: 'demo', publicKey: '/keys/person.pub');

void main() {
  late Directory scratch;
  late FileSettingsStore store;
  late Settings settings;
  late Machines machines;
  late HostRuns runs;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('kept-host-protocol-');
    store = FileSettingsStore(file: File('${scratch.path}/settings.json'));
    settings = Settings(store);
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    addTearDown(fixture.registry.dispose);
    runs = HostRuns(
      machines,
      environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
      hostAccess: access,
    );
  });
  tearDown(() async {
    runs.dispose();
    machines.dispose();
    settings.dispose();
    await scratch.delete(recursive: true);
  });

  // Harm: losing a completed rent hides a billed server; stale protocol after give-back describes a destroyed server.
  test('live protocol survives a file restart and is cleared only after confirmed give-back', () async {
    final process = HostProcess();
    final start = DateTime.utc(2000);
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async => process,
      now: () => start,
    );
    final run = runs.start(project: 'demo', session: session, record: _record);
    final delivered = Completer<void>();
    session.addListener(() {
      if (session.said.contains('Public setup diagnostic') &&
          session.steps.any((step) => step.step == 'rent' && step.state == StepState.done) &&
          !delivered.isCompleted) {
        delivered.complete();
      }
    });
    process.line(Step('check', StepState.started, text: 'Check the project', at: start, seconds: 5));
    process.line(Step('check', StepState.done, at: start.add(const Duration(seconds: 2))));
    process.line(Step('rent', StepState.started, text: 'Rent the project server', at: start, seconds: 300));
    process.line(Step('rent', StepState.done, words: 'Server created', at: start.add(const Duration(seconds: 8))));
    process.words('rent done — Server created');
    process.words('Public setup diagnostic');
    await delivered.future;
    await Future.wait([run.saved, settings.setWorkUser('another'), settings.setRefreshSeconds(15)]);
    await settings.rememberHostUp('demo', settings.hostUp('demo')!.withProtocol(session.keptProtocol));
    final before = List<String>.of(session.protocol);
    expect(before, hasLength(3), reason: 'the reference includes both completed steps and an unmatched diagnostic');
    final reopened = Settings(store);
    await reopened.load();
    final fleet = Machines(reopened, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final next = HostProcess();
    final restoredFixture = RegistryFixture();
    final restoredAccess = await restoredFixture.access(reopened);
    addTearDown(restoredFixture.registry.dispose);
    final restored = _RestoredRuns(
      fleet,
      (_, _) async => next,
      environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
      hostAccess: restoredAccess,
    );
    addTearDown(() {
      restored.dispose();
      fleet.dispose();
      reopened.dispose();
    });
    final recovered = restored.of('demo')!;
    await recovered.checked;
    expect(recovered.session.steps.map((step) => step.step), [
      'check',
      'rent',
    ], reason: 'the billed rent must survive an actual JSON file round trip');
    expect(
      recovered.session.protocol.take(before.length),
      before,
      reason: 'recorded words, order, state, and elapsed durations must survive unchanged',
    );
    expect(
      recovered.session.history.last.seconds,
      300,
      reason: 'the original duration estimate must remain attached to the step',
    );
    expect(
      recovered.session.protocol.last,
      startsWith('Interrupted at '),
      reason: 'a confirmed interruption must follow the recorded steps',
    );
    expect(recovered.interrupted, isTrue, reason: 'a free startup lock permits recovery');
    final againSettings = Settings(store);
    await againSettings.load();
    final againFleet = Machines(againSettings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final again = HostRuns(againFleet, environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path});
    await again.of('demo')!.checked;
    expect(
      again.of('demo')!.session.protocol,
      recovered.session.protocol,
      reason: 'reopening an already interrupted run must preserve its marker rather than duplicate it',
    );
    again.dispose();
    againFleet.dispose();
    againSettings.dispose();
    final priorProtocol = List<String>.of(recovered.session.protocol);
    final resumed = restored.resume(recovered);
    next.line(Step('check', StepState.done, text: 'Check the project', at: start));
    next.line(Step('person', StepState.waiting, text: 'Sign in on the server', at: start));
    next.end(75);
    await resumed;
    expect(
      recovered.session.protocol.take(priorProtocol.length),
      priorProtocol,
      reason: 'resuming must retain the earlier rent and interruption',
    );
    expect(recovered.session.steps.map((step) => step.step), [
      'check',
      'person',
    ], reason: 'past completion must never count as the resumed attempt completing');
    final afterResume = Settings(store);
    await afterResume.load();
    final reread = HostSession(executable: 'fake', arguments: const [])
      ..restoreProtocol(afterResume.hostUp('demo')!.protocol);
    expect(reread.protocol, recovered.session.protocol, reason: 'all attempts must survive the next restart');
    expect(reread.steps.map((step) => step.step), [
      'check',
      'person',
    ], reason: 'restoring must keep prior attempts out of active completion checks');
    reread.dispose();
    afterResume.dispose();
    await runs.leave();
    process.end(75);
    await run.finished;
    final failedDown = HostProcess()
      ..line(const Step('give-back', StepState.done))
      ..end(69);
    final down = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => failedDown);
    addTearDown(down.dispose);
    await down.down();
    await restored.confirmDown('demo', down);
    await reopened.load();
    expect(
      reopened.hostUp('demo')!.protocol,
      isNotEmpty,
      reason: 'a progress event without successful exit must retain billing evidence',
    );
    final givenBack = HostProcess()
      ..line(const Step('give-back', StepState.done))
      ..end(0);
    final confirmed = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => givenBack);
    addTearDown(confirmed.dispose);
    await confirmed.down();
    await restored.confirmDown('demo', confirmed);
    await reopened.load();
    expect(reopened.hostUp('demo'), isNull, reason: 'confirmed give-back removes recovery and protocol together');
  });

  // Harm: copying unrecognized wire fields to disk could retain a credential or once-shown password.
  test('stored protocol contains only the public fields the session recognizes', () async {
    final process = HostProcess();
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async => process,
      now: () => DateTime.utc(2000),
    );
    final run = runs.start(project: 'demo', session: session, record: _record);
    process.raw(
      jsonEncode({
        'step': 'rent',
        'state': 'done',
        'text': 'Rent the project server',
        'words': 'Server created',
        'password': 'synthetic-sensitive-field',
        'credentials': {'token': 'synthetic-sensitive-field'},
      }),
    );
    process.end(75);
    await run.finished;
    final stored = await store.read();
    final persisted = jsonEncode(stored);
    final diskEntry = switch (stored) {
      {'hostUps': {'demo': {'protocol': [_, final Map<String, Object?> entry]}}} => entry,
      _ => fail('The file must contain exactly the recorded public step.'),
    };
    expect(
      persisted.contains('synthetic-sensitive-field'),
      isFalse,
      reason: 'unrecognized credentials must never enter the saved protocol',
    );
    final readBack = Settings(store);
    addTearDown(readBack.dispose);
    await readBack.load();
    final entry = readBack.hostUp('demo')!.protocol.whereType<HostProtocolStep>().single;
    expect(diskEntry.keys.toSet(), {
      'kind',
      'name',
      'state',
      'text',
      'words',
      'startedAt',
      'endedAt',
      'current',
    }, reason: 'an exact allowlist prevents raw wire fields from being retained');
    expect(
      entry.stored['words'],
      'Server created',
      reason: 'the allowlist must still retain the public result of renting',
    );
  });

  // Harm: a failed settings write silently loses billing evidence while the interface permits leaving.
  test('protocol write failure keeps recovery and refuses leaving', () async {
    final failing = Settings(_RefusingProtocolStore());
    final fleet = Machines(failing, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final fixture = RegistryFixture();
    final access = await fixture.access(failing);
    addTearDown(fixture.registry.dispose);
    final preparing = HostRuns(fleet, hostAccess: access);
    addTearDown(() {
      preparing.dispose();
      fleet.dispose();
      failing.dispose();
    });
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = preparing.start(project: 'demo', session: session, record: _record);
    process.line(const Step('rent', StepState.done));
    process.end(75);
    await run.finished;
    expect(run.problem, isNotNull, reason: 'losing progress persistence must be reported to the person');
    expect(
      failing.hostUp('demo')!.preparing,
      isTrue,
      reason: 'a protocol write failure must retain the initial server recovery answers',
    );
    await expectLater(
      preparing.leave(),
      throwsA(isA<FileSystemException>()),
      reason: 'leaving must not silently discard unsaved billing evidence',
    );
  });

  // Harm: dropping teardown answers over unreadable progress strands a server that is still billed.
  test('an unreadable protocol preserves the stored teardown record with empty progress', () async {
    final teardown = _record.withPreparation(DateTime.utc(2000));
    for (final invalid in <Object?>[
      null,
      false,
      [null],
      [
        {'kind': 'step', 'name': 'rent', 'state': 'done', 'text': false},
      ],
      [
        HostProtocolLine('Public setup diagnostic').stored,
        {'kind': 'interruption', 'at': false},
      ],
    ]) {
      final loaded = Settings(
        MemorySettingsStore({
          'hostUps': {
            'demo': {...teardown.stored, 'protocol': invalid},
          },
        }),
      );
      addTearDown(loaded.dispose);
      await loaded.load();
      final kept = loaded.hostUp('demo');
      expect(kept, isNotNull, reason: 'unreadable protocol must not remove access to a billed server');
      expect(kept!.stored, teardown.stored, reason: 'every teardown and preparation field must survive unchanged');
      expect(
        kept.arguments('demo'),
        teardown.arguments('demo'),
        reason: 'give-back must still target the original server',
      );
      expect(kept.protocol, isEmpty, reason: 'an unreadable protocol must be discarded in full');
    }
  });

  // Harm: malformed saved progress can crash recovery or fabricate a completed rent.
  test('invalid stored protocol fields are rejected without casting', () {
    final valid = HostProtocolStep(
      name: 'rent',
      state: StepState.done,
      text: 'Rent the project server',
      startedAt: DateTime.utc(2000),
      current: true,
      seconds: 300,
    ).stored;
    expect(HostProtocolEntry.readMany([valid]), hasLength(1), reason: 'the valid reference must be loadable');
    for (final invalid in <Map<String, Object?>>[
      {'kind': 7},
      {'name': ''},
      {'name': 7},
      {'state': 'unknown'},
      {'state': 'plan'},
      {'text': false},
      {'words': []},
      {'fix': 7},
      {'seconds': -1},
      {'seconds': '300'},
      {'current': 'true'},
      {'startedAt': null},
      {'startedAt': 'not-a-time'},
      {'startedAt': '2000-02-30T00:00:00.000Z'},
      {'endedAt': false},
    ]) {
      expect(
        HostProtocolEntry.readMany([
          {...valid, ...invalid},
        ]),
        isNull,
        reason: 'invalid ${invalid.keys.single} must not fabricate recovery',
      );
    }
    for (final invalid in <Object?>[
      null,
      false,
      [null],
      [
        {'kind': 'line', 'text': 7},
      ],
      [
        {'kind': 'interruption', 'at': false},
      ],
      [
        {'kind': 'attempt', 'startedAt': false},
      ],
      [
        {'kind': 'attempt', 'startedAt': DateTime.utc(2000).toIso8601String(), 'endedAt': false},
      ],
    ]) {
      expect(HostProtocolEntry.readMany(invalid), isNull, reason: 'an invalid entry must not crash startup');
    }
    expect(
      HostUpRecord.fromStored(_record.stored),
      isNotNull,
      reason: 'records from before protocol retention remain usable',
    );
  });
}

class _RestoredRuns extends HostRuns {
  _RestoredRuns(super.machines, this.startCommand, {super.environment, super.hostAccess});
  final StartHostCommand startCommand;
  @override
  HostSession sessionFor(String project, HostUpRecord record) => HostSession(
    executable: 'fake',
    arguments: hostArguments(record, project),
    start: startCommand,
    now: () => DateTime.utc(2000, 1, 2),
  );
}

class _RefusingProtocolStore extends MemorySettingsStore {
  @override
  Future<void> write(Map<String, Object?> values) async {
    final hosts = values['hostUps'];
    if (hosts is Map && hosts.values.any((record) => record is Map && record.containsKey('protocol'))) {
      throw const FileSystemException('Settings write refused.');
    }
    await super.write(values);
  }
}

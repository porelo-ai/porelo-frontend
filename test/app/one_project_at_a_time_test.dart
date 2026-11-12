import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/backups.dart';
import 'package:porelo_frontend/src/app/egress.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/gate.dart';

/// One view serves every project, so what one project's read answers is shown only under that project's
/// name: never under the next one's, never after the next one was asked, and never for a project of the
/// same name on another machine.
void main() {
  Project project(String name) => Project.from(<String, dynamic>{'name': name, 'file': name});

  group('backups', () {
    // Harm: a restore confirmed under one project's name writes over another's mirror from a bundle of
    // the first.
    test('a restore considered for one project is not offered under the next one', () async {
      final machine = _Machine()..answerAtOnce = true;
      final backups = Backups();
      await backups.look(machine, 'a');
      await backups.considerRestoring(machine, backups.taken.single);
      expect(backups.restoring, isNotNull);

      await backups.look(machine, 'b');
      expect(backups.restoring, isNull, reason: 'the confirmation was for a');
      expect(backups.restoringFrom, isNull);
      await backups.restore(machine, force: true);
      expect(machine.restored, isEmpty, reason: 'nothing of a is restored under b');
    });

    test('an answer for the project asked before is not written under the next one', () async {
      final machine = _Machine();
      final backups = Backups();
      final forA = backups.look(machine, 'a');
      final forB = backups.look(machine, 'b');
      machine.answer('b');
      await forB;
      machine.answer('a');
      await forA;
      expect(backups.taken.single.bundle, '/srv/b.bundle');
      expect(backups.busy, isFalse);
    });

    test('a late answer neither ends the reading of the next project nor writes over it', () async {
      final machine = _Machine();
      final backups = Backups();
      final forA = backups.look(machine, 'a');
      final forB = backups.look(machine, 'b');
      machine.answer('a');
      await forA;
      expect(backups.busy, isTrue, reason: 'b is still asked');
      expect(backups.taken, isEmpty);
      machine.answer('b');
      await forB;
      expect(backups.taken.single.bundle, '/srv/b.bundle');
    });

    test('going back to a project takes its newest answer, not the one asked before', () async {
      final machine = _Machine();
      final backups = Backups();
      final firstA = backups.look(machine, 'a');
      final forB = backups.look(machine, 'b');
      final againA = backups.look(machine, 'a');
      machine.answer('a', at: 1);
      await againA;
      machine.answer('b');
      await forB;
      machine.answer('a', at: 0, bundle: '/srv/a-old.bundle');
      await firstA;
      expect(backups.taken.single.bundle, '/srv/a.bundle');
      expect(backups.busy, isFalse);
    });

    test('a project of the same name on another machine does not show this one\'s record', () async {
      final here = _Machine()..answerAtOnce = true;
      final there = _Machine();
      final backups = Backups();
      await backups.look(here, 'a');
      final asked = backups.look(there, 'a');
      expect(backups.taken, isEmpty, reason: 'there is another machine');
      there.answer('a');
      await asked;
    });
  });

  group('egress', () {
    test('an answer for the project asked before is not written under the next one', () async {
      final machine = _Machine();
      final egress = Egress();
      final forA = egress.lookAt(machine, project('a'));
      final forB = egress.lookAt(machine, project('b'));
      machine.answer('a');
      await forA;
      expect(egress.busy, isTrue, reason: 'b is still asked');
      expect(egress.reachable, isEmpty);
      machine.answer('b');
      await forB;
      expect(egress.reachable.single.host, 'b.example');
      expect(egress.read, isTrue);
    });

    test('going back to a project takes its newest answer, not the one asked before', () async {
      final machine = _Machine();
      final egress = Egress();
      final firstA = egress.lookAt(machine, project('a'));
      final forB = egress.lookAt(machine, project('b'));
      final againA = egress.lookAt(machine, project('a'));
      machine.answer('a', at: 1);
      await againA;
      machine.answer('b');
      await forB;
      machine.answer('a', at: 0, bundle: 'old');
      await firstA;
      expect(egress.reachable.single.host, 'a.example');
      expect(egress.busy, isFalse);
    });

    test('a project of the same name on another machine does not show this one\'s hosts', () async {
      final here = _Machine()..answerAtOnce = true;
      final there = _Machine();
      final egress = Egress();
      await egress.lookAt(here, project('a'));
      final asked = egress.lookAt(there, project('a'));
      expect(egress.reachable, isEmpty, reason: 'there is another machine');
      there.answer('a');
      await asked;
    });
  });

  group('gate', () {
    test('an answer for the project asked before is not written under the next one', () async {
      final machine = _Machine();
      final gate = Gate();
      final forA = gate.lookAt(machine, project('a'));
      final forB = gate.lookAt(machine, project('b'));
      machine.answer('a');
      await forA;
      expect(gate.reading, greaterThan(0), reason: 'b is still asked');
      expect(gate.busy, isTrue);
      expect(gate.waiting, isEmpty);
      machine.answer('b');
      await forB;
      expect(gate.waiting.single.name, 'push-of-b');
    });

    test('going back to a project takes its newest answer, not the one asked before', () async {
      final machine = _Machine();
      final gate = Gate();
      final firstA = gate.lookAt(machine, project('a'));
      final forB = gate.lookAt(machine, project('b'));
      final againA = gate.lookAt(machine, project('a'));
      machine.answer('a', at: 1);
      await againA;
      machine.answer('b');
      await forB;
      machine.answer('a', at: 0, bundle: 'old');
      await firstA;
      expect(gate.waiting.single.name, 'push-of-a');
      expect(gate.reading, 0);
      expect(gate.busy, isFalse);
    });

    test('a project of the same name on another machine does not show this one\'s pushes', () async {
      final here = _Machine()..answerAtOnce = true;
      final there = _Machine();
      final gate = Gate();
      await gate.lookAt(here, project('a'));
      final asked = gate.lookAt(there, project('a'));
      expect(gate.waiting, isEmpty, reason: 'there is another machine');
      there.answer('a');
      await asked;
    });

    test('a refusal of one project is not said while the next one is read', () async {
      final machine = _Machine()..answerAtOnce = true;
      final gate = Gate();
      machine.refuseTheGate = true;
      await gate.lookAt(machine, project('a'));
      expect(gate.problem, isNotNull);
      machine
        ..refuseTheGate = false
        ..answerAtOnce = false;
      final asked = gate.lookAt(machine, project('b'));
      expect(gate.problem, isNull);
      expect(gate.otherProblem, isNull);
      machine.answer('b');
      await asked;
    });
  });
}

/// A machine whose reads answer when the test says, each for the project it was asked about.
class _Machine implements FleetBackend {
  bool answerAtOnce = false;
  bool refuseTheGate = false;
  final restored = <String>[];
  final _held = <({String project, Completer<String?> answer})>[];

  /// Answers the read for [project]: the [at]th one asked about it, the first by default.
  void answer(String project, {int at = 0, String? bundle}) {
    final asked = _held.where((each) => each.project == project).toList();
    asked[at].answer.complete(bundle);
    _held.remove(asked[at]);
  }

  Future<String?> _asked(String project) async {
    if (answerAtOnce) return null;
    final answer = Completer<String?>();
    _held.add((project: project, answer: answer));
    return answer.future;
  }

  @override
  Future<List<Backup>> backups(String project, {String? repository}) async {
    final bundle = await _asked(project) ?? '/srv/$project.bundle';
    return <Backup>[Backup(taken: '2026-11-12T00:00:00Z', bundle: bundle, refs: 1, present: true, bytes: 1)];
  }

  @override
  Future<Restored> restoreBackup(String project, String bundle, {bool? dryRun, bool? force, String? repository}) async {
    if (dryRun != true) restored.add('$project from $bundle');
    return Restored(outcome: dryRun == true ? 'PREVIEWED' : 'RESTORED', mirror: '', unreviewed: const [], detail: '');
  }

  @override
  Future<(List<EgressHost>, List<String>, List<RemovedSetting>)> egressOf(
    String projectFile, {
    String? repository,
  }) async {
    final said = await _asked(projectFile);
    return (
      <EgressHost>[EgressHost(host: said == null ? '$projectFile.example' : '$said.example', origin: 'project')],
      const <String>[],
      const <RemovedSetting>[],
    );
  }

  @override
  Future<(List<EgressSet>, List<String>)> egressSets() async => (const <EgressSet>[], const <String>[]);

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async {
    if (refuseTheGate) {
      throw const VarlinkException('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{'message': 'no mirror'});
    }
    final said = await _asked(projectFile);
    return GateState.from(<String, dynamic>{
      'mode': 'gatekeeping',
      'pending': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': said == null ? 'push-of-$projectFile' : 'push-of-$said',
          'commit': '9a3c1f2',
          'subject': 'Round',
          'waiting': '1 minute',
        },
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/gate.dart';

import 'fleet_model_test.dart' show aBackendThatRefusesEverything;

/// The gate refuses to be asked about a project it cannot name.
///
/// Unreachable from the interface, which offers no gate for such a project and says why — but a
/// caller could still get here, and opening on nothing would be the wrong answer.
void main() {
  test('a project with no file is not asked about at all', () async {
    final gate = Gate();

    await gate.lookAt(
      aBackendThatRefusesEverything,
      Project.from(const <String, dynamic>{'name': 'unrecorded', 'file': ''}),
    );

    expect(gate.reachable, isFalse);
    expect(gate.problem, contains('not a project this machine follows'));
    expect(gate.waiting, isEmpty);
  });

  test('a push forwarded is said to be, even when another repository could not be read', () async {
    final backend = _OneOfTwoGatesReadable();
    final gate = Gate();

    await gate.lookAt(
      backend,
      Project.from(const <String, dynamic>{
        'name': 'checkout',
        'file': '/srv/checkout/project.yml',
        'repositories': <String>['checkout', 'payments-api'],
      }),
    );
    expect(gate.problem, contains('payments-api could not be read'));
    expect(gate.waiting.single.repository, 'checkout');

    await gate.look(backend, gate.waiting.single);
    final said = await gate.approve(backend, 'fix-rounding');

    expect(said, contains('was forwarded to fix-rounding'));
    expect(backend.approvedIn, <String?>['checkout']);
  });
}

/// The project's own repository answers; the other's mirror is gone.
class _OneOfTwoGatesReadable implements FleetBackend {
  final approvedIn = <String?>[];

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async {
    if (repository == 'payments-api') {
      throw const VarlinkException('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{
        'message': 'the mirror is missing',
      });
    }
    return GateState.from(const <String, dynamic>{
      'mode': 'gatekeeping',
      'pending': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'migrate', 'commit': '9a3c1f2', 'subject': 'Round', 'waiting': '1 minute'},
      ],
    });
  }

  @override
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
  }) async => (diff: '', log: '', files: const <ReviewFile>[], asked: null);

  @override
  Future<void> approve(String projectFile, String name, String branch, {String? repository, String? commit}) async =>
      approvedIn.add(repository);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

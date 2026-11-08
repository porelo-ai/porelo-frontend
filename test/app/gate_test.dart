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
    expect(gate.problem, contains('is not on this machine'));
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
    final answer = await gate.approve(backend, 'fix-rounding');

    expect(answer.forwarded, isTrue);
    expect(answer.said, contains('was forwarded to fix-rounding'));
    expect(backend.approvedIn, <String?>['checkout']);
  });

  // The harm: the caller's proposed branch is reported as the actual destination.
  test('a forward names only the destination confirmed by the answer', () async {
    final backend = _OneOfTwoGatesReadable()..forwardedBranch = 'porelo/migrate';
    final gate = Gate();
    await gate.lookAt(backend, Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'}));
    await gate.look(backend, gate.waiting.single);
    final answer = await gate.approve(backend, '');
    expect(answer.forwarded, isTrue);
    expect(answer.said, contains('was forwarded to porelo/migrate'));
    expect(
      answer.said,
      isNot(contains('refs/porelo/forwarded/')),
      reason: 'Approve returns the incoming name, with no retained ref or commit',
    );
  });

  // The harm: the window said the diff left line ends out while the machine had sent it whole.
  test('the diff is said to leave line ends out only when it was asked without them', () async {
    final backend = _ContractReadOnce();
    final gate = Gate();
    await gate.lookAt(backend, Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'}));
    await gate.look(backend, gate.waiting.single);
    expect(gate.servesWithoutLineEndings, isTrue);

    await gate.showWithoutLineEndings(backend, true);
    expect(backend.asked.last, isNull, reason: 'the contract could not be read this time, so nothing was sent');
    expect(gate.withoutLineEndings, isFalse, reason: 'the diff shown holds the line ends');
  });
}

/// Serves the line-end switch, and then cannot say what it serves.
class _ContractReadOnce extends _OneOfTwoGatesReadable {
  final asked = <bool?>[];
  var reads = 0;

  @override
  Future<String> contract() async {
    if (reads++ > 0) throw const VarlinkDisconnected('gone for a moment');
    return 'method Review(project: string, name: string, ignoreLineEndings: ?bool) -> ()';
  }

  @override
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async {
    asked.add(ignoreLineEndings);
    return (diff: '', log: '', files: const <ReviewFile>[], asked: null);
  }
}

/// The project's own repository answers; the other's mirror is gone.
class _OneOfTwoGatesReadable implements FleetBackend {
  final approvedIn = <String?>[];
  String? forwardedBranch;

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
    bool? ignoreLineEndings,
  }) async => (diff: '', log: '', files: const <ReviewFile>[], asked: null);

  @override
  Future<ForwardedPush> approve(
    String projectFile,
    String name,
    String branch, {
    String? repository,
    String? commit,
  }) async {
    approvedIn.add(repository);
    return ForwardedPush.from(<String, dynamic>{'forwarded': name, 'branch': forwardedBranch ?? branch});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

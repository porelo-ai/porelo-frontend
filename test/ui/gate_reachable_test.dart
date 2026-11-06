import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/gate.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

/// What waits at the gate stays reachable however much could not be read.
///
/// The harm: a commit that cannot be approved, or even opened, because the refusals of the other
/// repositories cover it.
void main() {
  const refused = 16;
  final project = Project.from(<String, dynamic>{
    'name': 'sluice',
    'file': '/srv/sluice/project.yml',
    'repositories': <String>['sluice', for (var i = 0; i < refused; i++) 'library-$i'],
  });

  Future<void> show(WidgetTester tester, Widget view) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
    await tester.pump();
  }

  testWidgets('a push waiting beside sixteen long refusals can be opened', (tester) async {
    final gate = Gate();
    await gate.lookAt(_SixteenRefuse(), project);
    expect(gate.problem, contains('library-15 could not be read'));

    await show(tester, GateView(gate: gate, focusNode: FocusNode(), onOpen: (_) {}, onClose: () {}));

    expect(find.text('Round to the nearest penny').hitTestable(), findsOneWidget);
    // Each refusal names its own repository and address; one reason is still one line.
    expect(find.textContaining('$refused repositories could not be read'), findsOneWidget);
  });

  testWidgets('the forward stays reachable under a long problem', (tester) async {
    final backend = _SixteenRefuse();
    final gate = Gate();
    await gate.lookAt(backend, project);
    await gate.look(backend, gate.waiting.single);
    gate.problem = List<String>.filled(refused, _cloneFailed('library')).join(' ');

    await show(tester, ReviewView(gate: gate, onBack: () {}, onClose: () {}, onApprove: () {}, onReject: () {}));

    expect(find.text('Forward it upstream…').hitTestable(), findsOneWidget);
  });
}

String _cloneFailed(String name) =>
    'git clone git@github.com:example/$name.git failed:\n'
    'Cloning into bare repository \'$name.git\'...\n'
    'No ED25519 host key is known for github.com and you have requested strict checking.\n'
    'Host key verification failed.\n'
    'fatal: Could not read from remote repository.\n\n'
    'Please make sure you have the correct access rights\n'
    'and the repository exists.';

/// The project's own repository holds one push; each of the others refuses with git's whole message.
class _SixteenRefuse implements FleetBackend {
  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async {
    if (repository != 'sluice') {
      throw VarlinkException('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{
        'message': _cloneFailed(repository ?? ''),
      });
    }
    return GateState.from(const <String, dynamic>{
      'mode': 'gatekeeping',
      'pending': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'round',
          'commit': '9a3c1f2',
          'subject': 'Round to the nearest penny',
          'waiting': '1 minute',
        },
      ],
    });
  }

  @override
  Future<String> contract() async => '';

  @override
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async => (diff: '', log: '', files: const <ReviewFile>[], asked: null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

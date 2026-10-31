import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/forges_view.dart';
import 'package:porelo_frontend/src/ui/host_key_dialog.dart';
import 'package:porelo_frontend/src/ui/host_stop_dialog.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend, FakeForge, World;

/// A terminal whose program does its work and ends with 0 only while the terminal closes, as one put away at the moment
/// it finished does.
class _EndsWellOnClose implements SessionChannel {
  _EndsWellOnClose({this.onClose});

  /// What the program did before it ended.
  final void Function()? onClose;

  final _output = StreamController<List<int>>.broadcast();
  final _ended = Completer<int>();

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {
    onClose?.call();
    if (!_ended.isCompleted) _ended.complete(0);
  }
}

class _Runs extends HostRuns {
  _Runs(super.machines);
  final resumed = <HostPreparation>[];
  @override
  Future<void> resume(HostPreparation run) async => resumed.add(run);
}

Future<void> _putAway(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('unlock-cancel')));
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('unlock-cancel-yes')));
  await World.settle(tester);
}

void main() {
  // Harm: a Scaleway key Scaleway accepted and kept as its terminal closed taken as refused, so the host setup asks for
  // it again although it is kept.
  testWidgets('a provider key kept while its terminal closes is taken as accepted', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => accepted = await openHostKeyDialog(
              context,
              open: (executable, arguments, {columns = 80, rows = 24}) => _EndsWellOnClose(),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await World.settle(tester);

    await _putAway(tester);

    expect(accepted, isTrue, reason: 'the program ended with 0 while its terminal closed');
  });

  // Harm: a provider sign-in that went through as its terminal closed taken as failed, so the host run never resumes.
  testWidgets('a provider sign-in that ends well while its terminal closes resumes the host run', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []));
    final runs = _Runs(machines);
    final session = HostSession(executable: 'fake', arguments: const []);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
      session.dispose();
    });
    final run = HostPreparation(
      project: 'demo',
      session: session,
      record: const HostUpRecord(scalewayProject: 'provider'),
      act: HostAct.ownAccount,
      providerMachine: const Machine(
        name: 'account',
        kind: 'host',
        hostProject: 'orchard',
        host: 'worker@orchard',
        socketPath: '',
        remoteSocket: '/run/user/1007/porelo',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HostStopDialog(
          run: run,
          hostRuns: runs,
          machines: machines,
          needs: const ['vault'],
          openTerminal: (program, arguments, {columns = 80, rows = 24}) => _EndsWellOnClose(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('host-open-provider-terminal')));
    await World.settle(tester);

    await _putAway(tester);

    expect(runs.resumed, [run], reason: 'the program ended with 0 while its terminal closed');
  });

  // Harm: a forge token stored as its terminal closed taken as cancelled, so the forge is never added.
  testWidgets('a forge token stored while its terminal closes connects the forge', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tokens = MemoryForgeTokens();
    final forges = ForgeConnection(
      tokens,
      forgeFor: (token, _) => FakeForge()..tokensTried.add(token),
      openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) =>
          _EndsWellOnClose(onClose: () => unawaited(tokens.write(arguments.last, 'ghp_accepted'))),
    );
    addTearDown(forges.dispose);
    var said = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeForm(useToken: true, forges: forges, onDone: (words) => said = words),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('forge-address')), 'git.example.org');
    final connect = find.byKey(const Key('forge-connect'));
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await World.settle(tester);

    await _putAway(tester);

    expect(said, contains('is set up'), reason: 'the program ended with 0 while its terminal closed');
  });
}

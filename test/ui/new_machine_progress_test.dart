import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_setup.dart';
import 'package:porelo_frontend/src/app/setup_run.dart';
import 'package:porelo_frontend/src/ui/new_machine.dart';

import '../support/tresorit_fixture.dart';

class _Response extends StreamView<List<int>> implements HttpClientResponse {
  _Response(super.stream, this.contentLength);

  @override
  final int contentLength;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  _Client(this.response);
  final _Response response;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(response);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Each remote action waits for the test's answer, without sockets on the widget test's fake clock.
class _Machine extends MachineSetup {
  _Machine() : super(home: '/unused');

  final sent = Completer<ProcessResult>();
  final checked = Completer<ProcessResult>();
  final prepared = Completer<ProcessResult>();
  void Function(int)? sending;
  void Function(String)? checking;
  void Function(String)? rootLine;

  @override
  Future<ProcessResult> asUser(String alias, String command) async {
    if (command.contains('mktemp -d')) return ProcessResult(0, 0, '/tmp/installer\n', '');
    if (command.contains('/bin/bash -c')) return checked.future;
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> asUserLive(String alias, String command, void Function(String) onLine) {
    checking = onLine;
    return asUser(alias, command);
  }

  @override
  Future<ProcessResult> sendToUser(String alias, String path, List<int> bytes, {void Function(int)? onProgress}) async {
    if (path.endsWith('/installer.run')) {
      sending = onProgress;
      return sent.future;
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<ProcessResult> asRootLive(String host, String keyFile, String script, void Function(String) onLine) {
    rootLine = onLine;
    return prepared.future;
  }
}

void main() {
  const mb = 1024 * 1024;
  late Directory scratch;
  late Uint8List bytes;
  late String pin;

  setUpAll(() async {
    if (TresoritFixture.skip != null) return;
    scratch = await Directory.systemTemp.createTemp('wizard-progress-');
    final fixture = TresoritFixture(scratch);
    final certificates = await fixture.certificates('download');
    final installer = await fixture.installer('download', [certificates.signing, certificates.ca]);
    // Only transfer counts are exercised here; the remote verifier is controlled by the test.
    bytes = Uint8List(3 * mb)..setRange(0, installer.length, installer);
    pin = fixture.fingerprint(certificates.ca);
  });
  tearDownAll(() async {
    if (TresoritFixture.skip == null) await scratch.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, SetupRun run) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(run.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: NewMachineSteps(run: run)),
        ),
      ),
    );
  }

  for (final total in [3 * mb, -1]) {
    // Harm: an apparently stalled transfer invites abandoning or repeating an installation still running.
    testWidgets('the installer shows bytes and each phase with total $total', (tester) async {
      final chunks = StreamController<List<int>>();
      final machine = _Machine();
      final run = SetupRun(name: 'example', workUser: 'alice', setup: machine, installerPin: pin)
        ..step = SetupStep.drive;
      await open(tester, run);
      final installing = HttpOverrides.runZoned(
        run.installDrive,
        createHttpClient: (_) => _Client(_Response(chunks.stream, total)),
      );
      await tester.pump();
      chunks.add(Uint8List.sublistView(bytes, 0, mb));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text("Fetching Tresorit's installer: 1${total > 0 ? ' of 3' : ''} MB"), findsOneWidget);
      chunks.add(Uint8List.sublistView(bytes, mb, 2 * mb));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text("Fetching Tresorit's installer: 2${total > 0 ? ' of 3' : ''} MB"), findsOneWidget);
      chunks.add(Uint8List.sublistView(bytes, 2 * mb));
      unawaited(chunks.close());
      await tester.pump();
      machine.sending?.call(mb);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Sending it to alice on the machine: 1 of 3 MB'), findsOneWidget);
      machine.sent.complete(ProcessResult(0, 0, '', ''));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Checking its signature on the machine…'), findsOneWidget);
      machine.checking?.call('PORELO_TRESORIT_INSTALLING');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Installing and starting it…'), findsOneWidget);
      machine.checked.complete(ProcessResult(0, 0, '', ''));
      await installing;
      await tester.pump();
      expect(run.driveInstalled, isTrue);
      expect(find.byKey(const Key('setup-doing')), findsNothing);
    }, skip: TresoritFixture.skip != null);
  }

  for (final signaturePassed in [false, true]) {
    final phase = signaturePassed ? 'Installing and starting it' : 'Checking its signature on the machine';
    // Harm: a failed check or installation must not be mistaken for a completed installation.
    testWidgets('a failure in $phase names its phase and never marks the drive installed', (tester) async {
      final machine = _Machine();
      machine.sent.complete(ProcessResult(0, 0, '', ''));
      final run = SetupRun(
        name: 'example',
        workUser: 'alice',
        setup: machine,
        download: (_) async => bytes,
        installerPin: pin,
      )..step = SetupStep.drive;
      await open(tester, run);
      final installing = run.installDrive();
      await tester.pump();
      if (signaturePassed) machine.checking!('PORELO_TRESORIT_INSTALLING');
      final failure = signaturePassed ? 'installation failed' : 'verification failed';
      machine.checked.complete(ProcessResult(0, 1, '', failure));
      await installing;
      await tester.pump();
      expect(find.textContaining('$phase:'), findsOneWidget);
      expect(run.driveInstalled, isFalse);
      expect(run.saidIsBad, isTrue);
      if (signaturePassed) expect(run.said, isNot(contains('nothing of it ran')));
    }, skip: TresoritFixture.skip != null);
  }

  // Harm: a running root script that appears stuck invites a second setup while it still changes the machine.
  testWidgets('the setup busy message shows the latest script line while root is still running', (tester) async {
    final machine = _Machine();
    final run = SetupRun(name: 'example', workUser: 'alice', setup: machine)
      ..step = SetupStep.prepare
      ..loggedInTo = 'example.org'
      ..kept = '/unused/key'
      ..shownDigest = 'ab' * 32;
    await open(tester, run);
    var notifications = 0;
    run.addListener(() => notifications++);
    final preparing = run.prepare();
    machine.rootLine!('Reading package lists...');
    await tester.pump(const Duration(milliseconds: 249));
    expect(notifications, 1, reason: 'lines do not notify sooner than the progress interval');
    await tester.pump(const Duration(milliseconds: 1));
    expect(notifications, 2);
    expect(find.text("Running Porelo's setup script as root…"), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('setup-progress'))).data, 'Reading package lists...');
    for (final line in ['Resolving packages...', 'Downloading packages...', 'Installing packages...']) {
      machine.rootLine!(line);
    }
    await tester.pump(const Duration(milliseconds: 250));
    expect(notifications, 3, reason: 'a burst of lines causes one progress notification');
    expect(tester.widget<Text>(find.byKey(const Key('setup-progress'))).data, 'Installing packages...');
    machine.prepared.complete(ProcessResult(0, 0, '', ''));
    await preparing;
    await tester.pump();
    expect(run.prepared, isTrue);
    expect(find.byKey(const Key('setup-doing')), findsNothing);
  });
}

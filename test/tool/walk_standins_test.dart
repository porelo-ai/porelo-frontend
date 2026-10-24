// The stand-ins are compiled and joined over unix sockets, which only Linux has here.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current;
  // Use the SDK paired with flutter_tester rather than whichever dart PATH selects.
  final cache = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  final dart = '${cache.path}/dart-sdk/bin/dart';
  late Directory binaries;
  late String hostExecutable;
  late String sshExecutable;
  setUpAll(() async {
    binaries = await Directory.systemTemp.createTemp('wb');
    hostExecutable = '${binaries.path}/host';
    sshExecutable = '${binaries.path}/ssh';
    for (final tool in {'host_standin': hostExecutable, 'ssh_standin': sshExecutable}.entries) {
      final result = await Process.run(
        dart,
        ['compile', 'exe', 'tool/${tool.key}.dart', '-o', tool.value],
        workingDirectory: root.path,
        environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }
  });
  tearDownAll(() => binaries.delete(recursive: true));
  late Directory scratch;
  late File state;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('w');
    state = File('${scratch.path}/host-standin.json');
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<void> situation(String name, {int pace = 0}) =>
      state.writeAsString(jsonEncode({'situation': name, 'paceMilliseconds': pace}));

  const options = [
    '--project',
    'checkout',
    '--tresor',
    'walk-drive',
    '--account',
    'porelo',
    '--public-key',
    'unused.pub',
    '--identity',
    'unused',
    '--collection',
    'unused.tar.gz',
    '--scaleway-project',
    'walk',
    '--vpn-peer-public-key',
    'public',
    '--vpn-peer-address',
    '10.73.0.2/32',
  ];

  Future<Process> host({String verb = 'up', bool answers = false, Map<String, String>? environment}) => Process.start(
    hostExecutable,
    [verb, ...options, if (answers) '--answers-on-stdin'],
    workingDirectory: root.path,
    environment: {
      'DASH__SUPPRESS_ANALYTICS': 'true',
      ...?environment,
      if (environment == null) 'PORELO_WALK': scratch.path,
    },
    includeParentEnvironment: false,
  );

  Future<({int code, List<Step> steps, List<Map<String, dynamic>> lines, String errors})> finish(
    Process process, {
    String input = '',
  }) async {
    addTearDown(() => process.kill(ProcessSignal.sigkill));
    final output = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).toList();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(input);
    await process.stdin.close();
    final code = await process.exitCode.timeout(const Duration(seconds: 15));
    final lines = await output;
    final steps = <Step>[];
    for (final line in lines) {
      final step = Step.fromLine(line);
      expect(step, isNotNull, reason: 'every stdout line must be a host step: $line');
      steps.add(step!);
      if (step.state == StepState.started) {
        final map = jsonDecode(line) as Map<String, dynamic>;
        expect(map.keys.toList().sublist(map.length - 2), ['text', 'seconds']);
        expect(map['text'], isA<String>().having((text) => text.isNotEmpty, 'English words', isTrue));
        expect(map['seconds'], isA<num>().having((seconds) => seconds >= 0, 'nonnegative duration', isTrue));
      }
    }
    return (
      code: code,
      steps: steps,
      lines: lines.map((line) => jsonDecode(line) as Map<String, dynamic>).toList(),
      errors: await errors,
    );
  }

  final beforeStop = [
    for (final name in ['rent', 'ssh', 'copy', 'ansible', 'play']) ...['$name:started', '$name:done'],
  ];
  final afterStop = [
    for (final name in ['drive', 'vault']) ...['$name:started', '$name:done'],
    'up:done',
  ];

  // Harm: malformed step lines or wrong exits make the interface misread completed host work.
  for (final name in ['clean', 'stop', 'refused', 'slow', 'down']) {
    test('the $name situation speaks host steps and the matching exit', () async {
      await situation(name);
      final result = await finish(await host(verb: name == 'down' ? 'down' : 'up'));
      expect(result.code, switch (name) {
        'stop' => Exit.waiting,
        'refused' => Exit.refused,
        _ => Exit.done,
      });
      expect(result.errors, isNotEmpty, reason: 'people get words on stderr');
      expect(result.steps.map((step) => '${step.step}:${step.state.name}'), switch (name) {
        'stop' => [...beforeStop, 'person:waiting'],
        'refused' => ['rent:started', 'rent:refused'],
        'slow' => ['play:started', 'play:done', 'up:done'],
        'down' => ['give-back:started', 'give-back:done'],
        _ => [...beforeStop, ...afterStop],
      });
      if (name == 'stop') {
        expect(result.steps.last.needs, ['drive', 'vault-new']);
      } else if (name == 'refused') {
        expect(result.steps.last.fix, isNotEmpty);
      } else {
        expect(result.steps.last.address, '192.0.2.10');
        if (name != 'down') {
          expect(result.steps.last.account, 'porelo');
          expect(result.steps.last.socket, '/run/user/1000/porelo/porelod.sock');
        }
        expect(jsonDecode(await state.readAsString())['state'], name == 'down' ? 'down' : 'done');
      }
    });
  }

  // Harm: an answer leaks to disk or stderr, or the stop cannot resume in a second process.
  test('a stopped run resumes with stdin answers and drops every answer byte', () async {
    await situation('stop');
    expect((await finish(await host())).code, Exit.waiting);
    expect((await finish(await host())).code, Exit.waiting, reason: 'up alone cannot answer the stop');
    final process = await host(answers: true);
    final result = await finish(
      process,
      input: '{"drivePassword":"walk-answer-sentinel","vaultPassphrase":"walk-vault-sentinel"}\n',
    );
    expect(result.code, Exit.done);
    expect(result.steps.last.step, 'up');
    expect(jsonDecode(await state.readAsString())['state'], 'done');
    expect(scratch.listSync().map((file) => file.uri.pathSegments.last), [
      'host-standin.json',
    ], reason: 'answers must not create a log or another state file');
    for (final value in ['walk-answer-sentinel', 'walk-vault-sentinel']) {
      expect(await state.readAsString(), isNot(contains(value)));
      expect(result.errors, isNot(contains(value)));
      expect(jsonEncode(result.lines), isNot(contains(value)));
    }
  });

  // Harm: a missing or invalid walk configuration silently selects the wrong host behavior.
  test('missing unreadable and malformed walk configuration is refused', () async {
    for (final environment in [
      <String, String>{},
      {'PORELO_WALK': ''},
      {'PORELO_WALK': scratch.path},
    ]) {
      final result = await finish(await host(environment: environment));
      expect(result.code, Exit.usage);
      expect(result.steps, isEmpty);
      expect(result.errors, isNotEmpty);
    }
    for (final contents in [
      'not json',
      '[]',
      '{"situation":"unknown"}',
      '{"situation":"slow","paceMilliseconds":-1}',
    ]) {
      await state.writeAsString(contents);
      final result = await finish(await host());
      expect(result.code, Exit.usage);
      expect(result.errors, isNotEmpty);
    }
  });

  Future<ProcessResult> ssh(List<String> args, {Map<String, String> environment = const {}}) => Process.run(
    sshExecutable,
    args,
    workingDirectory: root.path,
    environment: {'DASH__SUPPRESS_ANALYTICS': 'true', ...environment},
    includeParentEnvironment: false,
  );

  // Harm: an unsupported ssh command silently succeeds or a missing target leaves a dead forward.
  test('ssh refuses unknown forms and a forward without its mock socket', () async {
    for (final args in [
      <String>[],
      ['-t', 'porelo@host', 'bash'],
      ['-o'],
      ['-N', '-L', 'broken', 'host'],
    ]) {
      final result = await ssh(args);
      expect(result.exitCode, 255);
      expect(result.stderr, contains('does not support this form'));
      expect(result.stdout, isEmpty);
    }
    final result = await ssh(['-N', '-L', '${scratch.path}/l:/remote', 'host']);
    expect(result.exitCode, 255);
    expect(result.stderr, contains('PORELO_WALK_HOST_SOCKET'));
  });

  // Harm: a walk deletes or replaces an endpoint owned by another process.
  test('ssh leaves an existing endpoint untouched', () async {
    final local = File('${scratch.path}/l');
    await local.writeAsString('keep this endpoint');
    final result = await ssh(
      ['-N', '-L', '${local.path}:/remote', 'host'],
      environment: {'PORELO_WALK_HOST_SOCKET': '${scratch.path}/r'},
    );
    expect(result.exitCode, 255);
    expect(await local.readAsString(), 'keep this endpoint');
  });

  // Harm: option values become the destination or ssh refusal advice names the wrong key.
  test('ssh config parses pinned options and the identity without mistaking them for the host', () async {
    final result = await ssh([
      '-o',
      'BatchMode=yes',
      '-i',
      '/walk/key',
      '-o',
      'UserKnownHostsFile=/walk/known',
      '-G',
      'porelo@host',
    ]);
    expect(result.exitCode, 0);
    expect(result.stdout, 'identityfile /walk/key\n');
    expect(result.stderr, isEmpty);
  });

  // Harm: lost bytes hang daemon calls, or stopping the forward removes another process endpoint.
  for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
    test('ssh carries bytes both ways and cleans its own socket on $signal', () async {
      final target = '${scratch.path}/r';
      final local = '${scratch.path}/l';
      expect(utf8.encode(local).length, lessThan(100));
      final server = await ServerSocket.bind(InternetAddress(target, type: InternetAddressType.unix), 0);
      addTearDown(server.close);
      final accepted = StreamIterator(server);
      addTearDown(accepted.cancel);
      final process = await Process.start(
        sshExecutable,
        [
          '-i',
          '/walk/key',
          '-o',
          'BatchMode=yes',
          '-N',
          '-o',
          'ExitOnForwardFailure=yes',
          '-L',
          '$local:/run/user/1000/porelo/porelod.sock',
          'porelo@192.0.2.10',
        ],
        workingDirectory: root.path,
        environment: {'DASH__SUPPRESS_ANALYTICS': 'true', 'PORELO_WALK_HOST_SOCKET': target},
        includeParentEnvironment: false,
      );
      addTearDown(() => process.kill(ProcessSignal.sigkill));
      final output = process.stdout.drain<void>();
      final errors = StreamIterator(process.stderr.transform(utf8.decoder).transform(const LineSplitter()));
      addTearDown(errors.cancel);
      expect(await errors.moveNext().timeout(const Duration(seconds: 15)), isTrue);
      expect(errors.current, contains('Forwarding'));
      for (var n = 0; n < 2; n++) {
        final client = await Socket.connect(InternetAddress(local, type: InternetAddressType.unix), 0);
        addTearDown(client.destroy);
        expect(await accepted.moveNext().timeout(const Duration(seconds: 5)), isTrue);
        final peer = accepted.current;
        addTearDown(peer.destroy);
        final request = StreamIterator(peer.expand((bytes) => bytes));
        final response = StreamIterator(client.expand((bytes) => bytes));
        addTearDown(request.cancel);
        addTearDown(response.cancel);
        client.add([0, 255, n, 10]);
        await client.flush();
        for (final byte in [0, 255, n, 10]) {
          expect(await request.moveNext().timeout(const Duration(seconds: 5)), isTrue);
          expect(request.current, byte);
        }
        peer.add([254, n, 0, 13]);
        await peer.flush();
        for (final byte in [254, n, 0, 13]) {
          expect(await response.moveNext().timeout(const Duration(seconds: 5)), isTrue);
          expect(response.current, byte);
        }
        client.destroy();
        peer.destroy();
      }
      expect((await Process.run('chmod', ['600', local])).exitCode, 0);
      process.kill(signal);
      expect(await process.exitCode.timeout(const Duration(seconds: 5)), 0);
      await output;
      expect(FileSystemEntity.typeSync(local), FileSystemEntityType.notFound);
      expect(FileSystemEntity.typeSync(target), FileSystemEntityType.unixDomainSock);
    });
  }
}

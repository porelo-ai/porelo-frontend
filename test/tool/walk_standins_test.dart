// The stand-ins are compiled and joined over unix sockets, which only Linux has here.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current;
  // Both the plain Dart runner and flutter_tester use the same paired SDK.
  final executable = File(Platform.resolvedExecutable);
  final dart = executable.parent.path.endsWith('/bin')
      ? executable.path
      : '${executable.parent.parent.parent.parent.path}/dart-sdk/bin/dart';
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
    '--scaleway-project',
    'walk',
    '--vpn-peer-public-key',
    'public',
    '--vpn-peer-address',
    '10.73.0.2/32',
  ];

  Future<Process> host({String verb = 'up', Map<String, String>? environment}) => Process.start(
    hostExecutable,
    [
      verb,
      ...options,
      '--collection',
      hostExecutable,
      '--collection-sha256',
      sha256.convert(File(hostExecutable).readAsBytesSync()).toString(),
    ],
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
      if (step!.state != StepState.plan) steps.add(step);
      if (step.state == StepState.started) {
        final map = jsonDecode(line) as Map<String, dynamic>;
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
        'slow' => ['play:started', 'play:done', ...afterStop],
        'down' => ['give-back:started', 'give-back:done'],
        _ => [...beforeStop, ...afterStop],
      });
      if (name == 'stop') {
        expect(result.steps.last.needs, ['drive', 'vault-new']);
        expect(result.steps.last.address, '192.0.2.10');
        expect(result.steps.last.account, 'porelo');
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

  // Harm: the walk still requires secrets to pass through provisioning.
  test('a stopped run continues with a plain second up and no answers', () async {
    await situation('stop');
    expect((await finish(await host())).code, Exit.waiting);
    final result = await finish(await host());
    expect(result.code, Exit.done);
    expect(result.steps.last.step, 'up');
    expect(jsonDecode(await state.readAsString())['state'], 'done');
    expect(scratch.listSync().map((file) => file.uri.pathSegments.last), [
      'host-standin.json',
    ], reason: 'the stop creates no answer file');
  });

  // Harm: a walk stops at its first wizard step because the stand-in refuses the key check the real tool answers.
  test('the Scaleway key check is accepted and any other key check refused', () async {
    await situation('clean');
    Future<int> check(List<String> arguments) async {
      final process = await Process.start(hostExecutable, arguments, environment: {'PORELO_WALK': scratch.path});
      await process.stdin.close();
      return process.exitCode.timeout(const Duration(seconds: 15));
    }

    expect(await check(['key', 'check', 'scaleway']), 0);
    expect(await check(['key', 'check', 'hetzner']), Exit.usage);
    expect(await check(['key', 'set', 'scaleway']), Exit.usage);
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

  const sshKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKN5JzCUxyX6M8b9iJQSNmDvv7NirfTaeG3ZL3q7N3ke';
  final vpnKey = base64Encode(List<int>.filled(32, 7));

  Future<Process> server({
    String verb = 'up',
    String name = 'orchard',
    int network = 17,
    List<String> extra = const [],
    Map<String, String> environment = const {},
  }) => Process.start(
    hostExecutable,
    [
      verb,
      '--host-name',
      name,
      '--network',
      '$network',
      '--forge',
      'true',
      '--login-user',
      'root',
      '--public-key',
      'unused.pub',
      '--identity',
      'unused',
      '--scaleway-project',
      'walk',
      '--vpn-peer-public-key',
      vpnKey,
      '--vpn-peer-address',
      '10.73.$network.2/32',
      ...extra,
    ],
    environment: {'PORELO_WALK': scratch.path, ...environment},
    includeParentEnvironment: false,
  );

  // Harm: invalid completion records or project stops prevent a prepared server from being used.
  test('a prepared server stops as root then ends with seven checked public host fields', () async {
    await situation('stop');
    final stopped = await finish(await server());
    expect(stopped.code, Exit.waiting);
    expect(stopped.steps.last.account, 'root');
    expect(stopped.steps.last.needs, ['wireguard', 'forge-certificate']);
    expect(stopped.steps.where((step) => step.host != null), isEmpty);
    final done = await finish(await server());
    expect(done.code, Exit.done);
    expect(done.steps[done.steps.length - 2].state, StepState.done);
    final host = done.steps.last.host!;
    expect(done.lines.last.keys, unorderedEquals(['v', 'state', 'host']));
    expect(
      host.values.keys,
      unorderedEquals([
        'address',
        'endpoint',
        'wireguard_public_key',
        'network',
        'ssh_host_key',
        'ca_sha256',
        'homeserver',
      ]),
    );
    expect(host.values['address'], '192.0.2.10');
    expect(host.values['endpoint'], '192.0.2.10:51820');
    expect(host.network, 17);
    expect(host.values['homeserver'], 'matrix.orchard.porelo.internal');
    expect(host.fingerprint, startsWith('SHA256:'));
    final down = await finish(await server(verb: 'down'));
    expect(down.code, Exit.done);
    expect(down.steps.map((step) => step.step), ['give-back', 'give-back']);
    await situation('stop');
    final withoutForge = await finish(await server(extra: ['--forge', 'false']));
    expect(withoutForge.code, Exit.waiting);
    expect(withoutForge.steps.last.needs, ['wireguard', 'forge-certificate']);
  });

  // Harm: the interface refuses the prepared server because the stand-in reports a VPN key other than the one prepared.
  test('a prepared server reports the VPN key the interface prepared for it', () async {
    final prepared = base64Encode(List<int>.filled(32, 9));
    final configuration = Directory('${scratch.path}/config/porelo')..createSync(recursive: true);
    File('${configuration.path}/frontend.json').writeAsStringSync(
      jsonEncode({
        'hostUps': {
          'orchard': {'vpnHostPublicKey': prepared},
        },
      }),
    );
    await situation('clean');
    final done = await finish(await server(environment: {'XDG_CONFIG_HOME': '${scratch.path}/config'}));
    expect(done.code, Exit.done);
    expect(done.steps.last.host!.values['wireguard_public_key'], prepared);
    final other = await finish(
      await server(name: 'other', network: 18, environment: {'XDG_CONFIG_HOME': '${scratch.path}/config'}),
    );
    expect(other.code, Exit.done);
    expect(other.steps.last.host!.values['wireguard_public_key'], vpnKey);
  });

  // Harm: ignored host options rehearse a different operation than the app requested.
  test('prepared server options retain strict validation and every situation', () async {
    for (final name in ['clean', 'slow', 'refused']) {
      await situation(name);
      final result = await finish(await server(name: 'second-host', network: 255));
      expect(result.code, name == 'refused' ? Exit.refused : Exit.done);
      if (name != 'refused') {
        expect(result.steps.last.host!.network, 255);
        expect(result.steps.last.host!.values['homeserver'], 'matrix.second-host.porelo.internal');
      }
    }
    for (final extra in [
      ['--unknown', 'value'],
      ['--forge'],
      ['--forge', 'perhaps'],
      ['--project', 'checkout'],
      ['--account', 'alice'],
      ['--network', '-1'],
      ['--network', '256'],
      ['--network', 'text'],
      ['--host-name', 'bad.name'],
    ]) {
      await situation('clean');
      final result = await finish(await server(extra: extra));
      expect(result.code, Exit.usage, reason: '$extra');
      expect(result.steps, isEmpty);
    }
  });

  Future<({int code, String output, String errors})> helper(
    String command, {
    String input = '',
    bool close = true,
  }) async {
    final process = await Process.start(
      sshExecutable,
      [
        '-i',
        '/walk/key',
        '-o',
        'BatchMode=yes',
        '-o',
        'ConnectTimeout=10',
        '-T',
        '--',
        'root@192.0.2.10',
        '/usr/local/sbin/porelo-host-$command',
      ],
      environment: {'PORELO_WALK': scratch.path},
      includeParentEnvironment: false,
    );
    addTearDown(() => process.kill(ProcessSignal.sigkill));
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(input);
    await process.stdin.flush();
    if (close) await process.stdin.close();
    final code = await process.exitCode.timeout(const Duration(seconds: 5));
    return (code: code, output: await output, errors: await errors);
  }

  // Harm: helpers that ignore input or lose state authorize operations on the wrong people or projects.
  test('SSH helpers admit laptops register remove lock and purge using persisted inputs', () async {
    await situation('clean');
    final host = (await finish(await server())).steps.last.host!;
    final block = 'laptop $sshKey $vpnKey';
    final admit = HostAdminRequest.admit('alice', block, 17);
    final added = await helper('person add alice --role project-admin', input: '$block\n');
    expect(added.code, 0, reason: added.errors);
    expect(admit.answer(RemoteResult(added.code, added.errors), [added.output.trim()], host), contains('10.73.17.3'));
    expect((await helper('person add alice --role project-admin', input: '$block\n')).output, added.output);
    final key2 =
        'ssh-ed25519 ${base64Encode([...base64Decode(sshKey.split(' ')[1]).take(19), ...List<int>.filled(32, 8)])}';
    final vpn2 = base64Encode(List<int>.filled(32, 8));
    final key3 =
        'ssh-ed25519 ${base64Encode([...base64Decode(sshKey.split(' ')[1]).take(19), ...List<int>.filled(32, 9)])}';
    final vpn3 = base64Encode(List<int>.filled(32, 9));
    final second = await helper(
      'person add bob --role project-admin',
      input: 'other $key2 $vpn2\nspare $key3 $vpn3 10.73.17.5\n',
    );
    expect(second.code, 0, reason: second.errors);
    expect(jsonDecode(second.output)['laptops'], [
      {'laptop': 'other', 'vpn_address': '10.73.17.4'},
      {'laptop': 'spare', 'vpn_address': '10.73.17.5'},
    ]);
    final registered = await helper("project add grove alice --signed-by '$sshKey'");
    expect(registered.code, 0, reason: registered.errors);
    expect(
      HostAdminRequest.register(
        'grove',
        'alice',
        sshKey,
      ).answer(RemoteResult(registered.code, registered.errors), [registered.output.trim()], host),
      contains('porelo-publisher-grove'),
    );
    final duplicateProject = await helper("project add grove bob --signed-by '$sshKey'");
    expect(duplicateProject.code, 65);
    expect(duplicateProject.output, isEmpty);
    final removed = await helper('project remove grove', input: 'invented-removal-token\n', close: false);
    expect(removed.code, 0, reason: removed.errors);
    expect(jsonDecode(removed.output), {'project': 'grove', 'removed': true});
    expect((await helper("project add grove-two bob --signed-by '$sshKey'")).code, 0);
    final withoutToken = await helper('project remove grove-two');
    expect(withoutToken.code, 0);
    expect(jsonDecode(withoutToken.output), {'project': 'grove-two', 'removed': true});
    for (final action in ['lock', 'lock', 'purge']) {
      final result = await helper('person $action alice');
      expect(result.code, 0, reason: result.errors);
      expect(jsonDecode(result.output), {'person': 'alice', action == 'lock' ? 'locked' : 'purged': true});
    }
    for (final command in ['person lock alice', 'person purge alice', 'project remove grove']) {
      final result = await helper(command, input: 'invented-removal-token\n');
      expect(result.code, 65);
      expect(result.output, isEmpty);
      expect(
        result.errors,
        command.startsWith('person')
            ? 'porelo-host-person: the person is unknown to the people records\n'
            : 'porelo-host-project: unknown project grove\n',
      );
    }
    for (final file in scratch.listSync(recursive: true).whereType<File>()) {
      expect(await file.readAsString(), isNot(contains('invented-removal-token')));
    }
    expect(removed.output + removed.errors, isNot(contains('invented-removal-token')));
  });

  // Harm: malformed or colliding public identities silently consume another laptop's access.
  test('SSH helper refusals leave the people and projects unchanged', () async {
    await situation('clean');
    await finish(await server());
    for (final block in [
      '',
      'bad',
      'laptop ssh-ed25519 AAAA $vpnKey\n',
      'laptop $sshKey $vpnKey 10.73.18.2\n',
      'one $sshKey $vpnKey\ntwo $sshKey $vpnKey\n',
      'one $sshKey $vpnKey\nmalformed\n',
    ]) {
      final result = await helper('person add alice --role project-admin', input: block);
      expect(result.code, 64, reason: block);
      expect(result.output, isEmpty);
    }
    final added = await helper('person add alice --role project-admin', input: 'laptop $sshKey $vpnKey 10.73.17.9\n');
    expect(added.code, 0, reason: added.errors);
    expect(jsonDecode(added.output)['laptops'], [
      {'laptop': 'laptop', 'vpn_address': '10.73.17.9'},
    ]);
    final duplicate = await helper('person add bob --role project-admin', input: 'other $sshKey $vpnKey\n');
    expect(duplicate.code, 65);
    expect(duplicate.output, isEmpty);
    for (final command in [
      'person add bob --role owner',
      'person lock Bad',
      "project add grove alice --signed-by 'ssh-ed25519 AAAA'",
    ]) {
      final result = await helper(command);
      expect(result.code, 64, reason: command);
      expect(result.output, isEmpty);
    }
    expect((await helper('person lock bob')).code, 65);
    expect((await helper('project remove grove')).code, 65);
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

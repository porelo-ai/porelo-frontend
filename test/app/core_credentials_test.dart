import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/core_credentials.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

void main() {
  final fingerprint = 'SHA256:${List.filled(43, 'A').join()}';
  final other = 'SHA256:${List.filled(43, 'B').join()}';
  final key = (type: 'ssh-ed25519', fingerprint: fingerprint);

  // Harm: a key is recorded before comparison, or another key is accepted from a changed or malformed reply.
  test('host trust previews without writing and confirms the exact selected key', () async {
    final calls = <List<String>>[];
    Object? answer = {
      'host': 'forge.example.org:2222',
      'keys': [
        {'type': key.type, 'fingerprint': key.fingerprint, 'future': true},
      ],
      'known': false,
      'future': <Object?>[],
    };
    var code = 0;
    final core = CoreCredentials(
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        expect(program, 'porelo');
        expect(input, isNull, reason: 'host trust needs no secret');
        calls.add(arguments);
        return (code: code, out: jsonEncode(answer), err: '');
      },
    );
    final offered = await core.offered('forge.example.org:2222');
    expect(offered.keys, [key]);
    expect(offered.known, false);
    expect(calls.single, ['credentials', 'trust-host', 'forge.example.org:2222', '--json']);
    answer = {
      'host': 'forge.example.org:2222',
      'recorded': {'type': key.type, 'fingerprint': key.fingerprint},
    };
    await core.trust('forge.example.org:2222', key);
    expect(calls.last, ['credentials', 'trust-host', 'forge.example.org:2222', '--fingerprint=$fingerprint', '--json']);
    for (final bad in [
      {
        'host': 'another.example.org',
        'recorded': {'type': key.type, 'fingerprint': key.fingerprint},
      },
      {
        'host': 'forge.example.org:2222',
        'recorded': {'type': key.type, 'fingerprint': other},
      },
      {'host': 'forge.example.org:2222', 'recorded': null},
      <Object?>[],
    ]) {
      answer = bad;
      await expectLater(core.trust('forge.example.org:2222', key), throwsA(isA<WorkspaceRefused>()));
    }
    code = 70;
    await expectLater(core.trust('forge.example.org:2222', key), throwsA(isA<WorkspaceRefused>()));
  });

  // Harm: an unreadable or empty preview enables trust, or an option-like host starts a different command.
  test('unreadable host previews and unsafe destinations cannot be trusted', () async {
    var calls = 0;
    Object? answer = {'host': 'forge.example.org', 'known': false, 'keys': <Object?>[]};
    final core = CoreCredentials(
      run: (_, _, {inDirectory, environment = const {}, input}) async {
        calls++;
        return (code: 0, out: jsonEncode(answer), err: '');
      },
    );
    for (final bad in [
      answer,
      {
        'host': 'forge.example.org',
        'known': 'false',
        'keys': [
          {'type': key.type, 'fingerprint': key.fingerprint},
        ],
      },
      {
        'host': 'forge.example.org',
        'known': false,
        'keys': [
          {'type': 'ssh-ed25519'},
        ],
      },
      {'host': 'forge.example.org', 'known': false, 'keys': 'none'},
    ]) {
      answer = bad;
      await expectLater(core.offered('forge.example.org'), throwsA(isA<WorkspaceRefused>()));
    }
    final before = calls;
    for (final host in ['-F', 'forge.example.org\nother', 'forge.example.org:0', 'forge.example.org:65536']) {
      await expectLater(core.offered(host), throwsA(isA<WorkspaceRefused>()));
    }
    expect(calls, before, reason: 'unsafe destinations must not reach the process boundary');
  });

  // Harm: a token leaks through command arguments or diagnostics, or an unconfirmed write permits a forge operation.
  test('the kept forge token reaches only vault standard input and requires a checked echo', () async {
    const token = 'a-private-test-token';
    final tokens = MemoryForgeTokens();
    await tokens.write('forge.example.org', token);
    final forges = ForgeConnection(tokens);
    addTearDown(forges.dispose);
    final calls = <List<String>>[];
    var reply = (code: 0, out: '{"name":"git.token.forge.example.org","stored":true,"future":1}', err: '');
    final core = CoreCredentials(
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        calls.add([program, ...arguments]);
        expect(input, token, reason: 'the token belongs only on the helper input pipe');
        expect(environment, isEmpty);
        return reply;
      },
    );
    await forges.handTokenToVault('forge.example.org', core: core);
    expect(calls.single, ['porelo', 'vault', 'put', 'git.token.forge.example.org', '--json']);
    for (final bad in [
      (code: 0, out: '{"name":"git.token.other","stored":true}', err: ''),
      (code: 0, out: '{"name":"git.token.forge.example.org","stored":"true"}', err: ''),
      (code: 0, out: token, err: token),
      (code: 70, out: token, err: token),
    ]) {
      reply = bad;
      try {
        await forges.handTokenToVault('forge.example.org', core: core);
        fail('an unconfirmed vault write must refuse');
      } on WorkspaceRefused catch (refused) {
        expect(refused.words, isNot(contains(token)), reason: 'neither helper output stream is safe diagnostic text');
      }
    }
    await tokens.delete('forge.example.org');
    final before = calls.length;
    await expectLater(forges.handTokenToVault('forge.example.org', core: core), throwsA(isA<WorkspaceRefused>()));
    expect(calls.length, before, reason: 'a missing token must not launch a put with empty input');
  });
}

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' as cli;

final _secret = '${List.filled(8, 'a').join()}-bbbb-cccc-dddd-${List.filled(12, 'e').join()}';

void main() {
  late Directory scratch;
  late _MemoryStore store;
  late StringBuffer output;
  late StringBuffer errors;
  late List<(String, String)> calls;
  var status = 200;
  Object? responseBody;
  Exception? failure;

  setUp(() async {
    HttpOverrides.global = _NoNetwork();
    scratch = await Directory.systemTemp.createTemp('provider-key-');
    store = _MemoryStore();
    output = StringBuffer();
    errors = StringBuffer();
    calls = [];
    status = 200;
    responseBody = const <String, Object?>{'offers': <Object?>[]};
    failure = null;
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await scratch.delete(recursive: true);
  });

  Future<int> run(List<String> arguments, {String? input}) => cli.runKeyCommand(
    arguments,
    openStore: () => store,
    readKey: () => input,
    output: output,
    errors: errors,
    exchange: (key) => (method, path, {body}) async {
      expect(key == _secret, isTrue, reason: 'only the stripped secret goes into the authentication header');
      calls.add((method, path));
      if (failure != null) throw failure!;
      return ApiAnswer(status, responseBody);
    },
  );

  Future<File> keyFile(String content, {int mode = 0x180}) async {
    final file = await File('${scratch.path}/input').writeAsString(content);
    if (Platform.isLinux || Platform.isMacOS) _chmod(file.path, mode);
    return file;
  }

  void noLeak(String value) {
    expect(output.toString().contains(value), isFalse, reason: 'stdout must never disclose the secret');
    expect(errors.toString().contains(value), isFalse, reason: 'stderr must never disclose the secret');
  }

  for (final (label, body) in <(String, Object?)>[
    ('text', 'upstream returned $_secret'),
    ('empty', null),
    ('list', <Object?>[]),
    ('number', 42),
    ('boolean', true),
  ]) {
    for (final verb in ['set', 'check']) {
      // Harm: accepting an unrelated successful response can replace a working key or let the wizard bypass validation.
      test('key $verb refuses a successful $label body without exposing or changing credentials', () async {
        responseBody = body;
        status = label == 'empty'
            ? 204
            : label == 'list'
            ? 299
            : 200;
        store.values[providerKeyName('scaleway')] = verb == 'check' ? _secret : 'previous-key';
        final previous = Map.of(store.values);
        final code = await run([verb, 'scaleway'], input: _secret);

        noLeak(_secret);
        expect(code, 65, reason: 'HTTP success without an offers object must not authenticate a key');
        expect(
          _sameValues(store.values, previous),
          isTrue,
          reason: 'an unrelated response must preserve the stored credential',
        );
        expect(store.writes, 0, reason: 'an unrelated response must never authorize storing a credential');
        expect(calls, [
          ('GET', '/baremetal/v1/zones/fr-par-1/offers?name=EM-I220E-NVME'),
        ], reason: 'a rejected response must end the single offers check without retrying');
        expect(errors.isNotEmpty, isTrue, reason: 'the command must explain the refusal on stderr');
      });
    }
  }

  for (final source in ['terminal', 'plain file', 'assignments file']) {
    for (final outcome in [200, 204, 299, 401, 403, 500, 503, 'network']) {
      // Harm: provider errors and successful writes can disclose the secret or replace a working key on failure.
      test('$source keeps the secret private and preserves storage for $outcome', () async {
        if (outcome is int) status = outcome;
        responseBody = {'message': 'credential refused: $_secret'};
        if (outcome == 'network') failure = SocketException('unreachable: $_secret');
        final accepted = outcome is int && outcome < 300;
        store.values[providerKeyName('scaleway')] = 'previous-key';
        final arguments = ['set', 'scaleway'];
        if (source != 'terminal') {
          final content = source == 'plain file' ? ' \t$_secret\r\n' : 'ACCESS_KEY=unused\nSECRET_KEY= $_secret \r\n';
          final file = await keyFile(content);
          arguments.addAll(['--from-file', file.path]);
        }
        final code = await run(arguments, input: ' $_secret\n');

        noLeak(_secret);
        expect(
          code,
          accepted ? 0 : (outcome == 401 || outcome == 403 ? 65 : 69),
          reason: 'authentication refusal and availability failures have different recovery paths',
        );
        expect(calls, [
          ('GET', '/baremetal/v1/zones/fr-par-1/offers?name=EM-I220E-NVME'),
        ], reason: 'validation must make exactly one read-only offers request');
        expect(
          store.values[providerKeyName('scaleway')] == (accepted ? _secret : 'previous-key'),
          isTrue,
          reason: 'only an accepted stripped key may replace the earlier key',
        );
        expect(store.writes, accepted ? 1 : 0, reason: 'refusal must not write to the secret store');
        if (outcome == 401 || outcome == 403) {
          expect(
            errors.toString(),
            contains('refused by Scaleway: credential refused:'),
            reason: 'the provider refusal must reach the person without its echoed credential',
          );
        }
      });
    }
  }

  for (final value in ['SCW$_secret', 'not-a-uuid-$_secret', '']) {
    for (final fromFile in [false, true]) {
      // Harm: invalid credentials must never be sent to the provider or replace stored credentials.
      test(
        'invalid ${value.isEmpty
            ? 'empty'
            : value.startsWith('SCW')
            ? 'access'
            : 'non UUID'} key from ${fromFile ? 'file' : 'terminal'} never reaches the provider',
        () async {
          final arguments = ['set', 'scaleway'];
          if (fromFile) arguments.addAll(['--from-file', (await keyFile('$value\n')).path]);
          final code = await run(arguments, input: value);

          if (value.isNotEmpty) noLeak(value);
          noLeak(_secret);
          expect(code, 65, reason: 'malformed keys are data refusals');
          expect(calls, isEmpty, reason: 'format validation must happen before any HTTP request');
          expect(store.values, isEmpty, reason: 'an invalid key must not be stored');
          expect(store.writes, 0, reason: 'there must be no attempt to store an invalid key');
        },
      );
    }
  }

  for (final statusCode in [401, 403, 500]) {
    // Harm: a refused credential could be stored when no earlier key exists.
    test('HTTP $statusCode leaves an empty store empty', () async {
      status = statusCode;
      responseBody = {'message': 'not authorized'};
      final code = await run(['set', 'scaleway'], input: _secret);
      noLeak(_secret);
      expect(code, statusCode < 500 ? 65 : 69, reason: 'refusal and unavailability must fail closed');
      expect(store.values, isEmpty, reason: 'only accepted credentials may be kept');
      expect(store.writes, 0, reason: 'an HTTP error must not write any credential');
    });
  }

  // Harm: reading a file available to other users accepts a credential that may already be exposed.
  test('a public file is refused before reading or making any request', () async {
    final file = await keyFile(_secret, mode: 0x1a4);
    await file.writeAsBytes([..._secret.codeUnits, 0xff]);
    final code = await run(['set', 'scaleway', '--from-file', file.path]);
    noLeak(_secret);
    expect(code, 65, reason: 'a file readable by other users must be refused');
    expect(errors.toString(), contains('owner-only'), reason: 'permissions must be checked before decoding the file');
    expect(calls, isEmpty, reason: 'unsafe files must never reach the API');
    expect(store.writes, 0, reason: 'unsafe files must never reach the store');
  }, skip: !(Platform.isLinux || Platform.isMacOS) ? 'POSIX permission bits require Linux or macOS.' : false);

  for (final kind in ['symlink', 'directory', 'missing']) {
    // Harm: following a substituted file or opening a special file can disclose a credential or hang.
    test('a $kind is refused as a key file without a request', () async {
      final name = '${scratch.path}/other';
      if (kind == 'symlink') await Link(name).create((await keyFile(_secret)).path);
      if (kind == 'directory') await Directory(name).create();
      final code = await run(['set', 'scaleway', '--from-file', name]);
      noLeak(_secret);
      expect(code, 65, reason: 'only regular files may supply a key');
      expect(calls, isEmpty, reason: 'non-regular files must be rejected before HTTP');
      expect(store.writes, 0, reason: 'non-regular files must not change credentials');
    }, skip: kind == 'symlink' && Platform.isWindows ? 'Creating symlinks requires Windows privileges.' : false);
  }

  for (final (label, value, accepted) in [
    ('double quotes', '"$_secret"', true),
    ('single quotes', "'$_secret'", true),
    ('unmatched quotes', '"$_secret\'', false),
    ('two quote pairs', '""$_secret""', false),
  ]) {
    // Harm: keeping quotes or removing extra or unmatched quotes checks or stores a different key from the file.
    test('assignment with $label preserves the key when parsing quotes', () async {
      final file = await keyFile('SECRET_KEY=$value\n');
      store.values[providerKeyName('scaleway')] = 'previous-key';
      final code = await run(['set', 'scaleway', '--from-file', file.path]);

      noLeak(_secret);
      expect(code, accepted ? 0 : 65, reason: 'only one matching quote pair may wrap a UUID');
      expect(
        calls,
        accepted ? [('GET', '/baremetal/v1/zones/fr-par-1/offers?name=EM-I220E-NVME')] : isEmpty,
        reason: 'only the bare UUID may reach authentication',
      );
      expect(
        store.values[providerKeyName('scaleway')] == (accepted ? _secret : 'previous-key'),
        isTrue,
        reason: 'accepted keys must be stored bare and refused keys must preserve the earlier key',
      );
      expect(store.writes, accepted ? 1 : 0, reason: 'invalid quoting must never authorize a write');
    });
  }

  // Harm: a download with assignments but no secret key could store the access key instead.
  test('assignments without SECRET_KEY are refused without using another value', () async {
    final file = await keyFile('ACCESS_KEY=$_secret\nPROJECT_ID=unused\n');
    final code = await run(['set', 'scaleway', '--from-file', file.path]);
    noLeak(_secret);
    expect(code, 65, reason: 'an assignment file must explicitly name SECRET_KEY');
    expect(calls, isEmpty, reason: 'another field must never be tried as the secret');
    expect(store.writes, 0, reason: 'a missing SECRET_KEY must leave storage untouched');
  });

  for (final outcome in ['missing', 'malformed', 200, 401, 403, 503, 'network']) {
    // Harm: a wizard could bypass authentication or overwrite a credential when merely checking it.
    test('checking a stored key fails closed for $outcome without writing', () async {
      if (outcome != 'missing') {
        store.values[providerKeyName('scaleway')] = outcome == 'malformed' ? 'SCW$_secret' : _secret;
      }
      final previous = Map.of(store.values);
      if (outcome is int) status = outcome;
      responseBody = {'message': 'denied $_secret'};
      if (outcome == 'network') failure = SocketException(_secret);
      final code = await run(['check', 'scaleway']);
      noLeak(_secret);
      expect(
        code,
        outcome == 200 ? 0 : (outcome == 503 || outcome == 'network' ? 69 : 65),
        reason: 'checking must distinguish accepted, refused, and unreachable credentials',
      );
      expect(
        calls.length,
        outcome == 'missing' || outcome == 'malformed' ? 0 : 1,
        reason: 'a stored key must pass format validation before its single request',
      );
      expect(_sameValues(store.values, previous), isTrue, reason: 'checking must preserve the stored value');
      expect(store.writes, 0, reason: 'checking must never write credentials');
      if (code != 0) expect(errors.isNotEmpty, isTrue, reason: 'a refusal must explain why on stderr');
    });
  }

  // Harm: a secret-store failure might include the credential in its exception message.
  test('secret store exceptions never escape or disclose their values', () async {
    store.failure = SecretStoreFailed('cannot write $_secret');
    final code = await run(['set', 'scaleway'], input: _secret);
    noLeak(_secret);
    expect(code, 65, reason: 'an unavailable secret store must refuse the write');
  });
}

bool _sameValues(Map<String, String> left, Map<String, String> right) =>
    left.length == right.length && left.entries.every((entry) => right[entry.key] == entry.value);

void _chmod(String name, int mode) {
  final chmod = DynamicLibrary.process()
      .lookupFunction<Int32 Function(Pointer<Utf8>, Uint32), int Function(Pointer<Utf8>, int)>('chmod');
  using((arena) {
    expect(
      chmod(name.toNativeUtf8(allocator: arena), mode),
      0,
      reason: 'the fixture must have the requested file permissions',
    );
  });
}

class _MemoryStore implements SecretStore {
  final values = <String, String>{};
  int writes = 0;
  SecretStoreFailed? failure;

  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async {
    if (failure != null) throw failure!;
    writes++;
    values[name] = value;
  }

  @override
  Future<void> remove(String name) async => values.remove(name);
  @override
  Future<void> close() async {}
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw StateError('Tests must use the fake Scaleway API.');
}

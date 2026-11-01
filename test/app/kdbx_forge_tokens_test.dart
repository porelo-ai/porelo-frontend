import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/kdbx_forge_tokens.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

void main() {
  late Directory folder;
  late KeyFileSecrets secrets;
  late MemoryForgeTokens platform;
  late List<List<String>> calls;
  late Map<String, String> entries;
  var opens = true;

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String>? environment,
    String? input,
  }) async {
    calls.add([program, ...arguments]);
    if (!opens) return (code: 1, out: '', err: 'Error while reading the database');
    return switch (arguments.first) {
      'ls' => (code: 0, out: '${entries.keys.join('\n')}\n', err: ''),
      'show' => (code: 0, out: '${entries[arguments.last]}\n', err: ''),
      _ => (code: 1, out: '', err: ''),
    };
  }

  setUp(() {
    folder = Directory.systemTemp.createTempSync('kdbx-tokens-');
    addTearDown(() => folder.deleteSync(recursive: true));
    secrets = KeyFileSecrets('${folder.path}/secrets.kdbx', '${folder.path}/secrets.key');
    platform = MemoryForgeTokens();
    calls = [];
    entries = {'porelo-forge-token:github.com': 'from-the-test-file'};
    opens = true;
  });

  void prepared() {
    File(secrets.file).writeAsStringSync('');
    File(secrets.keyFile).writeAsStringSync('');
  }

  // Harm: the test token is asked for a master password, or read from the person's own keychain instead.
  test('while the test secrets file is there, a token is read from it with its key file and no password', () async {
    prepared();
    await platform.write('github.com', 'the-persons-own');
    final tokens = KeyFileForgeTokens(secrets, platform, run: run);
    expect(await tokens.read('github.com'), 'from-the-test-file');
    expect(calls.last, [
      '/usr/bin/keepassxc-cli',
      'show',
      '-s',
      '-a',
      'password',
      '--no-password',
      '--key-file',
      secrets.keyFile,
      secrets.file,
      'porelo-forge-token:github.com',
    ]);
    entries = {};
    expect(await tokens.read('github.com'), isNull, reason: 'an entry the file lacks is no token');
  });

  // Harm: a typed token overwrites the test file, or prepare's file is deleted from here.
  test('nothing is written to the test secrets file, and without it the system store is used as before', () async {
    final tokens = KeyFileForgeTokens(secrets, platform, run: run);
    await tokens.write('github.com', 'typed');
    expect(await tokens.read('github.com'), 'typed');
    expect(calls, isEmpty, reason: 'no test file, no keepassxc-cli');
    prepared();
    await expectLater(tokens.write('github.com', 'typed again'), throwsA(isA<ForgeRefused>()));
    await expectLater(tokens.delete('github.com'), throwsA(isA<ForgeRefused>()));
    expect(await platform.read('github.com'), 'typed');
  });

  // Harm: a key file that does not open the file reads as "no token", and the person is sent to type one.
  test('a key file that does not open the file is said in words', () async {
    prepared();
    opens = false;
    await expectLater(
      KeyFileForgeTokens(secrets, platform, run: run).read('github.com'),
      throwsA(isA<ForgeRefused>().having((e) => e.words, 'words', contains('did not open with its key file'))),
    );
  });

  // Harm: the developer's instance acts with the organization's token, or the admin's with the developer's.
  test('an instance started with its own entry reads that entry for the forge', () async {
    prepared();
    entries = {'porelo-forge-token:github.com': 'the-app', 'ms-test-reviewer': 'the-reviewer'};
    final tokens = KeyFileForgeTokens(secrets, platform, entry: 'ms-test-reviewer', run: run);
    expect(await tokens.read('github.com'), 'the-reviewer');
    expect(
      forgeTokenEntryFromArguments(['--roles=user', '--forge-token-entry', 'ms-test-reviewer']),
      'ms-test-reviewer',
    );
    expect(forgeTokenEntryFromArguments(['--forge-token-entry=github/app']), 'github/app');
    expect(forgeTokenEntryFromArguments(['--roles=user']), isNull);
    for (final wrong in [
      ['--forge-token-entry'],
      ['--forge-token-entry', '--roles=user'],
      ["--forge-token-entry=a'b"],
    ]) {
      expect(() => forgeTokenEntryFromArguments(wrong), throwsFormatException, reason: '$wrong');
    }
  });

  // Harm: Core's registry check runs without the organization's token, with the developer's, or with an expired one.
  test(
    'Core\'s registry calls of the organization\'s instance get the installation token, read anew each time',
    () async {
      entries = {'github-app-5539409-installation': 'ghs_first'};
      final environment = registryEnvironmentFor('github-app-5539409-installation', secrets: () => secrets, run: run);
      expect(await environment(), isEmpty, reason: 'no test secrets file: Core takes its vault');
      prepared();
      expect(await environment(), {'PORELO_GITHUB_APP_TOKEN': 'ghs_first'});
      entries = {'github-app-5539409-installation': 'ghs_renewed'};
      expect(await environment(), {'PORELO_GITHUB_APP_TOKEN': 'ghs_renewed'});
    },
  );

  // Harm: a developer's instance cannot read the registry, as Core's owner check asks the organization, or Core gets
  // the developer's own token for it.
  test('an instance started with a person\'s own entry gives Core the organization\'s installation token', () async {
    prepared();
    entries = {'github-ms-test-reviewer': 'ghp_person', 'github-app-5539409-installation': 'ghs_app'};
    for (final entry in ['github-ms-test-reviewer', null]) {
      final environment = registryEnvironmentFor(entry, secrets: () => secrets, run: run);
      expect(await environment(), {'PORELO_GITHUB_APP_TOKEN': 'ghs_app'}, reason: '$entry');
    }
    entries = {'github-ms-test-reviewer': 'ghp_person'};
    expect(await registryEnvironmentFor('github-ms-test-reviewer', secrets: () => secrets, run: run)(), isEmpty);
  });

  // Harm: the token reaches some other program, or never reaches Core's registry call.
  test('only porelo registry gets the registry environment', () async {
    final bin = Directory('${folder.path}/bin')..createSync();
    final fake = File('${bin.path}/porelo')
      ..writeAsStringSync('#!/bin/sh\nprintf "%s" "\${PORELO_GITHUB_APP_TOKEN:-none}"\n');
    await Process.run('/bin/chmod', ['+x', fake.path]);
    registryEnvironment = () async => {'PORELO_GITHUB_APP_TOKEN': 'ghs_x'};
    addTearDown(() => registryEnvironment = null);
    final path = {'PATH': '${bin.path}:/usr/bin:/bin'};
    expect((await runHere('porelo', ['registry', 'read'], environment: path)).out, 'ghs_x');
    expect((await runHere('porelo', ['project', 'verify'], environment: path)).out, 'none');
  });

  // Harm: a second instance with its own runtime folder looks for the test file somewhere prepare never wrote it.
  test('the test secrets file is named by the account id, not the runtime folder', () {
    final status = File('${folder.path}/status')..writeAsStringSync('Name:\tx\nUid:\t1000\t1000\t1000\t1000\n');
    final test = KeyFileSecrets.test(status: status.path)!;
    expect(test.file, '/run/user/1000/porelo-test/secrets.kdbx');
    expect(test.keyFile, '/run/user/1000/porelo-test/secrets.key');
  });
}

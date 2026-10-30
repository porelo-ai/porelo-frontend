// Linux: the terminal feed and its stand-ins require Bash and executable file modes.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';

void main() {
  late Directory scratch;
  late File calls;
  late File saved;
  late File helper;
  late File cli;
  late String candidate;
  late String old;

  String password(int length) => List.generate(length, (_) => Random.secure().nextInt(10)).join();

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('forge-feed-');
    calls = File('${scratch.path}/calls');
    saved = File('${scratch.path}/saved');
    candidate = password(16);
    old = password(16);
    cli = await File('${scratch.path}/cli').writeAsString(r'''#!/bin/bash
IFS= read -r master || exit 1
[ "$master" = fixture-master ] || exit 1
case "$1" in
  ls|mkdir) exit 0;;
  show)
    if [ -f "$TEST_PLACE/saved" ]; then printf '%s\n' "$TEST_CANDIDATE"
    elif [ "${TEST_KEPT:-no}" = yes ]; then printf '%s\n' "$TEST_OLD"
    else exit 1; fi;;
  add|edit)
    IFS= read -r value || exit 1
    [ "$value" = "$TEST_CANDIDATE" ] || exit 1
    printf 'accepted\n' > "$TEST_PLACE/saved";;
  *) exit 1;;
esac
''');
    helper = await File('${scratch.path}/ssh').writeAsString(r'''#!/bin/bash
IFS= read -r value || exit 1
printf 'called\n' >> "$TEST_PLACE/calls"
if [ "${TEST_REFUSE:-no}" = yes ] || { [ "${TEST_KEPT:-no}" = yes ] && [ "$value" = "$TEST_OLD" ]; }; then
  echo 'Forgejo answered 400: password was refused' >&2
  exit 65
fi
[ "$value" = "$TEST_CANDIDATE" ] || exit 1
''');
    expect((await Process.run('/usr/bin/chmod', ['700', cli.path, helper.path])).exitCode, 0);
    await File('${scratch.path}/secrets.kdbx').writeAsString('stand-in database, no secrets');
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<ProcessResult> feed(String input, {bool refuse = false, bool kept = false}) async {
    final command = hostForgePasswordFeedCommand(
      secretsFile: '${scratch.path}/secrets.kdbx',
      ssh: helper.path,
      sshOptions: const [],
      host: 'person@192.0.2.7',
      cli: cli.path,
    );
    final process = await Process.start(
      command.first,
      command.skip(1).toList(),
      environment: {
        'TEST_PLACE': scratch.path,
        'TEST_CANDIDATE': candidate,
        'TEST_OLD': old,
        'TEST_REFUSE': refuse ? 'yes' : 'no',
        'TEST_KEPT': kept ? 'yes' : 'no',
        'LC_ALL': 'C',
      },
    );
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write('fixture-master\n$input');
    await process.stdin.close();
    final result = ProcessResult(process.pid, await process.exitCode, await output, await errors);
    expect(
      '${result.stdout}${result.stderr}'.contains(candidate),
      isFalse,
      reason: 'the terminal cannot reveal a password',
    );
    expect('${result.stdout}${result.stderr}'.contains(old), isFalse);
    return result;
  }

  // Harm: an unusable password is sent and retained, so every retry repeats a rejected credential.
  test('a six-character password is refused before sending or saving', () async {
    candidate = password(6);
    final result = await feed('$candidate\n$candidate\n');
    expect(result.exitCode, isNot(0));
    expect(await calls.exists(), isFalse, reason: 'validation precedes the helper');
    expect(await saved.exists(), isFalse, reason: 'validation precedes storage');
    expect('${result.stderr}', contains('at least 8 characters'));
  });

  // Harm: byte counting in a C locale sends a password with fewer than eight Unicode characters.
  test('six Unicode characters are refused even when the terminal inherits a C locale', () async {
    candidate = String.fromCharCodes(List.generate(6, (_) => 0xe0 + Random.secure().nextInt(16)));
    final result = await feed('$candidate\n$candidate\n');
    expect(result.exitCode, isNot(0));
    expect(await calls.exists(), isFalse);
    expect(await saved.exists(), isFalse);
  });

  // Harm: a mistyped lasting password is installed and stored without confirming the intended value.
  test('a mismatch is refused before sending or saving', () async {
    final result = await feed('$candidate\n$old\n');
    expect(result.exitCode, isNot(0));
    expect(await calls.exists(), isFalse);
    expect(await saved.exists(), isFalse);
  });

  // Harm: a refused new credential poisons the shared entry for subsequent hosts and retries.
  test('a helper refusal is shown and leaves no saved password', () async {
    final result = await feed('$candidate\n$candidate\n', refuse: true);
    expect(result.exitCode, 65);
    expect(await saved.exists(), isFalse);
    expect('${result.stderr}', contains('Forgejo answered 400: password was refused'));
    final retry = await feed('$candidate\n$candidate\n');
    expect(retry.exitCode, 0);
    expect(await saved.exists(), isTrue);
  });

  // Harm: a helper success loses the chosen password or prompts for the master password twice.
  test('a helper success saves the confirmed password using the open secrets file', () async {
    final result = await feed('$candidate\n$candidate\n');
    expect(result.exitCode, 0);
    expect(await calls.readAsLines(), ['called']);
    expect(await saved.exists(), isTrue);
  });

  // Harm: replacing a refused stored password removes the old credential before acceptance.
  for (final refuse in [true, false]) {
    test(
      'a kept password replacement ${refuse ? 'refusal preserves the old entry' : 'success saves the new entry'}',
      () async {
        final result = await feed('y\n$candidate\n$candidate\n', kept: true, refuse: refuse);
        expect(result.exitCode, refuse ? 65 : 0);
        expect(await saved.exists(), !refuse);
        expect(await calls.readAsLines(), ['called', 'called']);
      },
    );
  }
}

// Linux only: it stands a real ssh-agent and the mock daemon on unix sockets.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/task_certifying.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A host starts a task only with a key this computer certifies. A host is not trusted to ask for
/// the right thing, so what it asks is checked here, by the real ssh-agent and ssh-keygen.
void main() {
  late Directory home;
  late Map<String, String> agent;
  late Process agentProcess;
  late String person;
  late String taskKey;

  Future<String> keygen(String name) async {
    final path = '${home.path}/$name';
    final made = await Process.run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-C', name, '-f', path]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    return (await File('$path.pub').readAsString()).trim();
  }

  setUpAll(() async {
    home = await Directory.systemTemp.createTemp('porelo-certify-test-');
    final socket = '${home.path}/agent.sock';
    agentProcess = await Process.start('ssh-agent', ['-D', '-a', socket]);
    for (var i = 0; i < 100 && !File(socket).existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    agent = <String, String>{'SSH_AUTH_SOCK': socket};
    person = await keygen('person');
    taskKey = await keygen('task');
    final added = await Process.run('ssh-add', ['${home.path}/person'], environment: agent);
    expect(added.exitCode, 0, reason: '${added.stderr}');
  });

  tearDownAll(() async {
    agentProcess.kill();
    await home.delete(recursive: true);
  });

  StartCertify asking({
    String? key,
    String principal = 'task:foo-project:work',
    String keyId = 'alice',
    DateTime? before,
    List<String>? certifiers,
  }) => StartCertify(
    start: 's1',
    key: key ?? taskKey,
    principal: principal,
    keyId: keyId,
    validBefore: before ?? DateTime.now().toUtc().add(const Duration(days: 7)),
    certifiers: certifiers ?? <String>[person],
  );

  Future<String> certified(StartCertify asked, {String? project, String? task}) =>
      certifyHere(asked, project: project, task: task, environment: agent);

  // Harm: without this the window can start nothing on a host at all, as the foo test found.
  test('the agent certifies the one key, for the one principal, until the end asked', () async {
    final end = DateTime.now().toUtc().add(const Duration(days: 7));
    final certificate = await certified(
      asking(before: end),
      project: 'foo-project',
      task: 'work',
    );
    final file = File('${home.path}/seen-cert.pub')..writeAsStringSync('$certificate\n');
    final shown = await Process.run('ssh-keygen', ['-L', '-f', file.path]);
    expect(shown.exitCode, 0, reason: '${shown.stderr}');
    expect('${shown.stdout}', contains('task:foo-project:work'));
    expect('${shown.stdout}', contains('Key ID: "alice"'));
    expect(certificate, startsWith('ssh-ed25519-cert-v01@openssh.com '));
  });

  group('what the host asks is refused here, unsigned,', () {
    final soon = DateTime.now().toUtc().add(const Duration(days: 1));
    final cases = <String, (StartCertify Function(), String)>{
      'a key that is not Ed25519': (() => asking(key: 'ssh-rsa AAAA x', before: soon), 'not Ed25519'),
      'another project': (() => asking(principal: 'task:other:work', before: soon), 'not the task you started'),
      'another task': (() => asking(principal: 'task:foo-project:else', before: soon), 'not the task you started'),
      'a second principal by a comma': (
        () => asking(principal: 'task:foo-project:work,root', before: soon),
        'which is no task',
      ),
      'an end already past': (
        () => asking(before: DateTime.now().toUtc().subtract(const Duration(minutes: 1))),
        'already ended',
      ),
      'more than the seven days': (
        () => asking(before: DateTime.now().toUtc().add(const Duration(days: 8))),
        'longer than seven days',
      ),
      'a key that does not decode': (() => asking(key: 'ssh-ed25519 AAAA', before: soon), 'not Ed25519'),
      'a certifier that does not decode': (
        () => asking(certifiers: <String>['ssh-ed25519 A'], before: soon),
        'not an Ed25519 key',
      ),
      'an empty identity': (() => asking(keyId: '', before: soon), 'no identity'),
      'no certifier': (() => asking(certifiers: const <String>[], before: soon), 'named no key'),
    };
    for (final each in cases.entries) {
      test(each.key, () async {
        await expectLater(
          certified(each.value.$1(), project: 'foo-project', task: 'work'),
          throwsA(isA<CertifyRefused>().having((r) => r.words, 'words', contains(each.value.$2))),
        );
      });
    }
  });

  // Harm: work in Default on a host cannot start, as Default has no members to name, and the contract
  // says its starter's key certifies it.
  test('a task of no project is certified by the key the agent holds first', () async {
    final certificate = await certified(
      asking(principal: 'task:default:work', certifiers: const <String>[]),
      project: 'default',
      task: 'work',
    );
    expect(certificate, startsWith('ssh-ed25519-cert-v01@openssh.com '));
  });

  // Harm: a host signs a project's task with any key by naming no certifier.
  test('a task of a project naming no certifier is refused, whatever the agent holds', () async {
    await expectLater(
      certified(
        asking(certifiers: const <String>[]),
        project: 'foo-project',
        task: 'work',
      ),
      throwsA(isA<CertifyRefused>().having((r) => r.words, 'words', contains('named no key'))),
    );
  });

  // Harm: a host's key_id reaches ssh-keygen and the certificate; control characters would forge lines.
  // Harm: an older ssh-keygen refuses a time ending in Z, and every certified start fails; without
  // the Z it reads local time, so a window asked for in UTC would be hours off unless it reads UTC too.
  test('the window is written so every ssh-keygen reads it, and reads it as UTC', () async {
    final end = DateTime.utc(2030, 1, 2, 3, 4, 5);
    List<String>? arguments;
    Map<String, String>? given;
    final certificate = await certifyHere(
      asking(before: end),
      now: DateTime.utc(2030),
      environment: <String, String>{...agent, 'TZ': 'America/New_York'},
      run: (name, words, {inDirectory, environment = const {}, input}) async {
        if (words.contains('-V')) {
          arguments = words;
          given = environment;
        }
        return runHere(name, words, inDirectory: inDirectory, environment: environment, input: input);
      },
    );
    expect(arguments![arguments!.indexOf('-V') + 1], '20291231235900:20300102030405');
    expect(given!['TZ'], 'UTC');
    final path = '${home.path}/window-cert.pub';
    await File(path).writeAsString('$certificate\n');
    final read = await Process.run('ssh-keygen', ['-L', '-f', path], environment: {'TZ': 'UTC'});
    expect('${read.stdout}', contains('Valid: from 2029-12-31T23:59:00 to 2030-01-02T03:04:05'));
  });

  test('control characters in the identity do not reach the certificate', () async {
    final end = DateTime.now().toUtc().add(const Duration(days: 1));
    final certificate = await certified(
      asking(before: end, keyId: 'alice\nroot'),
      project: 'foo-project',
    );
    final file = File('${home.path}/control-cert.pub')..writeAsStringSync('$certificate\n');
    final shown = await Process.run('ssh-keygen', ['-L', '-f', file.path]);
    expect('${shown.stdout}', contains('Key ID: "alice?root"'));
  });

  // Harm: the person at the desk is told the key to add, not "add a key".
  test('a card not in the agent is said by its fingerprint', () async {
    final other = await keygen('other');
    final end = DateTime.now().toUtc().add(const Duration(days: 1));
    await expectLater(
      certified(asking(before: end, certifiers: <String>[other])),
      throwsA(
        isA<CertifyRefused>().having(
          (r) => r.words,
          'words',
          allOf(contains('does not hold the key SHA256:'), contains('ssh-add')),
        ),
      ),
    );
  });

  // Harm: an agent gone must say so, not read as a key missing.
  test('no agent says that no agent answers', () async {
    final end = DateTime.now().toUtc().add(const Duration(days: 1));
    await expectLater(
      certifyHere(asking(before: end), environment: <String, String>{'SSH_AUTH_SOCK': '${home.path}/nobody.sock'}),
      throwsA(isA<CertifyRefused>().having((r) => r.words, 'words', contains('No SSH agent answers'))),
    );
  });

  group('over the daemon', () {
    late MockDaemon daemon;
    late List<Map<String, dynamic>> answers;
    late Map<String, dynamic> started;

    setUp(() async {
      daemon = MockDaemon();
      await daemon.start();
      answers = <Map<String, dynamic>>[];
      started = <String, dynamic>{};
      daemon.description = 'method Start(task: ?string, project: ?string, certify: ?bool) -> (exitCode: ?int)';
      daemon.method('Certify', (parameters) {
        answers.add(parameters);
        return <String, dynamic>{};
      });
      daemon.stream('Start', (parameters) async* {
        started = parameters;
        yield <String, dynamic>{
          'certify': <String, dynamic>{
            'start': 's1',
            'key': taskKey,
            'principal': 'task:foo-project:work',
            'key_id': 'alice',
            'valid_before': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
            'certifiers': <String>[person],
          },
        };
        yield <String, dynamic>{'exitCode': 0};
      });
    });
    tearDown(() => daemon.stop());

    PoreloBackend backendAnswering(Future<String> Function(StartCertify) answer) => PoreloBackend(
      Backend(socketPath: daemon.socketPath, label: 'host'),
      certify: (asked, {project, task}) => answer(asked),
    );

    // Harm: a start must not leave a host waiting five minutes for a word it never gets.
    test('a request is answered with the certificate, and the start goes on saying what it signed', () async {
      final backend = backendAnswering((_) async => 'the-certificate');
      await backend.open();
      final events = await backend.startTask(project: 'foo-project', task: 'work').toList();
      expect(started['certify'], true);
      expect(answers.single, <String, dynamic>{'start': 's1', 'certificate': 'the-certificate'});
      expect(events.whereType<StartLine>().single.line, contains('Certified task:foo-project:work'));
    });

    // Harm: a start on this computer waits for what a person's computer signs, and work in Default,
    // with nobody to name, cannot start at all; the contract asks this only of a machine not its own.
    test('a start on this computer asks nothing of the person, as the command line does', () async {
      final here = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'here'), asksToCertify: false);
      await here.open();
      await here.startTask(task: 'work').toList();
      expect(started['certify'], isNot(true));
    });

    test('the machine says whether it asks: another one does, this computer does not', () {
      expect(
        (Machines.overSocket(
          Machine(name: 'here', socketPath: Backend.local().socketPath),
        ) as PoreloBackend).asksToCertify,
        isFalse,
      );
      expect(
        (Machines.overSocket(Machine(name: 'elsewhere', socketPath: daemon.socketPath)) as PoreloBackend).asksToCertify,
        isTrue,
      );
    });

    // Harm: the person must read why, and the host must not wait out its five minutes.
    test('a refusal is answered to the host and said at the start', () async {
      final backend = backendAnswering((_) async => throw const CertifyRefused('Your SSH agent does not hold it.'));
      await backend.open();
      final events = await backend.startTask(project: 'foo-project', task: 'work').toList();
      expect(answers.single, <String, dynamic>{'start': 's1', 'refused': 'Your SSH agent does not hold it.'});
      expect(events.whereType<StartLine>().last.line, 'Your SSH agent does not hold it.');
    });

    // Harm: *Start it again* on a host would wait five minutes for an answer never sent.
    test('starting it again answers too', () async {
      final backend = backendAnswering((_) async => 'the-certificate');
      await backend.open();
      final result = await backend.startAgain(project: 'foo-project', task: 'work');
      expect(started['certify'], true);
      expect(answers.single['certificate'], 'the-certificate');
      expect(result.output.single, contains('Certified task:foo-project:work'));
    });

    // Harm: a hostile host has a dry run sign for it.
    test('a dry run signs nothing even if the host asks', () async {
      var signed = 0;
      final backend = backendAnswering((_) async {
        signed++;
        return 'x';
      });
      await backend.open();
      await backend.startTask(project: 'foo-project', dryRun: true).toList();
      expect(signed, 0);
      expect(answers, isEmpty);
    });

    // Harm: a hostile host has one start sign certificates for several tasks.
    test('one start signs once; a second request is refused unsigned', () async {
      Map<String, dynamic> request(String task) => <String, dynamic>{
        'certify': <String, dynamic>{
          'start': 's1',
          'key': taskKey,
          'principal': 'task:foo-project:$task',
          'key_id': 'alice',
          'valid_before': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
          'certifiers': <String>[person],
        },
      };
      daemon.stream('Start', (parameters) async* {
        yield request('one');
        yield request('two');
        yield <String, dynamic>{'exitCode': 0};
      });
      var signed = 0;
      final backend = backendAnswering((_) async {
        signed++;
        return 'x';
      });
      await backend.open();
      await backend.startTask(project: 'foo-project').toList();
      expect(signed, 1);
      expect(answers.last['refused'], contains('more than once'));
    });

    // Harm: the daemon's later lines hide why, and the person is told only that the start failed.
    test('a refusal is the last word even when the daemon goes on', () async {
      daemon.stream('Start', (parameters) async* {
        yield <String, dynamic>{
          'certify': <String, dynamic>{
            'start': 's1',
            'key': taskKey,
            'principal': 'task:foo-project:work',
            'key_id': 'alice',
            'valid_before': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
            'certifiers': <String>[person],
          },
        };
        yield <String, dynamic>{'line': 'porelo: task certificate refused'};
        yield <String, dynamic>{
          'exitCode': 65,
          'output': <String>['porelo: start failed'],
        };
      });
      final backend = backendAnswering((_) async => throw const CertifyRefused('Your agent lacks it.'));
      await backend.open();
      final lines = <String>[];
      await expectLater(
        backend.startTask(project: 'foo-project', task: 'work').forEach((event) {
          if (event is StartLine) lines.add(event.line);
        }),
        // Harm: "the agent exited" of an agent that never ran.
        throwsA(isA<OperationFailed>().having((failed) => '$failed', 'what is said', contains('no agent ran'))),
      );
      expect(lines.last, 'Your agent lacks it.');
      final again = await backend.startAgain(project: 'foo-project', task: 'work');
      expect(again.output, contains('Your agent lacks it.'));
    });

    // Harm: a start already certified, refused a second time, is said to have run no agent.
    test('a second refusal after a signature does not say no agent ran', () async {
      daemon.stream('Start', (parameters) async* {
        final asked = <String, dynamic>{
          'certify': <String, dynamic>{
            'start': 's1',
            'key': taskKey,
            'principal': 'task:foo-project:work',
            'key_id': 'alice',
            'valid_before': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
            'certifiers': <String>[person],
          },
        };
        yield asked;
        yield asked;
        yield <String, dynamic>{'exitCode': 70};
      });
      final backend = backendAnswering((_) async => 'the-certificate');
      await backend.open();
      await expectLater(
        backend.startTask(project: 'foo-project', task: 'work').drain<void>(),
        throwsA(isA<OperationFailed>().having((failed) => '$failed', 'what is said', isNot(contains('no agent ran')))),
      );
    });

    // Harm: a container that would not start reads as an agent that ran and ended.
    test('a start that ended says so, and names no agent', () {
      expect('${const OperationFailed(70)}', 'It ended with code 70. What it said is in the output above.');
    });

    // Harm: asking a daemon without the input fails every start on every older machine.
    test('an older daemon is not asked', () async {
      daemon.description = 'method Start(task: ?string, project: ?string) -> (exitCode: ?int)';
      daemon.stream('Start', (parameters) async* {
        started = parameters;
        yield <String, dynamic>{'exitCode': 0};
      });
      final backend = backendAnswering((_) async => 'unused');
      await backend.open();
      await backend.startTask(project: 'foo-project', task: 'work').toList();
      expect(started.containsKey('certify'), isFalse);
    });

    // Harm: a dry run starts nothing, and nothing should be signed for it.
    test('a dry run does not ask', () async {
      daemon.stream('Start', (parameters) async* {
        started = parameters;
        yield <String, dynamic>{'exitCode': 0};
      });
      final backend = backendAnswering((_) async => 'unused');
      await backend.open();
      await backend.startTask(project: 'foo-project', dryRun: true).toList();
      expect(started.containsKey('certify'), isFalse);
    });
  });
}

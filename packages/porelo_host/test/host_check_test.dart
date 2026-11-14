import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' show runHostCommand;
import 'host_run_test.dart' show ScriptedRemote;
import 'server_contract_test.dart' show sshKey;

const _script = 'import json\nanswer = {\n  "v": 1,\n}\nprint(json.dumps(answer))\n';
const _limits = '{\n  "memory": 2048\n}\n';

Map<String, Object?> _finding(String state, {String id = 'memory'}) => {
  'id': id,
  'state': state,
  'found': 512,
  'unit': 'MiB',
  'asked': 2048,
  'do': 'Choose a larger machine.',
};

String _answer({bool ok = true, bool complete = true, List<Object?>? findings, Object? v = 1}) => jsonEncode({
  'v': v,
  'ok': ok,
  'complete': complete,
  'findings': findings ?? [_finding('pass')],
});

/// A ustar archive of [files], each under [leading], with a directory entry first as `tar` writes one.
List<int> _collection(Map<String, String> files, {String leading = ''}) {
  List<int> header(String name, int size, int type) {
    final block = List<int>.filled(512, 0);
    void put(int at, String text) => block.setRange(at, at + text.length, latin1.encode(text));
    put(0, name);
    put(100, '0000644\u0000');
    put(108, '0000000\u0000');
    put(116, '0000000\u0000');
    put(124, '${size.toRadixString(8).padLeft(11, '0')}\u0000');
    put(136, '00000000000\u0000');
    put(148, '        ');
    block[156] = type;
    put(257, 'ustar\u0000');
    put(263, '00');
    final sum = block.reduce((a, b) => a + b);
    put(148, '${sum.toRadixString(8).padLeft(6, '0')}\u0000 ');
    return block;
  }

  final tar = <int>[
    if (leading.isNotEmpty) ...header('$leading/', 0, 0x35),
    for (final entry in files.entries) ...[
      ...header('$leading${leading.isEmpty ? '' : '/'}${entry.key}', utf8.encode(entry.value).length, 0x30),
      ...utf8.encode(entry.value),
      ...List<int>.filled(-utf8.encode(entry.value).length % 512, 0),
    ],
    ...List<int>.filled(1024, 0),
  ];
  return gzip.encode(tar);
}

const _withCheck = {
  'galaxy.yml': 'name: host\n',
  'roles/check/files/limits.json': _limits,
  'roles/check/files/porelo-host-check': _script,
};

/// An ssh that answers as told, and keeps what it was given on standard input.
class _Ssh implements Process {
  _Ssh({this.out = '', this.err = '', this.code = 0}) {
    final input = StreamController<List<int>>();
    input.stream.transform(utf8.decoder).listen(given.write);
    stdin = IOSink(input.sink);
  }

  final String out;
  final String err;
  final int code;
  final given = StringBuffer();
  @override
  late final IOSink stdin;
  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(out));
  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(err));
  @override
  Future<int> get exitCode async => code;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => killed = true;
  bool killed = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Checked extends ScriptedRemote {
  _Checked(this.answer, this.answerExit)
    : super([
        jsonEncode({'v': 1, 'state': 'ok', 'task': 'finished', 'text': 'Host ready'}),
        jsonEncode({
          'v': 1,
          'state': 'host',
          'host': {
            'address': '192.0.2.7',
            'ssh_host_key': sshKey,
            'homeserver': 'orchard',
            'services': {
              'forge': {'web_port': 3000, 'git_port': 3001},
            },
          },
        }),
      ]);

  final String answer;
  final int answerExit;
  var asked = 0;
  var changedBefore = false;

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    if (command.startsWith('python3 - --limits ')) {
      asked++;
      changedBefore = commands.any((each) => each.contains('mkdir'));
      for (final line in const LineSplitter().convert(answer)) {
        onLine?.call(line);
      }
      return RemoteResult(answerExit, '');
    }
    return super.run(host, user, command, input: input, onLine: onLine);
  }
}

void main() {
  // Harm: a root login still held by the provider's line reads as a check without an answer, and the person, told
  // nothing, never runs the bootstrap line.
  group('a root login that still answers with the provider\'s line', () {
    const providers = 'Please login as the user "ubuntu" rather than the user "root".';
    Future<HostCheckAnswer> asked({required String out, required int exit, String err = ''}) => askHostCheck(
      const HostCheckFiles(script: _script, limits: _limits),
      choices: const {'forge': false},
      send: (command, script, onLine) async {
        for (final line in const LineSplitter().convert(out)) {
          onLine(line);
        }
        return RemoteResult(exit, err);
      },
    );

    test('says the bootstrap line has not run, with the provider\'s words', () async {
      final answer = await asked(out: '$providers\n', exit: 142);
      expect(answer.answered, isFalse);
      expect(answer.said, contains('The bootstrap line has not run'));
      expect(answer.said, contains(providers));
    });

    test('says so by the words alone, whatever the exit', () async {
      final answer = await asked(out: '$providers\n', exit: 1);
      expect(answer.said, contains('The bootstrap line has not run'));
    });

    test('a check with no answer and nothing on standard error names its last line on standard output', () async {
      final answer = await asked(out: 'something went wrong here\n', exit: 3);
      expect(answer.answered, isFalse);
      expect(answer.said, contains('something went wrong here'));
      expect(answer.said, contains('exit 3'));
    });
  });

  // Harm: `up` on the command line, or a run started again, changes the machine first and finds out after.
  group('up, with a collection that holds a check', () {
    Future<(int, _Checked, String)> upWith(String answer, int exit) async {
      final scratch = await Directory.systemTemp.createTemp('up-check-');
      addTearDown(() => scratch.delete(recursive: true));
      final tar = _collection({'roles/check/files/porelo-host-check': _script, 'roles/check/files/limits.json': '{}'});
      final collection = await File('${scratch.path}/c.tar.gz').writeAsBytes(tar);
      final machine = await File('${scratch.path}/machine.yml').writeAsString('organization:\n  pin: "x"\n');
      final remote = _Checked(answer, exit);
      final output = StringBuffer();
      final code = await runHostCommand(
        [
          'up',
          '--public-key',
          sshKey,
          '--given',
          '192.0.2.7',
          '--host-key',
          sshKey,
          '--host-name',
          'orchard',
          '--collection',
          collection.path,
          '--collection-sha256',
          sha256.convert(tar).toString(),
          '--machine-file',
          machine.path,
        ],
        remote: remote,
        output: output,
        errors: StringBuffer(),
        environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
      );
      return (code, remote, '$output');
    }

    test('a machine that fails it is refused, with every fault, before any change', () async {
      final (code, remote, output) = await upWith(_answer(ok: false, findings: [_finding('fail')]), 1);
      expect(code, Exit.refused);
      expect(remote.asked, 1);
      expect(remote.changedBefore, isFalse);
      expect(remote.commands.where((each) => each.contains('mkdir') || each.contains('apt-get')), isEmpty);
      expect(output, contains('memory'));
    });

    test('a check that gives no answer installs nothing', () async {
      final (code, remote, _) = await upWith('not json', 2);
      expect(code, Exit.refused);
      expect(remote.commands.where((each) => each.contains('apt-get')), isEmpty);
    });

    test('a machine that passes goes on', () async {
      final (_, remote, _) = await upWith(_answer(), 0);
      expect(remote.asked, 1);
      expect(remote.commands.any((each) => each.contains('apt-get') || each.contains('collection.tar.gz')), isTrue);
    });
  });

  // Harm: a limit a person may give is read as none by the check, and a large machine fails.
  test('a memory limit in bytes with its letter reaches the check as the check reads it', () {
    final choices = hostCheckChoices(const HostPreparationSettings(forgeJobMemory: '805306368b'), forge: true);
    expect(choices['job_memory'], '805306368');
    final kept = hostCheckChoices(const HostPreparationSettings(forgeJobMemory: '768m'), forge: true);
    expect(kept['job_memory'], '768m');
  });

  // Harm: a hostile size repeats one header for ever, on the window's thread.
  test('a tar entry with a size below nothing is refused rather than read again and again', () {
    final tar = gzip.decode(_collection({'a': 'b'}));
    final bytes = List<int>.of(tar);
    bytes.setRange(124, 136, latin1.encode('-0000002000\u0000'));
    bytes.fillRange(148, 156, 32);
    final sum = bytes.sublist(0, 512).reduce((a, b) => a + b);
    bytes.setRange(148, 156, latin1.encode('${sum.toRadixString(8).padLeft(6, '0')}\u0000 '));
    expect(readHostCheckFiles(gzip.encode(bytes)), isNull);
  });

  // Harm: the script says what kind of fault stopped it, and the person reads only that it could not run.
  test('the script\'s own reason at exit 2 is said', () {
    final answer = HostCheckAnswer.read(
      '{"v": 1, "ok": false, "complete": false, "findings": [], "why": "PermissionError"}',
      exitCode: 2,
    );
    expect(answer.answered, isFalse);
    expect(answer.said, contains('PermissionError'));
  });

  group('the answer', () {
    // Harm: an answer of any finding's state is not shown as it is, and a machine is prepared on a misread.
    for (final state in HostCheckState.values) {
      test('${state.name} reads as itself', () {
        final fails = state == HostCheckState.fail;
        final answer = HostCheckAnswer.read(
          _answer(ok: !fails, findings: [_finding(state.name)]),
          exitCode: fails ? 1 : 0,
        );
        expect(answer.findings.single.state, state);
        expect(answer.passed, !fails);
      });
    }

    // Harm: a finding this window has not heard of is dropped, and a fault goes unseen.
    test('an id nobody here knows is kept, with a value of any shape', () {
      final finding = HostCheckAnswer.read(
        _answer(
          ok: false,
          findings: [
            {
              'id': 'new.thing',
              'state': 'fail',
              'found': {
                'a': [1, null],
              },
              'asked': [true],
              'unit': null,
              'do': null,
            },
          ],
        ),
        exitCode: 1,
      ).findings.single;
      expect(finding.id, 'new.thing');
      expect(finding.found, {
        'a': [1, null],
      });
      expect(finding.asked, [true]);
    });

    // Harm: anything broken or at odds with itself reads as a passed machine, and the installation runs on it.
    final broken = <String, (String, int)>{
      'no JSON': ('Traceback', 0),
      'empty': ('', 0),
      'not an object': ('[1]', 0),
      'another version': (_answer(v: 2), 0),
      'a version in words': (_answer(v: '1'), 0),
      'no findings field': ('{"v":1,"ok":true,"complete":true}', 0),
      'ok not a boolean': ('{"v":1,"ok":"true","complete":true,"findings":[]}', 0),
      'a state out of the contract': (_answer(findings: [_finding('fine')]), 0),
      'a finding without an id': (
        _answer(
          findings: [
            {'state': 'pass'},
          ],
        ),
        0,
      ),
      'words that are no text': (
        _answer(
          findings: [
            {'id': 'a', 'state': 'pass', 'do': 1},
          ],
        ),
        0,
      ),
      'a pass of nothing': (_answer(findings: []), 0),
      'exit 0 with ok false': (_answer(ok: false, findings: [_finding('fail')]), 0),
      'exit 0 not complete': (_answer(complete: false), 0),
      'exit 1 with ok true and complete': (_answer(), 1),
      'ok true beside a failure': (_answer(findings: [_finding('fail')]), 0),
      'exit 1 with nothing failing': (_answer(ok: false), 1),
      'exit 2 with an answer that passes': (_answer(), 2),
      'another exit': (_answer(), 3),
    };
    for (final entry in broken.entries) {
      test('${entry.key} reads as no answer', () {
        final answer = HostCheckAnswer.read(entry.value.$1, exitCode: entry.value.$2);
        expect(answer.passed, isFalse);
        expect(answer.answered, isFalse);
        expect(answer.exitCode, 2);
        expect(answer.said, isNotEmpty);
      });
    }

    // Harm: a check that stopped halfway is taken for a machine with nothing wrong.
    test('ok beside complete false is not passed either', () {
      final answer = HostCheckAnswer.read(_answer(complete: false), exitCode: 1);
      expect(answer.passed, isFalse);
      expect(answer.exitCode, 1);
    });

    test('complete false is not passed, and its findings stand', () {
      final answer = HostCheckAnswer.read(_answer(ok: false, complete: false), exitCode: 1);
      expect(answer.passed, isFalse);
      expect(answer.answered, isTrue);
      expect(answer.findings, hasLength(1));
      expect(answer.exitCode, 1);
    });
  });

  group('the collection', () {
    // Harm: a real collection's own layout hides its check, and every host goes on unchecked.
    for (final leading in ['', 'x', 'porelo-host-0.6.0']) {
      test('reads the check under leading "$leading"', () {
        final files = readHostCheckFiles(_collection(_withCheck, leading: leading))!;
        expect(files.script, _script);
        expect(jsonDecode(files.limits), {'memory': 2048});
        expect(files.limits, isNot(contains('\n')));
      });
    }

    test('a name beginning with ./ is the same name', () {
      expect(
        readHostCheckFiles(
          _collection({'./roles/check/files/limits.json': _limits, './roles/check/files/porelo-host-check': _script}),
        )?.script,
        _script,
      );
    });

    // Harm: the dialog offers a check that cannot run, on the collection pinned today.
    test('a collection without a check, or half of one, holds none', () {
      expect(readHostCheckFiles(_collection({'galaxy.yml': 'name: host\n'})), isNull);
      expect(readHostCheckFiles(_collection({'roles/check/files/limits.json': _limits})), isNull);
      expect(readHostCheckFiles(_collection({'roles/check/files/porelo-host-check': _script})), isNull);
    });

    test('a path that only ends the same is not the check', () {
      expect(
        readHostCheckFiles(
          _collection({
            'a/b/roles/check/files/limits.json': _limits,
            'a/b/roles/check/files/porelo-host-check': _script,
          }),
        ),
        isNull,
      );
    });

    // Harm: a damaged file is read as if whole, and what is sent to the machine is not the collection's.
    test('what is no gzipped tar, a truncated one and limits of no JSON hold no check', () {
      expect(readHostCheckFiles([1, 2, 3]), isNull);
      expect(readHostCheckFiles(gzip.encode(List<int>.filled(512, 7))), isNull);
      final whole = gzip.decode(_collection(_withCheck));
      expect(readHostCheckFiles(gzip.encode(whole.sublist(0, 512 * 4 + 10))), isNull);
      final cutBehindTheCheck = gzip.decode(_collection({..._withCheck, 'zz-last': List.filled(2000, 'x').join()}));
      expect(readHostCheckFiles(gzip.encode(cutBehindTheCheck.sublist(0, cutBehindTheCheck.length - 2600))), isNull);
      expect(
        readHostCheckFiles(
          _collection({'roles/check/files/limits.json': 'not json', 'roles/check/files/porelo-host-check': _script}),
        ),
        isNull,
      );
    });
  });

  group('porelo-host check', () {
    late Directory scratch;
    late File collection;
    late String digest;
    late StringBuffer output;
    late StringBuffer errors;
    final started = <List<String>>[];
    late _Ssh ssh;

    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('host-check-');
      collection = File('${scratch.path}/collection.tar.gz');
      await collection.writeAsBytes(_collection(_withCheck, leading: 'porelo-host-0.6.0'));
      digest = sha256.convert(await collection.readAsBytes()).toString();
      output = StringBuffer();
      errors = StringBuffer();
      started.clear();
      ssh = _Ssh(out: '${_answer()}\n');
    });
    tearDown(() => scratch.delete(recursive: true));

    Future<int> check([List<String> extra = const []]) => runHostCommand(
      [
        'check',
        '--given',
        '192.0.2.7',
        '--host-key',
        sshKey,
        '--public-key',
        sshKey,
        '--collection',
        collection.path,
        '--collection-sha256',
        digest,
        ...extra,
      ],
      output: output,
      errors: errors,
      startSsh: (_, arguments) async {
        started.add(arguments);
        return ssh;
      },
    );

    Map<String, Object?> printed() {
      final lines = const LineSplitter().convert('$output');
      expect(lines, hasLength(1), reason: 'exactly one JSON object');
      return jsonDecode(lines.single) as Map<String, Object?>;
    }

    // Harm: a check that touched the machine other than by the one read-only script would change it before its yes.
    test('a passing machine: one ssh as root, the script on its input, its answer and exit 0', () async {
      expect(await check(), 0);
      expect(started, hasLength(1));
      expect(started.single, contains('root@192.0.2.7'));
      expect(started.single, containsAllInOrder(['-F', '/dev/null']), reason: 'No configuration of this computer.');
      expect(started.single, contains('PreferredAuthentications=publickey'));
      expect(started.single.last, startsWith('python3 - --limits '));
      expect('${ssh.given}', _script);
      expect(printed()['ok'], isTrue);
    });

    // Harm: a machine streaming without end fills this computer's memory before any deadline.
    test('an answer without end is cut off and reads as no answer', () async {
      ssh = _Ssh(out: 'x' * (2 * 1024 * 1024));
      expect(await check(), 2);
      expect(ssh.killed, isTrue);
      expect(printed()['said'], contains('far more'));
    });

    // Harm: the script's own lines, such as a lone `}`, are cut out of its answer, and no answer ever reads.
    test('the answer comes back whole although its characters stand as lines of the script', () async {
      expect(await check(), 0);
      expect(printed()['findings'], [_finding('pass')]);
    });

    // Harm: a check is asked of another machine's key, or of the person's own known hosts.
    test('it pins only the given key, in a file of its own that is gone after', () async {
      String? pinned;
      await runHostCommand(
        [
          'check',
          '--given',
          '192.0.2.7',
          '--host-key',
          sshKey,
          '--public-key',
          sshKey,
          '--collection',
          collection.path,
          '--collection-sha256',
          digest,
        ],
        output: output,
        errors: errors,
        startSsh: (_, arguments) async {
          final option = arguments.singleWhere((each) => each.startsWith('UserKnownHostsFile='));
          pinned = option.substring('UserKnownHostsFile="'.length, option.length - 1);
          expect(await File(pinned!).readAsString(), '192.0.2.7 $sshKey\n');
          return ssh;
        },
      );
      expect(pinned, isNotNull);
      expect(File(pinned!).existsSync(), isFalse);
    });

    // Harm: the choices never reach the check, so its list says nothing of what was chosen.
    test('the choices go as JSON, and this computer\'s forward ports do not', () async {
      await check([
        '--kvm',
        'true',
        '--forge',
        'true',
        '--forge-runner-capacity',
        '2',
        '--forge-job-cpus',
        '3',
        '--forge-job-memory',
        '768m',
        '--forge-web-port',
        '4000',
      ]);
      final choices = started.single.last.split('--choices ').last;
      expect(jsonDecode(choices.substring(1, choices.length - 1)), {
        'forge': true,
        'kvm': true,
        'jobs': 2,
        'job_cpus': 3,
        'job_memory': '768m',
      });
    });

    test('an unchosen kvm is not sent, and an absent forge is the forge up would install', () async {
      await check();
      final choices = started.single.last.split('--choices ').last;
      expect(jsonDecode(choices.substring(1, choices.length - 1)), {'forge': true});
    });

    // Harm: findings of a failing machine are lost on the way to the window.
    test('a machine with faults: its answer and exit 1', () async {
      ssh = _Ssh(
        out: _answer(
          ok: false,
          findings: [
            _finding('fail'),
            _finding('warn', id: 'disk'),
          ],
        ),
        code: 1,
      );
      expect(await check(), 1);
      expect(printed()['findings'], hasLength(2));
    });

    // Harm: each of these reads as passed, or as a silence, and the person cannot tell what to do.
    final refusals = <String, (_Ssh, String)>{
      'a refused login': (
        _Ssh(err: 'root@192.0.2.7: Permission denied (publickey).\n', code: 255),
        'refused the login',
      ),
      'another host key': (_Ssh(err: 'Host key verification failed.\n', code: 255), 'another SSH host key'),
      'a machine not reached': (
        _Ssh(err: 'ssh: connect to host 192.0.2.7 port 22: No route to host\n', code: 255),
        'does not reach',
      ),
      'no python3': (_Ssh(err: 'bash: line 1: python3: command not found\n', code: 127), 'no python3'),
      'the check not able to run': (
        _Ssh(out: '{"v":1,"ok":false,"complete":false,"findings":[]}', code: 2),
        'could not run',
      ),
      'nothing printed, exit 0': (_Ssh(), 'cannot be read'),
      'a traceback, exit 1': (_Ssh(out: 'junk', err: 'Traceback\nValueError: x\n', code: 1), 'ValueError'),
    };
    for (final entry in refusals.entries) {
      test('${entry.key} prints one object saying so, and exit 2', () async {
        ssh = entry.value.$1;
        expect(await check(), 2);
        final answer = printed();
        expect(answer['ok'], isFalse);
        expect(answer['complete'], isFalse);
        expect(answer['findings'], isEmpty);
        expect(answer['said'], contains(entry.value.$2));
      });
    }

    // Harm: without its check the command would still log in and say nothing useful.
    test('a collection with no check starts no ssh', () async {
      await collection.writeAsBytes(_collection({'galaxy.yml': 'name: host\n'}));
      digest = sha256.convert(await collection.readAsBytes()).toString();
      expect(await check(), 2);
      expect(started, isEmpty);
      expect(printed()['said'], contains('no check'));
    });

    // Harm: a script no digest vouches for is run as root on the person's machine.
    test('a collection with another digest starts no ssh', () async {
      digest = List.filled(64, 'a').join();
      expect(await check(), 2);
      expect(started, isEmpty);
    });

    test('a bad address starts no ssh and says so', () async {
      expect(
        await runHostCommand(
          [
            'check',
            '--given',
            'a b',
            '--host-key',
            sshKey,
            '--public-key',
            sshKey,
            '--collection',
            collection.path,
            '--collection-sha256',
            digest,
          ],
          output: output,
          errors: errors,
          startSsh: (_, arguments) async => throw StateError('must not start'),
        ),
        2,
      );
      expect(printed()['ok'], isFalse);
    });

    group('--available', () {
      Future<int> available(List<String> extra, {String? executable}) => runHostCommand(
        ['check', '--available', ...extra],
        output: output,
        errors: errors,
        resolvedExecutable: executable,
      );

      // Harm: the dialog stands on the answer here: a wrong yes offers a check that cannot run, a wrong no skips it.
      test('holds a check: 0, printing nothing', () async {
        expect(await available(['--collection', collection.path, '--collection-sha256', digest]), 0);
        expect('$output$errors', isEmpty);
      });

      // Harm: a collection without a check is said as one, so the person knows preparing runs unchecked.
      test('holds none: 4, saying so in one line', () async {
        await collection.writeAsBytes(_collection({'galaxy.yml': 'name: host\n'}));
        digest = sha256.convert(await collection.readAsBytes()).toString();
        expect(await available(['--collection', collection.path, '--collection-sha256', digest]), 4);
        expect('$output', 'The collection carried here holds no check, so preparing runs without one.\n');
        expect('$errors', isEmpty);
      });

      // Harm: a missing collection reads as one that merely holds no check, and the broken install goes unseen.
      test('nothing beside this command: 4, naming where it looked', () async {
        expect(await available(const [], executable: '${scratch.path}/porelo-host'), 4);
        expect('$output', contains('No collection is carried here'));
        expect('$output', contains('${scratch.path}/${hostCollection.fileName}'));
      });

      // Harm: a collection no digest vouches for reads as one without a check, and nobody looks at what changed it.
      test('the pinned name beside this command with another digest: 4, saying it is not the pinned one', () async {
        await collection.copy('${scratch.path}/${hostCollection.fileName}');
        expect(await available(const [], executable: '${scratch.path}/porelo-host'), 4);
        expect('$output', contains('is not the one this porelo-host was built with'));
        expect('$output', isNot(contains('holds no check')));
      });

      // Harm: a package that installs the collection for root alone reads as one without a check, as it did.
      test('a collection this account cannot read: 4, saying it cannot be read', () async {
        await collection.writeAsBytes(_collection(_withCheck));
        digest = sha256.convert(await collection.readAsBytes()).toString();
        await Process.run('chmod', ['000', collection.path]);
        addTearDown(() => Process.run('chmod', ['600', collection.path]));
        expect(await available(['--collection', collection.path, '--collection-sha256', digest]), 4);
        expect('$output', contains('cannot be read'));
        expect('$output', contains(collection.path));
        expect('$output', isNot(contains('holds no check')));
      }, skip: Platform.isWindows || _runsAsRoot() ? 'root reads it anyway, and Windows has no chmod' : false);
    });
  });
}

/// Whether this test runs as root, who reads a file whatever its mode.
bool _runsAsRoot() => !Platform.isWindows && (Process.runSync('id', ['-u']).stdout as String).trim() == '0';

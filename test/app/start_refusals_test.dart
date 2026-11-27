import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/agent_sign_in.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/app/start_refusals.dart';

const _tasks1 = 'org.fuin.porelo.Tasks1';

String _words(String name, [Map<String, dynamic> parameters = const <String, dynamic>{}]) =>
    startRefusalWords(VarlinkException('$_tasks1.$name', parameters), machine: 'build-host');

void main() {
  // Harm: a person reads a type name and does not know that a sign-in is missing, or where; every other refusal of
  // Start reads as a riddle the same way.
  group("each of Start's refusals is said in words, never by the wire's type name", () {
    test('a missing sign-in names the agent and the machine, and that a sign-in runs where one does', () {
      final missing = _words('SignInNeeded', {'agent': 'claude'});
      expect(missing, contains('claude is not signed in on build-host'));
      expect(missing, contains('Sign it in there, then start again'));
      expect(missing, isNot(contains('already runs')));

      final running = _words('SignInNeeded', {'agent': 'claude', 'running': 'porelo-login-claude'});
      expect(running, contains('claude is not signed in on build-host'));
      expect(running, contains('A sign-in to it already runs there'));
      expect(_words('SignInNeeded', {'agent': 'claude', 'running': ''}), contains('already runs'));
    });

    test('the agent is called by its label where the machine gave one', () {
      final words = startRefusalWords(const SignInNeeded('claude', label: 'Claude Code'), machine: 'build-host');
      expect(words, startsWith('Claude Code is not signed in on build-host'));
    });

    test("a missing sign-in passed through Start's stream is the typed refusal, said alike", () async {
      final refused = Stream<StartProgress>.error(
        const VarlinkException('$_tasks1.SignInNeeded', <String, dynamic>{'agent': 'claude'}),
      ).transform(startRefusalsSaid);
      await expectLater(refused, emitsError(isA<SignInNeeded>().having((it) => it.agent, 'agent', 'claude')));
    });

    test('every other refusal of Start in its own words, naming what it is about', () {
      final said = <String, String>{
        'VaultLocked': _words('VaultLocked'),
        'FirstStartRefused': _words('FirstStartRefused', {
          'reason': 'MOVED_ON',
          'detail': 'The project file changed since it was read',
        }),
        'UnknownHostKey': _words('UnknownHostKey', {
          'host': 'git.example.org',
          'hostKeys': <Object>[],
          'detail': 'Trust its key first',
        }),
        'BranchTaken': _words('BranchTaken', {
          'task': 'fix',
          'branch': 'porelo/fix',
          'detail': 'Another task holds it',
        }),
        'ContainerNameTaken': _words('ContainerNameTaken', {
          'container': 'porelo-demo-fix',
          'project': 'demo',
          'task': 'fix',
          'ownerProject': 'other',
          'ownerTask': 'mend',
        }),
        'AlreadyStarting': _words('AlreadyStarting', {'task': 'fix'}),
        'MadeWithAnother': _words('MadeWithAnother', {'task': 'fix', 'agent': 'codex', 'model': ''}),
        'NoSuchTask': _words('NoSuchTask', {'task': 'fix'}),
        'EarlierWorkWaits': _words('EarlierWorkWaits', {'task': 'fix', 'commit': '', 'subject': ''}),
        'UpstreamUnreadable': _words('UpstreamUnreadable', {'cause': 'NOT_FOUND', 'detail': '', 'fix': ''}),
        'NoSuchDestination': _words('NoSuchDestination', {'name': 'extra'}),
      };
      for (final MapEntry(key: name, value: words) in said.entries) {
        expect(words, isNot(contains(name)), reason: '$name is said in words, not by its name');
        expect(words, isNotEmpty, reason: name);
      }
      expect(said['VaultLocked'], contains('The vault on build-host is locked'));
      expect(said['FirstStartRefused'], contains('The project file changed since it was read'));
      expect(said['UnknownHostKey'], allOf(contains('git.example.org'), contains('Trust its key first')));
      expect(said['BranchTaken'], allOf(contains('porelo/fix'), contains('Another task holds it')));
      expect(said['ContainerNameTaken'], allOf(contains('porelo-demo-fix'), contains('mend of other')));
      expect(said['AlreadyStarting'], contains('fix is being started on build-host'));
      expect(said['MadeWithAnother'], contains('codex'));
      expect(said['NoSuchTask'], contains('build-host has no task fix'));
      expect(said['EarlierWorkWaits'], contains('still waits at the gate'));
      expect(said['NoSuchDestination'], contains('The credential extra'));
    });

    // Harm: a person reads a wire name and cannot tell which right a task holds, or reads one label for another right.
    test('each of Porelo\'s rights has its own plain words, and one the window does not know its name', () {
      const labels = <String, String>{
        'push': 'push work to the gate',
        'reply': 'reply in threads',
        'openThreads': 'open threads',
        'resolveThreads': 'resolve threads',
        'start': 'start tasks',
        'stop': 'stop the tasks it started',
        'done': 'report its own end',
        'report': 'hand back a result',
        'reject': 'reject a waiting push',
      };
      for (final MapEntry(key: right, value: label) in labels.entries) {
        expect(rightLabel(right), label, reason: right);
      }
      expect(rightLabel('mergeThreads'), 'mergeThreads', reason: 'said by its raw name, never left out');
    });

    // Harm: a name the machine sent breaks the line it is said in, turns its text around or fills the window.
    test('a right or a rule the machine sent is said without controls and never longer than a name', () {
      expect(rightLabel('merge${String.fromCharCode(0x202e)}Threads\nnow'), 'mergeThreadsnow');
      expect(
        _words('StartRuleBroken', {'rule': 'r' * 200, 'detail': ''}),
        'build-host refused the start: it breaks the rule ${'r' * 64}….',
      );
    });

    // Harm: a refusal no method of the machine answers keeps words of its own, and a later machine's error of that
    // name is said with values the window never checked.
    test('a missing right, which no call answers, is worded like any refusal the window does not know', () {
      final bare = _words('RightMissing', {'right': 'push', 'act': 'hunter2-secret'});
      expect(bare, 'build-host refused (RightMissing: right, act).');
      expect(bare, isNot(contains('hunter2-secret')), reason: 'no value is ever shown');
    });

    test('changed rights on a resume say that a new task is needed', () {
      final changed = _words('RightsChanged');
      expect(changed, contains('keeps the workspace, equipment and rights it was started with'));
      expect(changed, contains('Start a new task'));
      expect(changed, isNot(contains('RightsChanged')));
    });

    test("a broken rule of a start is said in words, the machine's detail beside it", () {
      const known = <String, String>{
        'foreignWorkLeadsOut': 'cannot hold project services',
        'foreignWorkNamesNoRights': 'must be started with its rights named',
        'rejectWithPush': 'together with the right to push',
        'rejectOverOwnWork': 'cannot reject its own work',
        'pushWithoutOwnWork': 'only a task on its own work',
        'exceedsParent': 'more than the task that started it',
      };
      for (final MapEntry(key: rule, value: part) in known.entries) {
        final words = _words('StartRuleBroken', {'rule': rule, 'detail': 'read\nOnly'});
        expect(words, startsWith('build-host refused the start: '), reason: rule);
        expect(words, contains(part), reason: rule);
        // The machine's detail names the part that breaks the rule, a word and no sentence: said as that, on one line.
        expect(words, endsWith('. What breaks it: readOnly.'), reason: rule);
        expect(words, isNot(contains(rule)), reason: '$rule is said in words');
        expect(words, isNot(contains('StartRuleBroken')), reason: rule);
      }
      expect(
        _words('StartRuleBroken', {'rule': 'somethingNew', 'detail': ''}),
        'build-host refused the start: it breaks the rule somethingNew.',
      );
    });

    test('an account named where there is no pull request says where one is chosen', () {
      final words = startRefusalWords(
        const VarlinkException('org.varlink.service.InvalidParameter', <String, dynamic>{'parameter': 'writeAs'}),
        machine: 'build-host',
      );
      expect(words, 'build-host refused the start: an account to write as is chosen only for a pull request.');
      // Any other refused parameter keeps the generic words: it is no start's refusal.
      expect(
        startRefusalWords(
          const VarlinkException('org.varlink.service.InvalidParameter', <String, dynamic>{'parameter': 'task'}),
          machine: 'build-host',
        ),
        'build-host refused (InvalidParameter: parameter).',
      );
    });

    test('an unknown refusal is said by its detail, and without one never by its type name alone', () {
      expect(
        _words('SomethingNew', {'detail': 'The moon is in the way'}),
        'build-host refused: The moon is in the way.',
      );
      // Harm: a value the machine sent with an unknown refusal, a secret among them, is shown on screen.
      final bare = _words('SomethingNew', {'which': 'moon', 'token': 'hunter2-secret'});
      expect(bare, 'build-host refused (SomethingNew: which, token).');
      expect(bare, isNot(contains('moon')), reason: 'no value is ever shown');
      expect(bare, isNot(contains('hunter2-secret')), reason: 'no value is ever shown');
      expect(bare, isNot(contains(_tasks1)), reason: 'not the wire name');
    });
  });

  // Harm: a start refused for a sign-in ends its operation with the wire's error as its last line, and the person
  // does not know which agent needs signing in, or where.
  test("a start's operation refused for a missing sign-in ends in words naming the agent and the machine", () async {
    final operations = Operations(saveDelay: Duration.zero);
    final output = StreamController<Object>();
    final operation = operations.run(title: 'Start work in demo', machine: 'build-host', output: output.stream);
    output.addError(
      startRefusalSaid(const VarlinkException('$_tasks1.SignInNeeded', <String, dynamic>{'agent': 'claude'})),
    );
    await output.close();
    await pumpEventQueue();

    expect(operation.failed, isTrue);
    expect(operation.summary, startsWith('claude is not signed in on build-host'));
    expect(operation.summary, isNot(contains('SignInNeeded')));
    operations.dispose();
  });

  // Harm: a failure of an operation that is no start, a stop or a removal, reads as a refused start, and the person
  // looks for a start that never was.
  test('a stop or a removal that fails is said in words that fit it, never as a start', () async {
    final operations = Operations(saveDelay: Duration.zero);
    final failures = <String, Object>{
      'Stop fix': const VarlinkException('$_tasks1.NoSuchTask', <String, dynamic>{'task': 'fix'}),
      'Remove fix': const VarlinkException('$_tasks1.VaultLocked'),
      'Remove mend': const VarlinkException('$_tasks1.HoldsWork', <String, dynamic>{'files': 3}),
    };
    final ended = <Operation>[];
    for (final MapEntry(key: title, value: failure) in failures.entries) {
      final output = StreamController<Object>();
      ended.add(operations.run(title: title, machine: 'build-host', output: output.stream));
      output.addError(failure);
      await output.close();
    }
    await pumpEventQueue();

    for (final operation in ended) {
      expect(operation.failed, isTrue);
      expect(operation.summary, contains('build-host'), reason: operation.title);
      expect(operation.summary.toLowerCase(), isNot(contains('start')), reason: operation.title);
      expect(operation.summary, isNot(contains(_tasks1)), reason: operation.title);
    }
    operations.dispose();
  });

  group('the sign-ins starts were refused for', () {
    // Harm: every refused start of one agent adds a row of its own, and Needs you fills with the same sign-in.
    test('a second refusal for the same machine and agent adds no second row', () {
      final needed = SignInsNeeded();
      var made = 0;
      SigningIn make() {
        made++;
        return SigningIn();
      }

      expect(needed.need('build-host', 'claude', make), isTrue);
      expect(needed.need('build-host', 'claude', make), isTrue, reason: 'its row still stands');
      expect(needed.need('laptop', 'claude', make), isTrue);
      expect(made, 2, reason: 'one sign-in per machine and agent');
      expect(needed.all, hasLength(2));
      needed.dispose();
    });

    // Harm: a sign-in for a machine no longer watched stays offered, and its press asks a machine nobody watches.
    test('a row is dropped once its machine is no longer watched', () {
      final needed = SignInsNeeded();
      needed
        ..need('build-host', 'claude', () => SigningIn()..machine = 'build-host')
        ..need('laptop', 'claude', () => SigningIn()..machine = 'laptop');

      needed.keepOnly((machine) => machine == 'laptop');

      expect(needed.all.map((each) => each.machine), ['laptop']);
      needed.dispose();
    });
  });
}

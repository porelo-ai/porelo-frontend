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

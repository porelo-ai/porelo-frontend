import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
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
      final bare = _words('SomethingNew', {'which': 'moon'});
      expect(bare, contains('build-host refused'));
      expect(bare, contains('which moon'));
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
}

// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/outcome_words.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// Drives the real client over a real unix socket against [MockDaemon].
///
/// Over a socket rather than by calling the methods directly: what is being checked is the wire,
/// and a call that never crosses it proves nothing about the framing, the streaming or the
/// disconnect handling - which is all of what is hard here.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(
      Backend(socketPath: daemon.socketPath, label: 'mock'));

  Map<String, dynamic> task(String name, {bool running = true, int helpers = 4}) => {
        'name': name,
        'project': 'demo',
        'securityClass': 'guarded',
        'state': running ? 'Up 2 minutes' : 'Exited (143) 1 second ago',
        'running': running,
        'helpers': helpers,
      };

  group('talking to a backend', () {
    test('a task name is asked about with readiness, and a bad one comes back as such', () async {
      Map<String, dynamic>? asked;
      daemon.method('CanStart', (parameters) {
        asked = parameters;
        return <String, dynamic>{
          'ready': false,
          'outcome': 'BAD_TASK_NAME',
          'agent': 'claude',
          'provider': '',
          'credential': '',
          'detail': "'Foo Bar' is not a task name: use lowercase letters, digits and hyphens - 'foo-bar' would do",
        };
      });

      final answer = await (await connect()).canStart(project: '/srv/demo/project.yml', task: 'Foo Bar');

      expect(asked, containsPair('task', 'Foo Bar'));
      expect(answer.outcome, StartOutcome.badTaskName);
      expect(answer.outcome.recognized, isTrue);
      expect(answer.whatToDo, contains("'foo-bar' would do"));
    });

    test('reads the task list over the socket', () async {
      daemon.method('List', (_) => {'tasks': [task('porelo-demo-shell-1')]});
      final tasks = await (await connect()).tasks();
      expect(tasks, hasLength(1));
      expect(tasks.single.name, 'porelo-demo-shell-1');
      expect(tasks.single.helpers, 4);
    });

    test('a refusal arrives as an outcome, not as a failure', () async {
      // HOLDS_WORK is the gate working. A client that treated it as an error would show the one
      // answer that matters most as a generic failure.
      daemon.method('Remove', (_) => {
            'outcome': 'HOLDS_WORK',
            'work': '2 commits on main',
            'rescuedRef': '',
            'removed': false,
            'helpers': 0,
            'surviving': 4,
            'detail': '',
          });
      final stopped = await (await connect()).remove('porelo-demo-shell-1');
      expect(stopped.outcome, Outcome.holdsWork);
      expect(stopped.removed, isFalse);
      expect(stopped.work, '2 commits on main');
    });

    test('a removal says how much it destroyed that exists nowhere else', () async {
      // The agent's own installs go with the container and have nowhere to arrive, unlike the
      // workspace. Nothing else records that any of it existed, so a removal that does not
      // mention it is the last chance to know, gone.
      daemon.method('Remove', (_) => {
            'outcome': 'REMOVED',
            'work': '',
            'rescuedRef': '',
            'removed': true,
            'helpers': 2,
            'surviving': 0,
            'detail': '',
            'discarded': 1284,
          });

      final stopped = await (await connect()).remove('porelo-demo-shell-1');

      expect(stopped.discarded, 1284);
    });

    test("a stop's survivors are a count, and what the machine adds is kept", () async {
      daemon.method('Stop', (_) => {'outcome': 'STOPPED', 'helpers': 2, 'surviving': 1, 'detail': 'the gate helper would not end'});

      final stopped = await (await connect()).stop('porelo-demo-shell-1');

      expect(stopped.surviving, 1);
      expect(stopped.detail, 'the gate helper would not end');
      expect(stopWords('porelo-demo-shell-1', stopped),
          allOf(contains('One helper outlived the stop'), contains('the gate helper would not end.')));
    });

    test("a removal's discarded is a count of paths, never a size, and its detail is said", () async {
      daemon.method('Remove', (_) => {
            'outcome': 'RESCUE_FAILED',
            'work': '',
            'rescuedRef': '',
            'removed': false,
            'helpers': 0,
            'surviving': 0,
            'detail': 'the gate refused the push',
            'discarded': 3,
          });

      final removed = await (await connect()).remove('porelo-demo-shell-1');

      expect(removeWords('porelo-demo-shell-1', removed), contains('the gate refused the push.'));
      expect(removeWords('t', const Removed(outcome: Outcome.removed, work: '', rescuedRef: '', removed: true, discarded: 3)),
          allOf(contains('3 paths only it held went with it'), isNot(contains('bytes'))));
    });

    test('a reply from a daemon too old to count it reads as none', () async {
      // Additive: a backend that has not gained the field yet simply does not send it, and that
      // has to read as zero rather than as a client that cannot talk to it.
      daemon.method('Remove', (_) => {
            'outcome': 'REMOVED',
            'work': '',
            'rescuedRef': '',
            'removed': true,
            'helpers': 0,
            'surviving': 0,
            'detail': '',
          });

      final stopped = await (await connect()).remove('porelo-demo-shell-1');

      expect(stopped.discarded, 0);
      expect(stopped.removed, isTrue);
    });

    test('a named error keeps its name so one refusal can be told from another', () async {
      daemon.fails('Decide', 'org.fuin.porelo.Tasks1.NoClearance', {'task': 'gone'});
      final client = await connect();
      await expectLater(
        client.decide(
            const Prompt(
                task: 'gone',
                key: 'tcp/example.com/443',
                destination: 'example.com',
                protocol: 'tcp',
                port: 443,
                at: '',
                prefix: ''),
            allow: true),
        throwsA(isA<VarlinkException>()
            .having((e) => e.simpleName, 'simpleName', 'NoClearance')),
      );
    });
  });

  group('streaming', () {
    test('a watch delivers every event and then ends', () async {
      daemon.stream('Watch', (_) => Stream.fromIterable([
            {'tasks': [task('a')]},
            {'tasks': [task('a'), task('b')]},
            {'tasks': [task('b')]},
          ]));
      final seen = await (await connect()).watchTasks().toList();
      expect(seen.map((tasks) => tasks.length), [1, 2, 1]);
    });

    test('a stream cut mid-flight is an error, never a quiet end', () async {
      // The requirement is that tunnel loss shows as a disconnection and never as a machine with
      // nothing on it. A stream that completed normally here would render as an empty fleet.
      daemon.stream('Watch', (_) async* {
        yield {'tasks': [task('a')]};
        daemon.severConnections();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        yield {'tasks': [task('b')]};
      });
      final client = await connect();
      await expectLater(client.watchTasks(), emitsThrough(emitsError(anything)));
    });

    test('a stream that ends politely without a final reply is still an error', () async {
      // The subtler half of the same requirement, and the one a passing test can hide. A socket
      // that is destroyed surfaces as a socket error; a connection closed *politely* mid-stream
      // surfaces as the stream just ending, which reads as "nothing is running" rather than as a
      // lost backend. Found by deliberately removing the guard and watching this not fail.
      daemon.hangUpOn.add('Watch');
      await expectLater((await connect()).watchTasks(), emitsError(isA<VarlinkDisconnected>()));
    });

    test('a call whose connection closes before it is answered is an error', () async {
      daemon.hangUpOn.add('List');
      await expectLater((await connect()).tasks(), throwsA(isA<VarlinkDisconnected>()));
    });

    test('a launch streams its output and then its result', () async {
      daemon.stream('Start', (_) => Stream.fromIterable([
            {'line': 'building the image'},
            {'line': 'done'},
            {'container': 'porelo-demo-shell-9', 'exitCode': 0},
          ]));
      final progress = await (await connect()).start(project: 'project.yml').toList();
      expect(progress.take(2).map((p) => p.line), ['building the image', 'done']);
      expect(progress.last.isResult, isTrue);
      expect(progress.last.container, 'porelo-demo-shell-9');
    });
  });

  group('staying compatible with an older backend', () {
    // None of these can be tested against a real daemon: it always has every method it declares,
    // and only ever sends values it knows about. This is why the mock is permanent.

    test('a missing method disables one feature instead of failing the client', () async {
      daemon.method('List', (_) => {'tasks': [task('a')]});
      daemon.remove('Credentials');
      final client = await connect();

      await expectLater(client.credentials(), throwsA(isA<FeatureNotSupported>()));
      // and everything else still works
      expect(await client.tasks(), hasLength(1));
    });

    test('an unrecognized outcome is carried, not thrown on', () async {
      // Adding an enum value is explicitly not a breaking change, so a client that cannot survive
      // one breaks on a routine backend release. A generated Dart enum would throw here.
      daemon.method('Stop', (_) => {
            'outcome': 'QUARANTINED_PENDING_REVIEW',
            'work': '',
            'rescuedRef': '',
            'removed': false,
            'helpers': 0,
            'surviving': 0,
            'detail': '',
          });
      final stopped = await (await connect()).stop('a');
      expect(stopped.outcome.isKnown, isFalse);
      expect(stopped.outcome.name, 'QUARANTINED_PENDING_REVIEW');
      expect(stopped.outcome.label, 'quarantined pending review');
    });

    test('an unrecognized reply field is ignored', () async {
      daemon.method('List', (_) => {
            'tasks': [ {...task('a'), 'somethingAddedLater': 42} ],
            'anotherNewField': true,
          });
      expect(await (await connect()).tasks(), hasLength(1));
    });

    test('the newest understood interface is chosen, not the newest offered', () async {
      daemon.interfaces = const [
        'org.varlink.service',
        'org.fuin.porelo.Tasks1',
        'org.fuin.porelo.Tasks2',
      ];
      // Tasks2 is offered and this build does not know it, so Tasks1 is what gets used - which is
      // what lets an old interface keep working against a new backend.
      expect((await connect()).interfaceName, 'org.fuin.porelo.Tasks1');
    });

    test('a backend serving nothing understood says so plainly', () async {
      daemon.interfaces = const ['org.varlink.service', 'org.fuin.porelo.Tasks9'];
      await expectLater(connect(), throwsA(isA<StateError>()));
    });

    test('the build version is reported but never gates anything', () async {
      daemon.version = '0.9.3';
      expect((await connect()).info.version, '0.9.3');
    });
  });

  group('when there is no backend', () {
    test('an absent socket is a disconnection, not a crash', () async {
      await expectLater(
        PoreloClient.connect(
            const Backend(socketPath: '/nonexistent/porelod.sock', label: 'nowhere')),
        throwsA(isA<VarlinkDisconnected>()),
      );
    });
  });

  group('a prompt and its answer', () {
    Map<String, dynamic> prompt({String? verdict, String prefix = 'egress/deny'}) => {
          'task': 'porelo-demo-shell-1',
          'key': 'tcp/example.com/443',
          'destination': 'example.com',
          'protocol': 'tcp',
          'port': 443,
          'at': '2026-09-07T09:12:00Z',
          'prefix': verdict == null ? prefix : '',
          'verdict': ?verdict,
        };

    test('an open question carries no verdict', () async {
      daemon.pushes('Prompts', (_) => Stream<Map<String, dynamic>>.value(prompt()));
      final client = await connect();

      final asked = await client.prompts().first;

      expect(asked.settled, isFalse);
      expect(asked.expired, isFalse);
      expect(asked.verdict, isNull);
    });

    test('the answer matches the question by task and key alone', () async {
      // The answer arrives as the same destination a second time. Anything keyed on a field that
      // differs between the two would show every blocked destination twice.
      final asked = Prompt.from(prompt());
      final answered = Prompt.from(prompt(verdict: 'allow'));

      expect(answered.identity, asked.identity);
      expect(answered.settled, isTrue);
      expect(answered.prefix, isEmpty);
    });

    test('a prompt that ran out says so, rather than simply never arriving again', () async {
      final expired = Prompt.from(prompt(verdict: 'timeout'));

      expect(expired.expired, isTrue);
      expect(expired.settled, isTrue);
    });

    test('a verdict this build has never heard of is carried, not thrown on', () async {
      // verdict is a plain string in the contract, so it may gain values the way Outcome does.
      final odd = Prompt.from(prompt(verdict: 'deferred'));

      expect(odd.verdict, 'deferred');
      expect(odd.settled, isTrue);
      expect(odd.expired, isFalse);
    });

    test('an undeclared field on the event is ignored', () async {
      // These events carry more than the IDL declares - shown, project, source among them. They
      // are not contract and must not be read.
      final extra = Prompt.from({...prompt(), 'project': 'checkout', 'source': 'proxy'});

      expect(extra.destination, 'example.com');
      expect(extra.shown, 'example.com:443');
    });
  });

  group('which logs a task has', () {
    test('an empty list is an answer, not a failure', () async {
      // A task whose state directory is gone — which is what stopping with purge does — has no
      // logs, and neither does a name that is not a Porelo task. Neither raises an error.
      daemon.method('Logs', (_) => {'logs': <Map<String, dynamic>>[]});

      expect(await (await connect()).logsOf('porelo-demo-shell-1'), isEmpty);
    });

    test('a reply shaped differently from the promise still reads as none', () async {
      daemon.method('Logs', (_) => <String, dynamic>{});

      expect(await (await connect()).logsOf('porelo-demo-shell-1'), isEmpty);
    });
  });

  group('an endless stream', () {
    test('delivers each event as it happens, not one event late', () async {
      // Watch and Prompts are never finite. A backend that held each event until the next one
      // arrived would make every change reach the interface one change late, which is
      // indistinguishable from an interface that ignores its own events.
      final changes = StreamController<Map<String, dynamic>>();
      daemon.pushes('Watch', (_) => changes.stream);
      final client = await connect();

      final seen = <int>[];
      final first = Completer<void>();
      final second = Completer<void>();
      final watching = client.watchTasks().listen((tasks) {
        seen.add(tasks.length);
        if (seen.length == 1) first.complete();
        if (seen.length == 2) second.complete();
      });

      changes.add(<String, dynamic>{'tasks': <Map<String, dynamic>>[task('a')]});
      await first.future;
      changes.add(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[task('a'), task('b')],
      });
      await second.future;

      expect(seen, <int>[1, 2]);
      await watching.cancel();
      await changes.close();
    });
  });

  group('leaving a stream', () {
    test('canceling returns rather than waiting for a daemon that will not close', () async {
      // Socket.close() completes when the *peer* closes, and a daemon holding a stream open never
      // does. Awaiting it hung for ever, which reads as an interface that froze on the way out.
      final changes = StreamController<Map<String, dynamic>>();
      daemon.pushes('Watch', (_) => changes.stream);
      final client = await connect();
      final seen = Completer<void>();
      final watching = client.watchTasks().listen((_) {
        if (!seen.isCompleted) seen.complete();
      });
      changes.add(<String, dynamic>{'tasks': <Map<String, dynamic>>[task('a')]});
      await seen.future;

      await expectLater(
        watching.cancel().timeout(const Duration(seconds: 5)),
        completes,
      );
      await changes.close();
    });
  });

  group('a backend that accepts a call and never answers it', () {
    test('gives up rather than waiting forever', () async {
      // The state that cost an afternoon: the socket is healthy, the connection is accepted, and
      // nothing ever comes back. Without a deadline the interface sits saying it is connecting,
      // with no way out and nothing to report.
      daemon.neverAnswers('List');
      final connection = await VarlinkConnection.open(daemon.socketPath);

      await expectLater(
        connection.call('org.fuin.porelo.Tasks1.List', const {},
            const Duration(milliseconds: 100)),
        throwsA(isA<VarlinkDisconnected>()),
      );
    });

    test('a stream is left alone, because having nothing to say is not a fault', () async {
      // Prompts may legitimately be silent for hours. A deadline on a stream would report a
      // working backend as a broken one, which is why the deadline is on single calls only.
      daemon.neverAnswers('List');
      daemon.neverAnswers('Prompts');
      final client = await PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'),
          answerWithin: const Duration(milliseconds: 100));
      // The same client gives up on a single call, so the silence below outlasts a real deadline.
      await expectLater(client.tasks(), throwsA(isA<VarlinkDisconnected>()));

      final happened = <Object>[];
      final listening = client.prompts().listen(happened.add, onError: happened.add);
      await Future<void>.delayed(const Duration(seconds: 1));
      await listening.cancel();

      expect(happened, isEmpty, reason: 'a silent stream was cut or failed');
    });
  });

  group('the contract', () {
    test('is read from the running backend rather than a copy', () async {
      daemon.description = 'interface org.fuin.porelo.Tasks1\nmethod List() -> (tasks: []Task)';
      expect(await (await connect()).contract(), contains('method List()'));
    });
  });
}

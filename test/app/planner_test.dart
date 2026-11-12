// Linux only: porelo-planner is built for Linux; these read its runtime directory, POSIX modes and paths.
// Windows, where nothing is started, is tested in planner_windows_test.dart.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';
import '../support/planner_process.dart';

/// A stand-in planner on the loopback address that records every call and answers an empty board.
class _Planner {
  _Planner._(this.server) {
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      calls.add((request.method, request.uri.path, request.headers.value(HttpHeaders.authorizationHeader), body));
      final response = request.response;
      if (request.method == 'PUT') {
        response.statusCode = HttpStatus.noContent;
      } else {
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode(
            request.uri.pathSegments.last == 'workflow'
                ? {'revision': 'r1', 'states': <Object>[], 'phases': <Object>[]}
                : {'revision': 'r1', 'stories': <Object>[]},
          ),
        );
      }
      await response.close();
    });
  }

  static Future<_Planner> start() async => _Planner._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer server;
  final calls = <(String, String, String?, String)>[];

  /// Writes the address file as the planner does: owner-only, in an owner-only directory, in one step.
  Future<void> announce(String runtime, {String token = 'token-of-the-test', int mode = 384, Object? log}) async {
    final directory = await Directory('$runtime/porelo-planner').create(recursive: true);
    await Process.run('chmod', ['700', directory.path]);
    // Written beside it and renamed over, so a window looking meanwhile never sees it before its mode is set.
    final written = File('${directory.path}/planner.json.new');
    await written.writeAsString(jsonEncode({'port': server.port, 'token': token, 'log': ?log}));
    await Process.run('chmod', [mode.toRadixString(8), written.path]);
    await written.rename('${directory.path}/planner.json');
  }
}

void main() {
  late Directory runtime;
  late Directory bin;
  final planners = <_Planner>[];
  final clients = <LocalPlanner>[];

  setUp(() async {
    runtime = await Directory.systemTemp.createTemp('planner-runtime-');
    // Closed to others, as /run/user is: the planner's package refuses a runtime directory others may write.
    await Process.run('chmod', ['700', runtime.path]);
    bin = await Directory.systemTemp.createTemp('planner-bin-');
  });

  tearDown(() async {
    for (final client in clients) {
      client.dispose();
    }
    clients.clear();
    for (final planner in planners) {
      await planner.server.close(force: true);
    }
    planners.clear();
    await runtime.delete(recursive: true);
    await bin.delete(recursive: true);
  });

  Future<_Planner> planner() async => (await _Planner.start())..let(planners.add);

  /// A program the planner could be, which nothing ever runs: the start is the test's.
  Future<String> program() async {
    final file = File('${bin.path}/porelo-planner');
    await file.writeAsString('#!/bin/sh\nexit 1\n');
    await Process.run('chmod', ['700', file.path]);
    return file.path;
  }

  LocalPlanner client({
    List<String>? candidates,
    StartPlanner? start,
    Duration? wait,
    String? Function()? runtimeDirectory,
    OpenPlanner? open,
    Duration? follow,
  }) => LocalPlanner(
    projects: () => ['demo'],
    repositories: (project) => PlannerProject('https://example.org/$project.git'),
    runtimeDirectory: runtimeDirectory == null ? runtime.path : runtimeDirectory(),
    candidates: candidates ?? const [],
    start: start ?? (_, _) async => fail('no planner may be started'),
    open: open,
    wait: wait ?? const Duration(seconds: 5),
    poll: const Duration(milliseconds: 20),
    follow: follow ?? const Duration(seconds: 2),
  )..let(clients.add);

  // Harm: the window reads a board from somewhere other than the planner that runs, or before the planner knows where
  // the project's planning is kept.
  test('a running planner is found by its address file and told the repository before the board is read', () async {
    final running = await planner();
    await running.announce(runtime.path);
    final local = client();

    await local.reach();

    expect(local.notReached, isNull);
    final provider = local.providers.single;
    expect(provider.connected, isTrue);
    expect(provider.projects, ['demo']);
    await provider.source.stories('demo');
    expect(running.calls.first, (
      'PUT',
      '/projects/demo',
      'Bearer token-of-the-test',
      jsonEncode({'repository': 'https://example.org/demo.git'}),
    ));
    expect(running.calls.skip(1).map((call) => (call.$1, call.$2)), [
      ('GET', '/projects/demo/workflow'),
      ('GET', '/projects/demo/stories'),
    ]);
  });

  // Harm: one window starts several planners, or starts one for the person's own runtime directory in place of its own.
  test('where none runs, one planner is started for the window and found once it writes its address', () async {
    final started = await planner();
    final path = await program();
    final starts = <(String, Map<String, String>)>[];
    final local = client(
      candidates: [path],
      start: (executable, environment) async {
        starts.add((executable, environment));
        unawaited(Future<void>.delayed(const Duration(milliseconds: 100), () => started.announce(runtime.path)));
        return PlannerProcess();
      },
    );

    await Future.wait([local.reach(), local.reach()]);
    await local.reach();

    expect(starts.map((start) => start.$1), [path]);
    expect(starts.single.$2, {'XDG_RUNTIME_DIR': runtime.path});
    expect(local.notReached, isNull);
    expect(local.providers.single.connected, isTrue);
  });

  // Harm: a planner that never answers leaves the place waiting forever, or has the window start planner after planner.
  test(
    'a started planner that writes no address is waited for a bounded time, said, and never started again',
    () async {
      final path = await program();
      var starts = 0;
      final local = client(
        candidates: [path],
        start: (_, _) async {
          starts++;
          return PlannerProcess();
        },
        wait: const Duration(milliseconds: 200),
      );

      await local.reach().timeout(const Duration(seconds: 5));
      await local.reach();

      expect(starts, 1);
      expect(local.notReached, contains('did not say where it answers'));
      expect(local.providers, isEmpty);
    },
  );

  // Harm: a window without a planner shows an empty board as if planning had nothing, or runs a file it cannot run.
  test('where no planner is installed, nothing is started and the place says so in words', () async {
    final notRunnable = File('${bin.path}/porelo-planner');
    await notRunnable.writeAsString('#!/bin/sh\n');
    await Process.run('chmod', ['600', notRunnable.path]);
    final local = client(candidates: ['${bin.path}/missing', notRunnable.path]);

    await local.reach();

    expect(local.notReached, plannerNotInstalled);
    expect(local.providers, isEmpty);
  });

  // Harm: the window trusts a token others could read, or starts a second planner beside one that runs and then
  // loses the refusal's words to a timeout.
  test('an address file other accounts may read is refused in words, and no planner is started', () async {
    final running = await planner();
    await running.announce(runtime.path, mode: 420);
    var starts = 0;
    final local = client(
      candidates: [await program()],
      start: (_, _) async {
        starts++;
        return PlannerProcess();
      },
    );

    await local.reach();

    expect(starts, 0, reason: 'a refused address file is no planner that is not running');
    expect(local.notReached, contains('other accounts'));
    expect(local.providers, isEmpty);
    expect(running.calls, isEmpty);
  });

  // Harm: an address file the planner did not write has the window start a second planner, and its words are lost.
  test('an address file that is not the planner\'s is refused in words, and no planner is started', () async {
    final directory = await Directory('${runtime.path}/porelo-planner').create();
    await Process.run('chmod', ['700', directory.path]);
    final file = File('${directory.path}/planner.json');
    await file.writeAsString('not the planner\'s address');
    await Process.run('chmod', ['600', file.path]);
    var starts = 0;
    final local = client(
      candidates: [await program()],
      start: (_, _) async {
        starts++;
        return PlannerProcess();
      },
    );

    await local.reach();

    expect(starts, 0);
    expect(local.notReached, contains('not JSON'));
  });

  // Harm: a planner is started into a runtime directory relative to wherever the window was started, which the read
  // refuses, so the started planner is never found and the refusal is lost to a timeout.
  test('a relative runtime directory is refused in words, and no planner is started', () async {
    var starts = 0;
    final local = client(
      runtimeDirectory: () => 'relative/run',
      candidates: [await program()],
      start: (_, _) async {
        starts++;
        return PlannerProcess();
      },
    );

    await local.reach();

    expect(starts, 0);
    expect(local.notReached, contains('relative/run'));
  });

  // Harm: a blank runtime directory has the planner started with an empty XDG_RUNTIME_DIR while the window reads the
  // account's own, so each looks in a different place.
  test('a blank runtime directory is the account\'s own, for the start and the read alike', () async {
    final reads = <String?>[];
    final starts = <Map<String, String>>[];
    final local = client(
      runtimeDirectory: () => '  ',
      candidates: [await program()],
      start: (_, environment) async {
        starts.add(environment);
        return PlannerProcess();
      },
      open: (_, {runtimeDirectory}) async {
        reads.add(runtimeDirectory);
        throw const PlanningRefusal('NoAddress', {}, 'no planner runs');
      },
      wait: const Duration(milliseconds: 60),
    );

    await local.reach();

    expect(reads, everyElement(isNull));
    expect(reads, isNotEmpty);
    expect(starts, [<String, String>{}]);
  });

  // Harm: an unexpected failure while reading the address escapes unseen and leaves the place looking forever.
  test('a failure other than a refusal while looking is said in words, and no planner is started', () async {
    var starts = 0;
    final local = client(
      candidates: [await program()],
      start: (_, _) async {
        starts++;
        return PlannerProcess();
      },
      open: (_, {runtimeDirectory}) async => throw StateError('the address could not be taken'),
    );

    await local.reach();

    expect(starts, 0);
    expect(local.notReached, contains('the address could not be taken'));
  });

  // Harm: a planner installed or answering after the first try is never reached until the window is restarted.
  test('a failed reach is tried again, and finds a planner installed since', () async {
    final started = await planner();
    final file = File('${bin.path}/porelo-planner');
    await file.writeAsString('#!/bin/sh\nexit 1\n');
    await Process.run('chmod', ['600', file.path]);
    final starts = <String>[];
    final local = client(
      candidates: [file.path],
      start: (executable, _) async {
        starts.add(executable);
        await started.announce(runtime.path);
        return PlannerProcess();
      },
    );
    await local.reach();
    expect(local.notReached, plannerNotInstalled);

    await Process.run('chmod', ['700', file.path]);
    await local.reach();

    expect(starts, [file.path]);
    expect(local.notReached, isNull);
  });

  // Harm: a planner that answers late is never read, or a second planner is started beside the first.
  test('a started planner that answers late is found when tried again, and is never started twice', () async {
    final slow = await planner();
    var starts = 0;
    final local = client(
      candidates: [await program()],
      start: (_, _) async {
        starts++;
        return PlannerProcess();
      },
      wait: const Duration(milliseconds: 100),
    );
    await local.reach();
    expect(local.notReached, contains('did not say where it answers'));

    await slow.announce(runtime.path);
    await local.reach();

    expect(starts, 1);
    expect(local.notReached, isNull);
  });

  // Harm: one candidate the account cannot run hides another it can, so planning is never reached.
  test('a candidate that cannot be started gives way to the next', () async {
    final started = await planner();
    final first = await program();
    final second = File('${bin.path}/porelo-planner-second');
    await second.writeAsString('#!/bin/sh\nexit 1\n');
    await Process.run('chmod', ['700', second.path]);
    final starts = <String>[];
    final local = client(
      candidates: [first, second.path],
      start: (executable, _) async {
        starts.add(executable);
        if (executable == first) throw ProcessException(executable, const [], 'Permission denied', 13);
        await started.announce(runtime.path);
        return PlannerProcess();
      },
    );

    await local.reach();

    expect(starts, [first, second.path]);
    expect(local.notReached, isNull);
  });

  // Harm: a relative entry on the path runs a program from whatever directory the window was started in.
  test('the planner is looked for where its package puts it, then on the path, never by a relative path', () {
    expect(plannerCandidates({'PATH': '/opt/a:bin::/usr/bin: /tmp/bin:/usr/bin/../../tmp/bin:/opt/..'}), [
      plannerInstalled,
      '/opt/a/porelo-planner',
      '/usr/bin/porelo-planner',
    ]);
  });

  Project project(String name, List<Map<String, dynamic>> repositories) =>
      Project.from({'name': name, 'repositories': repositories});
  Project own(String name, String upstream) => project(name, [
    {'name': name, 'own': true, 'upstream': upstream},
  ]);

  // Harm: the planner is told another repository than the project's own, or a project of another name.
  test('a project is told with its own repository\'s upstream, and refused in words where no machine names one', () {
    final known = [
      own('other', 'https://example.org/other.git'),
      project('demo', [
        {'name': 'demo-code', 'own': false, 'upstream': 'https://example.org/demo-code.git'},
        {'name': 'demo', 'own': true, 'upstream': ''},
      ]),
      project('demo', [
        {'name': 'demo-code', 'own': false, 'upstream': 'https://example.org/demo-code.git'},
        {'name': 'demo', 'own': true, 'upstream': 'https://example.org/demo.git'},
      ]),
    ];

    expect(plannerProjectIn(known, 'demo'), const PlannerProject('https://example.org/demo.git'));
    expect(
      () => plannerProjectIn(known.take(2), 'demo'),
      throwsA(
        isA<PlanningRefusal>()
            .having((refusal) => refusal.name, 'name', 'NoRepository')
            .having(planningFailureWords, 'words on the board', contains('No watched machine names where demo')),
      ),
    );
  });

  // Harm: a local path the planner refuses is told in place of a clone URL another machine names, so the board fails.
  test('a remote clone URL is preferred to a local path, which is told only where no machine names a remote one', () {
    expect(
      plannerProjectIn([own('demo', '/home/user/git/demo'), own('demo', 'https://example.org/demo.git')], 'demo'),
      const PlannerProject('https://example.org/demo.git'),
    );
    expect(
      plannerProjectIn([own('demo', 'file:///srv/git/demo'), own('demo', 'git@example.org:org/demo.git')], 'demo'),
      const PlannerProject('git@example.org:org/demo.git'),
    );
    expect(
      plannerProjectIn([own('demo', '/srv/git/demo'), own('demo', '/home/user/git/demo')], 'demo'),
      const PlannerProject('/srv/git/demo'),
    );
  });

  group('the watched machines', () {
    late Machines machines;
    late Map<String, FakeBackend> backends;
    const other = Machine(name: 'other', socketPath: '/tmp/other-planner.sock');

    setUp(() async {
      backends = {};
      machines = Machines(
        Settings(MemorySettingsStore()),
        reach: (machine) => backends[machine.name] = FakeBackend(const <Task>[])..theProjectsItHas = [],
        tunnels: FakeTunnels(),
      );
      await machines.add(other);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() => machines.dispose());

    Future<void> listing(Machine machine, List<Project> projects) async {
      backends[machine.name]!.theProjectsItHas = projects;
      await machines.of(machine).refresh();
    }

    Machine shown() => machines.all.firstWhere((machine) => machine.name != other.name);

    // Harm: the board is asked of a project the window never lists, of the default project, or of one project twice.
    test('plan every project they list once, without the default project', () async {
      await listing(shown(), [own('demo', 'https://example.org/demo.git'), own(defaultProject, '')]);
      await listing(other, [
        own('demo', 'https://example.org/demo.git'),
        own('tools', 'https://example.org/tools.git'),
      ]);

      expect(plannedProjects(machines)..sort(), ['demo', 'tools']);
    });

    // Harm: the planner is told another machine's repository where the shown machine names its own.
    test('name a project\'s repository from the machine shown first, then from another', () async {
      await listing(shown(), [own('demo', 'https://example.org/shown/demo.git')]);
      await listing(other, [
        own('demo', 'https://example.org/other/demo.git'),
        own('tools', 'https://example.org/tools.git'),
      ]);

      expect(plannerProjectOf(machines, 'demo'), const PlannerProject('https://example.org/shown/demo.git'));
      expect(plannerProjectOf(machines, 'tools'), const PlannerProject('https://example.org/tools.git'));
      machines.select(other);
      expect(plannerProjectOf(machines, 'demo'), const PlannerProject('https://example.org/other/demo.git'));
    });

    // Harm: the shown machine's local path is told in place of the clone URL another machine names.
    test('take another machine\'s clone URL over the shown machine\'s local path', () async {
      await listing(shown(), [own('demo', '/home/user/git/demo')]);
      await listing(other, [own('demo', 'https://example.org/demo.git')]);

      expect(plannerProjectOf(machines, 'demo'), const PlannerProject('https://example.org/demo.git'));
    });

    // Harm: the planner's board lists projects the window does not, tells it other repositories, or opens another
    // project than the one the person chose.
    test('are what the planner of the window is told, and the chosen project is the shown machine\'s', () async {
      await listing(shown(), [own('demo', 'https://example.org/demo.git'), own(defaultProject, '')]);
      PlannerProjects? told;
      final local = LocalPlanner.of(
        machines,
        candidates: const [],
        open: (projects, {runtimeDirectory}) async {
          told = projects;
          return HttpPlanningSource(Uri.parse('http://127.0.0.1:9'), 'token', projects);
        },
      )..let(clients.add);
      machines.fleet.selectProject('demo');

      await local.reach();

      expect(local.providers.single.projects, ['demo']);
      expect(told!('demo'), const PlannerProject('https://example.org/demo.git'));
      expect(local.chosenProject, 'demo');
    });
  });

  /// Waits until [done] holds, failing after a few seconds.
  Future<void> until(bool Function() done) async {
    for (var tries = 0; !done(); tries++) {
      if (tries > 200) fail('it did not happen');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  // Harm: after the planner restarts on another port, planning stays out of reach until the window is restarted.
  test('after the planner restarts on another port, the window follows it there', () async {
    final first = await planner();
    await first.announce(runtime.path);
    final local = client(follow: const Duration(milliseconds: 20));
    await local.reach();
    final before = local.providers.single.source;
    await first.server.close(force: true);
    final second = await planner();
    await second.announce(runtime.path, token: 'token-after-the-restart');

    await until(() => !identical(local.providers.single.source, before));
    await local.providers.single.source.stories('demo');

    expect(local.notReached, isNull);
    expect(second.calls.map((call) => call.$3), everyElement('Bearer token-after-the-restart'));
    expect(second.calls.map((call) => call.$2), contains('/projects/demo/stories'));
  });

  // Harm: a guessed path is opened as the planner's log, or the one the planner names is not the one opened.
  test('the planner\'s log is the path its address file names, and none where it names none', () async {
    final running = await planner();
    await running.announce(runtime.path);
    final local = client(follow: const Duration(milliseconds: 20));
    await local.reach();
    expect(local.log, isNull, reason: 'the planner names no log yet');

    await running.announce(runtime.path, log: '${runtime.path}/planner.log');
    await until(() => local.log != null);
    expect(local.log, '${runtime.path}/planner.log');
  });

  // Harm: a planner that ended for good leaves planning out of reach until the window is restarted.
  test('where the planner found is gone, one is started once and reached', () async {
    final first = await planner();
    await first.announce(runtime.path);
    final second = await planner();
    var starts = 0;
    final local = client(
      candidates: [await program()],
      follow: const Duration(milliseconds: 20),
      start: (_, _) async {
        starts++;
        await second.announce(runtime.path, token: 'token-of-the-new-one');
        return PlannerProcess();
      },
    );
    await local.reach();
    final before = local.providers.single.source;
    await first.server.close(force: true);
    await File('${runtime.path}/porelo-planner/planner.json').delete();

    await until(() => local.providers.isNotEmpty && !identical(local.providers.single.source, before));
    await local.providers.single.source.stories('demo');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(starts, 1, reason: 'the planner started answers, so no second one is started');
    expect(second.calls.map((call) => call.$3), everyElement('Bearer token-of-the-new-one'));
  });
}

extension<T> on T {
  void let(void Function(T) use) => use(this);
}

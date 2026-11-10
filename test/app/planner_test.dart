import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/client/models.dart';
import 'package:porelo_planning/porelo_planning.dart';

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

  /// Writes the address file as the planner does: owner-only, in an owner-only directory.
  Future<void> announce(String runtime, {String token = 'token-of-the-test', int mode = 384}) async {
    final directory = await Directory('$runtime/porelo-planner').create(recursive: true);
    await Process.run('chmod', ['700', directory.path]);
    final file = File('${directory.path}/planner.json');
    await file.writeAsString(jsonEncode({'port': server.port, 'token': token}));
    await Process.run('chmod', [mode.toRadixString(8), file.path]);
  }
}

void main() {
  late Directory runtime;
  late Directory bin;
  final planners = <_Planner>[];
  final clients = <LocalPlanner>[];

  setUp(() async {
    runtime = await Directory.systemTemp.createTemp('planner-runtime-');
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

  LocalPlanner client({List<String>? candidates, StartPlanner? start, Duration? wait}) => LocalPlanner(
    projects: () => ['demo'],
    repositories: (project) => PlannerProject('https://example.org/$project.git'),
    runtimeDirectory: runtime.path,
    candidates: candidates ?? const [],
    start: start ?? (_, _) async => fail('no planner may be started'),
    wait: wait ?? const Duration(seconds: 5),
    poll: const Duration(milliseconds: 20),
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
        start: (_, _) async => starts++,
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

  // Harm: the window trusts a token others could read, or starts a second planner beside one that runs.
  test('an address file other accounts may read is refused in words, and no planner is started', () async {
    final running = await planner();
    await running.announce(runtime.path, mode: 420);
    final local = client(candidates: [await program()]);

    await local.reach();

    expect(local.notReached, contains('other accounts'));
    expect(local.providers, isEmpty);
    expect(running.calls, isEmpty);
  });

  // Harm: a relative entry on the path runs a program from whatever directory the window was started in.
  test('the planner is looked for where its package puts it, then on the path, never by a relative path', () {
    expect(plannerCandidates({'PATH': '/opt/a:bin::/usr/bin'}), [
      plannerInstalled,
      '/opt/a/porelo-planner',
      '/usr/bin/porelo-planner',
    ]);
  });

  // Harm: the planner is told another repository than the project's own, or a project of another name.
  test('a project is told with its own repository\'s upstream, and refused where no machine names one', () {
    Project project(String name, List<Map<String, dynamic>> repositories) =>
        Project.from({'name': name, 'repositories': repositories});
    final known = [
      project('other', [
        {'name': 'other', 'own': true, 'upstream': 'https://example.org/other.git'},
      ]),
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
      throwsA(isA<PlanningRefusal>().having((refusal) => refusal.name, 'name', 'NoRepository')),
    );
  });
}

extension<T> on T {
  void let(void Function(T) use) => use(this);
}

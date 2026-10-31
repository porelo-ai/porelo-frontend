import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/project_copies.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

const _url = 'git@example.org:team/demo.git';

void main() {
  late Directory root;
  late List<List<String>> calls;
  late List<Map<String, String>> environments;
  late String origin;
  late ProjectCopies copies;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('project-copies-');
    calls = [];
    environments = [];
    origin = _url;
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      calls.add([program, ...arguments]);
      environments.add(environment);
      if (arguments.first == 'clone') await Directory(arguments.last).create(recursive: true);
      return (code: 0, out: arguments.first == 'config' ? '$origin\n' : '', err: '');
    }

    copies = ProjectCopies(root: path.join(root.path, 'copies'), run: run);
  });

  tearDown(() => root.delete(recursive: true));

  // Harm: a copy fetched from another repository than the follow names would be verified as this project, and the
  // person's or the system's Git configuration could choose what is fetched or run.
  test('a copy is cloned bare once, then fetched only from the address it was made of', () async {
    final copy = copies.project('demo');
    await copies.fetch(copy, _url);
    await copies.fetch(copy, _url);
    expect(calls, [
      ['git', 'clone', '--bare', '--no-tags', '--', _url, copy],
      ['git', 'config', '--get', 'remote.origin.url'],
      ['git', 'fetch', '--no-tags', '--prune', 'origin', '+refs/heads/*:refs/heads/*'],
    ]);
    expect(environments.map((each) => each['GIT_CONFIG_GLOBAL']).toSet(), {'/dev/null'});
    expect(environments.map((each) => each['GIT_CONFIG_NOSYSTEM']).toSet(), {'1'});
    origin = 'git@example.org:other/demo.git';
    await expectLater(copies.fetch(copy, _url), throwsA(isA<RegistryRefusal>()));
    expect(calls.last.take(2), ['git', 'config']);
  });
}

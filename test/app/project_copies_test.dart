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
      return (
        code: 0,
        out: switch (arguments.first) {
          'config' => '$origin\n',
          'ls-remote' => 'ref: refs/heads/trunk\tHEAD\n${'a' * 40}\tHEAD\n',
          _ => '',
        },
        err: '',
      );
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
      ['git', 'config', '--get-all', 'remote.origin.url'],
      ['git', 'fetch', '--no-tags', '--prune', 'origin', '+refs/heads/*:refs/heads/*'],
      ['git', 'ls-remote', '--symref', 'origin', 'HEAD'],
      ['git', 'symbolic-ref', 'HEAD', 'refs/heads/trunk'],
    ]);
    expect(environments.map((each) => each['GIT_CONFIG_GLOBAL']).toSet(), {'/dev/null'});
    expect(environments.map((each) => each['GIT_CONFIG_NOSYSTEM']).toSet(), {'1'});
    origin = 'git@example.org:other/demo.git';
    await expectLater(copies.fetch(copy, _url), throwsA(isA<RegistryRefusal>()));
    expect(calls.last.take(2), ['git', 'config']);
    // Git fetches from the first of several addresses, while `--get` would show only the last.
    origin = 'git@example.org:other/demo.git\n$_url';
    await expectLater(copies.fetch(copy, _url), throwsA(isA<RegistryRefusal>()));
    expect(calls.last.take(2), ['git', 'config']);
  });

  // Harm: other accounts on this computer list which projects this person administers, from the copies' folder.
  test('the folder of all copies is owner-only, even when it was there before', tags: ['linux'], () async {
    final all = Directory(path.join(root.path, 'copies'))..createSync();
    await Process.run('chmod', ['0755', all.path]);
    await copies.fetch(copies.project('demo'), _url);
    expect(all.statSync().mode & 0x1ff, 0x1c0);
  });
}

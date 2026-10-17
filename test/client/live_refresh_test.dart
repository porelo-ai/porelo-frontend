import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/project_check.dart';

/// Checks a followed project now on a real machine, as "Check it now" does.
///
/// Runs only when `PORELO_SOCKET` names a daemon's socket and `PORELO_REFRESH_PROJECT` a project this
/// account follows; with `PORELO_REFRESH_TASK` also a task of a checkout-sourced repository, which the person
/// moves on in its checkout between runs.
void main() {
  final socket = Platform.environment['PORELO_SOCKET'] ?? '';
  final project = Platform.environment['PORELO_REFRESH_PROJECT'] ?? '';
  final task = Platform.environment['PORELO_REFRESH_TASK'] ?? '';
  final skip = socket.isEmpty || project.isEmpty ? 'needs PORELO_SOCKET and PORELO_REFRESH_PROJECT, a followed project' : null;

  late PoreloBackend backend;
  setUp(() async {
    backend = PoreloBackend(Backend(socketPath: socket, label: 'live'));
    await backend.open();
  });

  test('a followed project is fetched now, and its record says when', () async {
    final before = DateTime.now().toUtc().subtract(const Duration(seconds: 2));

    final records = await backend.refreshProjects(project: project);

    final mine = records.singleWhere((each) => each.name == project);
    expect(mine.outcome, isNotEmpty);
    expect(DateTime.parse(mine.at).isAfter(before), isTrue, reason: 'fetched at ${mine.at}, asked after $before');
  }, skip: skip);

  test('a project this account does not follow is refused by name', () async {
    await expectLater(
      backend.refreshProjects(project: 'no-such-project-here'),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'error', 'NoSuchProject')),
    );
  }, skip: skip);

  test('"Check it now" says the follow and each repository, as the page shows them', () async {
    final check = ProjectCheck();
    final listed = (await backend.projects()).singleWhere((each) => each.name == project);

    await check.checkNow(backend, project, <String>[for (final each in listed.repositoryStates) each.name]);

    final said = check.saidAbout(project);
    // ignore: avoid_print
    print(said.join('\n'));
    expect(said, isNotEmpty);
    expect(said.first, isNot(startsWith('Refused')));
    expect(said.first, isNot(startsWith('Lost contact')));
    check.dispose();
  }, skip: skip);

  test('a task is brought up to its source, with what moved and whether its agent heard', () async {
    final refreshed = await backend.refreshTask(task);

    // ignore: avoid_print
    print(refreshed.wordsFor(task));
    expect(refreshed.outcome, anyOf('MOVED', 'UNCHANGED'));
    if (refreshed.outcome == 'MOVED') expect(refreshed.moved, isNotEmpty);
  }, skip: socket.isEmpty || task.isEmpty ? 'needs PORELO_SOCKET and PORELO_REFRESH_TASK, a task started in a checkout' : null);

  test('a repository started in a checkout says so, with the checkout as where its work goes', () async {
    final repositories = await backend.defaultRepositories();

    // ignore: avoid_print
    print([for (final each in repositories) '${each.name}: ${each.comesFromAndGoes}'].join('\n'));
    expect(repositories.where((each) => each.source == 'CHECKOUT' && each.upstream == each.checkout), isNotEmpty);
  }, skip: socket.isEmpty || task.isEmpty ? 'needs PORELO_SOCKET and PORELO_REFRESH_TASK, a task started in a checkout' : null);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/bring_project_file.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  String project({String upstream = 'https://example.org/team/api.git'}) =>
      '''
name: demo
access: {repository: git@example.org:team/access.git}
credentials: {search: brave-search}
repositories:
  api:
    upstream: $upstream
    credentials: {api-token: api-destination}
''';

  // Harm: reading credential destinations as vault entry names feeds unrelated credentials or fails the stop.
  test('the signed project supplies vault entry names rather than their destinations', () {
    final file = BringProjectFile.read(project());
    expect(file.keys, ['search', 'api-token']);
    expect(file.access, 'git@example.org:team/access.git');
    expect(file.repositories, ['https://example.org/team/api.git']);
  });

  // Harm: a credential-bearing URL reaches a process or upload before its field is refused.
  test('the central upstream is validated before the parsed project can be used', () {
    expect(
      () => BringProjectFile.read(project(upstream: 'https://person:fixture@example.org/api.git')),
      throwsA(
        isA<HostFilesRefused>()
            .having((e) => e.message, 'field', contains('forge.repositories[0].url'))
            .having((e) => e.message, 'no value', isNot(contains('fixture'))),
      ),
    );
  });

  // Harm: the followed URL can itself leak a password or token through Git's argument list.
  test('credential-bearing followed sources are refused without repeating their values', () {
    for (final source in [
      'https://person:fixture@example.org/project.git',
      'https://example.org/project.git?fixture',
      'https://fixture@example.org/project.git',
    ]) {
      expect(
        () => BringProjectFile.checkSource(source),
        throwsA(isA<WorkspaceRefused>().having((e) => e.words, 'safe refusal', isNot(contains('fixture')))),
      );
    }
    for (final source in [
      'https://example.org/project.git',
      'git@example.org:team/project.git',
      '/home/person/project.bundle',
      'file:///home/person/project.bundle',
    ]) {
      expect(() => BringProjectFile.checkSource(source), returnsNormally);
    }
  });

  // Harm: an absent migration list silently omits repositories from the bring.
  for (final value in ['{}', '[]', 'null']) {
    test('an empty or malformed repository set is refused ($value)', () {
      expect(
        () => BringProjectFile.read('access: {repository: https://example.org/access.git}\nrepositories: $value\n'),
        throwsA(isA<WorkspaceRefused>()),
      );
    });
  }
}

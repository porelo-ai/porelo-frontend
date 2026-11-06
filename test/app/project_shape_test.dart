import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_binding.dart';
import 'package:porelo_frontend/src/app/run_here.dart' show WorkspaceRefused;

void main() {
  test('a project.yml names its project', () {
    expect(ProjectShape.of('project: {name: billing}').name, 'billing');
  });

  // Harm: a repository naming itself so reads the gate of the project every machine has as its own.
  test('a project.yml may not name the Default project', () {
    for (final name in ['default', 'Default']) {
      expect(() => ProjectShape.of('project: {name: $name}'), throwsA(isA<WorkspaceRefused>()));
    }
  });

  // Harm: a project file renamed to central: reads as having no repositories, and its waiting changes go unseen.
  test("a repository's address is its central:, or upstream: in a file not yet renamed", () {
    final shape = ProjectShape.of(
      'project: {name: billing}\n'
      'repositories:\n'
      '  api: {central: git@github.com:acme/api.git}\n'
      '  web: {upstream: git@github.com:acme/web.git}\n',
    );
    expect(shape.repositories, {'api': 'git@github.com:acme/api.git', 'web': 'git@github.com:acme/web.git'});
  });
}

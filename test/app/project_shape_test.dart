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
}

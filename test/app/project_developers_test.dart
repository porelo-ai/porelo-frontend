import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';

class _People implements ProjectPeople {
  final person = AccessDeveloper(login: 'worker', role: 'developer', fingerprint: 'SHA256:${'A' * 43}');
  final changes = <String>[];
  bool fail = false;
  @override
  Future<AccessDevelopers> read(String project) async {
    if (fail) throw const FormatException('refused');
    return AccessDevelopers([person]);
  }

  @override
  Future<void> change(String project, AccessDeveloper person, {required bool remove}) async {
    changes.add('$project/${person.login}/$remove');
  }
}

void main() {
  // Harm: stale or arbitrary names must not remove somebody outside the accepted project list.
  test('removal targets only the selected accepted person and project', () async {
    final people = _People();
    final action = ProjectDevelopers(project: 'demo', people: people);
    addTearDown(action.dispose);
    await action.load();
    await action.remove('unknown');
    expect(people.changes, isEmpty);
    await action.remove('worker');
    expect(people.changes, ['demo/worker/true']);
  });
  // Harm: a failed read must not turn a last verified list into authoritative absence.
  test('a failed refresh retains the last accepted persons', () async {
    final people = _People();
    final action = ProjectDevelopers(project: 'demo', people: people);
    addTearDown(action.dispose);
    await action.load();
    final before = action.access;
    people.fail = true;
    await action.load();
    expect(action.access, same(before));
    expect(action.problem, isNotNull);
  });
}

import 'package:porelo_frontend/src/app/registry_pages.dart';

/// A registry and host whose state changes only when the test sends a scoped operation.
class FakeRegistryPageSource implements RegistryPageSource {
  FakeRegistryPageSource(this.snapshot);
  RegistryPageSnapshot snapshot;
  final List<RegistryPageChange> published = [];
  final List<({RegistryTarget target, String revision})> applications = [];
  final Map<RegistryTarget, Map<String, String>> hostPersons = {};
  bool failRead = false;
  bool failPublish = false;
  bool failApply = false;
  int revision = 1;

  @override
  Future<RegistryPageSnapshot> read() async {
    if (failRead) throw Exception('access repository unreadable');
    return snapshot;
  }

  @override
  Future<String> publish(RegistryPageChange change) async {
    if (failPublish) throw Exception('publication refused');
    published.add(change);
    return 'revision-${++revision}';
  }

  @override
  Future<RegistryHostState> apply(RegistryTarget target, String revision) async {
    applications.add((target: target, revision: revision));
    if (failApply) throw Exception('host unavailable');
    final change = published.lastWhere((change) => change.target == target);
    if (change.person case final person?) {
      final people = hostPersons.putIfAbsent(target, () => {});
      switch (change.operation) {
        case RegistryOperation.projectLock || RegistryOperation.hostLock:
          people[person] = 'locked';
        case RegistryOperation.projectUnlock || RegistryOperation.hostUnlock:
          people[person] = 'active';
        case RegistryOperation.removePerson || RegistryOperation.deleteAccount:
          people.remove(person);
        default:
          people[person] = 'active';
      }
    }
    return RegistryHostState(revision: revision, personStates: Map.of(hostPersons[target] ?? {}));
  }
}

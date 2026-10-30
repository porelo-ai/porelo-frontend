import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/backups.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/host_forge_refresh.dart';
import 'package:porelo_frontend/src/app/project_check.dart';

class _Backend extends Fake implements FleetBackend {
  final calls = <String>[];
  @override
  Future<List<Followed>> refreshProjects({String? project}) async {
    calls.add('refresh $project');
    return [];
  }

  @override
  Future<Synced> syncUpstream(String project, {String? repository}) async {
    calls.add('sync $project $repository');
    return Synced.from({'outcome': 'MEASURED', 'measured': true, 'behind': 0});
  }
}

class _HostForge implements HostForgeRefresh {
  final calls = <String>[];
  @override
  Future<List<Followed>> refresh(String project) async {
    calls.add('refresh $project');
    return [];
  }

  @override
  Future<Synced> sync(String project, {String? repository}) async {
    calls.add('sync $project $repository');
    return Synced.from({'outcome': 'MEASURED', 'measured': true, 'behind': 0});
  }
}

void main() {
  // Harm: a routine joined-project refresh fetches the central forge without intent or a person's credential.
  test('joined checks and backup sync never fall back to the legacy upstream', () async {
    final backend = _Backend();
    final check = ProjectCheck();
    final backups = Backups();
    addTearDown(check.dispose);
    addTearDown(backups.dispose);
    await check.checkNow(backend, 'example', ['api'], joinedHost: true);
    final words = await backups.syncFor(backend, 'example', repository: 'api', joinedHost: true);
    expect(words, isNotEmpty, reason: 'a project-menu refusal must reach the caller even without a backup view');
    expect(backend.calls, isEmpty);
    expect(check.saidAbout('example'), isNotEmpty);
    expect(backups.problem, isNotNull);
    final local = _HostForge();
    await check.checkNow(backend, 'example', ['api'], joinedHost: true, hostForge: local);
    await backups.syncFor(backend, 'example', repository: 'api', joinedHost: true, hostForge: local);
    expect(local.calls, ['refresh example', 'sync example api', 'sync example api']);
    expect(backend.calls, isEmpty);
  });

  // Harm: blocking joined transfers inadvertently breaks an existing non-host refresh.
  test('ordinary project refresh retains its upstream behavior', () async {
    final backend = _Backend();
    final check = ProjectCheck();
    final backups = Backups();
    addTearDown(check.dispose);
    addTearDown(backups.dispose);
    await check.checkNow(backend, 'example', ['api']);
    await backups.syncFor(backend, 'example', repository: 'api');
    expect(backend.calls, ['refresh example', 'sync example api', 'sync example api']);
  });
}

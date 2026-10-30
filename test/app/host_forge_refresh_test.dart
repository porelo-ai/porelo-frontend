import 'dart:async';

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
    expect(backups.problem, isNull);
    final local = _HostForge();
    await check.checkNow(backend, 'example', ['api'], joinedHost: true, hostForge: local);
    await backups.syncFor(backend, 'example', repository: 'api', joinedHost: true, hostForge: local);
    expect(local.calls, ['refresh example', 'sync example api', 'sync example api']);
    expect(backend.calls, isEmpty);
  });

  // Harm: a failed or overlapping sync changes which project's listing or repository is used.
  test('sync captures its own target without replacing the open backup listing', () async {
    final backend = _Backend();
    final backups = Backups()
      ..project = 'open'
      ..repository = 'original';
    addTearDown(backups.dispose);
    await backups.syncFor(backend, 'refused', repository: 'other', joinedHost: true);
    expect(backups.project, 'open');
    expect(backups.repository, 'original');
    await Future.wait([
      backups.syncFor(backend, 'first', repository: 'one', joinedHost: false),
      backups.syncFor(backend, 'second', repository: 'two', joinedHost: false),
    ]);
    expect(backend.calls, unorderedEquals(['sync first one', 'sync second two']));
    expect(backups.project, 'open');
    expect(backups.repository, 'original');
  });

  // Harm: one project's sync clears another project's refusal or corrupts the open listing.
  test('overlapping sync results and listing failures remain independent', () async {
    final backend = _Backend();
    final backups = Backups()
      ..project = 'open'
      ..repository = 'original'
      ..problem = 'listing refusal';
    addTearDown(backups.dispose);
    final slow = _WaitingHost();
    final pending = backups.syncFor(backend, 'first', joinedHost: true, hostForge: slow);
    final refusal = await backups.syncFor(backend, 'second', joinedHost: true);
    expect(refusal, contains('Host forge refresh'));
    expect(backups.problem, 'listing refusal');
    slow.answer.complete(Synced.from({'outcome': 'MEASURED', 'measured': true, 'behind': 2}));
    expect(await pending, contains('2 commits'));
    expect(backups.problem, 'listing refusal');
    expect(backups.busy, isFalse);
  });

  // Harm: blocking joined transfers inadvertently breaks an existing non-host refresh.
  test('ordinary project refresh retains its upstream behavior', () async {
    final backend = _Backend();
    final check = ProjectCheck();
    final backups = Backups();
    addTearDown(check.dispose);
    addTearDown(backups.dispose);
    await check.checkNow(backend, 'example', ['api'], joinedHost: false);
    await backups.syncFor(backend, 'example', repository: 'api', joinedHost: false);
    expect(backend.calls, ['refresh example', 'sync example api', 'sync example api']);
  });
}

class _WaitingHost extends _HostForge {
  final answer = Completer<Synced>();
  @override
  Future<Synced> sync(String project, {String? repository}) => answer.future;
}

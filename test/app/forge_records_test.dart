import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/forge.dart' show MemoryForgeTokens;
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/forge_records.dart';

const _github = ForgeEntry(id: 'github.com', kind: 'github', name: 'GitHub', address: 'github.com');

void main() {
  late ForgeConnection forges;
  late Map<String, _Machine> watched;
  late DateTime at;
  late ForgeRecords records;

  setUp(() {
    forges = ForgeConnection(MemoryForgeTokens());
    watched = {'laptop': _Machine()};
    at = DateTime.utc(2026, 11, 25, 12);
    records = ForgeRecords(
      forges: forges,
      machines: () => [for (final MapEntry(:key, :value) in watched.entries) (name: key, backend: value)],
      now: () => at,
    );
  });

  Future<void> look() async {
    records.look();
    await pumpEventQueue();
  }

  // Harm: a forge set up under My forges stays unknown to a machine, whose tasks then cannot reach it; or every change
  // of a machine sends it again.
  test('each watched machine is told each forge once, also one watched later', () async {
    forges.entries = [_github];
    await look();
    await look();
    watched['fedora'] = _Machine();
    await look();

    expect(watched['laptop']!.set, [('github.com', 'github', null)]);
    expect(watched['fedora']!.set, [('github.com', 'github', null)]);
  });

  // Harm: a machine is told again what it knows, and a trust the person gave it is lost on the way.
  test('a forge the machine knows alike is not told again, and a trust it holds is kept', () async {
    watched['laptop']!.known['github.com'] = const ForgeInstance(
      host: 'github.com',
      adapter: 'github',
      comments: 'TRUSTED',
    );
    watched['laptop']!.known['forge.example'] = const ForgeInstance(
      host: 'forge.example',
      adapter: 'github',
      unreadable: 'the file is cut short',
    );
    forges.entries = [
      _github,
      const ForgeEntry(id: 'forge.example', kind: 'github', name: 'Work', address: 'forge.example'),
    ];
    await look();

    expect(watched['laptop']!.set, [('forge.example', 'github', null)], reason: 'an unreadable entry says no reading');
  });

  // Harm: comments are trusted nobody chose, or the person's choice of extended never reaches the machine.
  test("the person's choice decides: trusted is sent as chosen, extended sends none", () async {
    watched['laptop']!.known['github.com'] = const ForgeInstance(
      host: 'github.com',
      adapter: 'github',
      comments: 'TRUSTED',
    );
    forges.entries = [_github];
    await forges.readComments(_github, 'EXTENDED');
    await look();
    final work = const ForgeEntry(id: 'forge.example', kind: 'github', name: 'Work', address: 'forge.example');
    forges.entries = [...forges.entries, work];
    await forges.readComments(work, 'TRUSTED');
    await look();

    expect(watched['laptop']!.set, [('github.com', 'github', null), ('forge.example', 'github', 'TRUSTED')]);
  });

  // Harm: a machine with no adapter for the forge is sent a forge it refuses, and the person never learns why its
  // tasks cannot reach it.
  test('a machine with no adapter of the forge kind is not told it, and that is said', () async {
    watched['laptop']!.adapters = const [];
    forges.entries = [_github];
    await look();

    expect(watched['laptop']!.set, isEmpty);
    expect(records.problems.values, [
      'laptop has no forge adapter for github installed, so its tasks cannot reach '
          'github.com.',
    ]);
  });

  // Harm: an older Porelo without forges is said wrong on every change, or a tunnel's own forge is sent to every machine.
  test('an older Porelo is told nothing and nothing is said; a forge a tunnel serves is never sent', () async {
    watched['laptop']!.older = true;
    watched['fedora'] = _Machine();
    forges.entries = [
      ForgeEntry(id: 'tunnel', kind: 'github', name: 'Host', address: 'forge.host', hostMachine: 'host'),
    ];
    await look();

    expect(watched['fedora']!.set, isEmpty);
    expect(records.problems, isEmpty);
  });

  // Harm: a machine that cannot read its own forge file is taken for one not reached, and the person never learns why.
  test('a machine that cannot read its forges says why for each forge', () async {
    watched['laptop']!.refusal = const VarlinkException('org.fuin.porelo.Tasks1.ForgeFileUnreadable', {
      'reason': 'the forge file is not valid YAML at line 3',
    });
    forges.entries = [_github];
    await look();

    expect(watched['laptop']!.set, isEmpty);
    expect(records.problems, {
      ('laptop', 'github.com'): 'laptop cannot read the forges it keeps: the forge file is not valid YAML at line 3.',
    });
  });

  // Harm: a machine not reached is asked again on every change of any machine, or never again.
  test('a machine not reached is asked again only after a while', () async {
    watched['laptop']!.unreached = true;
    forges.entries = [_github];
    await look();
    watched['laptop']!.unreached = false;
    await look();
    expect(watched['laptop']!.set, isEmpty);

    at = at.add(const Duration(minutes: 2));
    await look();
    expect(watched['laptop']!.set, [('github.com', 'github', null)]);
  });

  // Harm: a trust the person chose while the machine was being asked never reaches it.
  test('a forge changed while a machine is asked is told it once that call is over', () async {
    final asked = Completer<void>();
    watched['laptop']!.hold = asked;
    forges.entries = [_github];
    records.look();
    await pumpEventQueue();
    await forges.readComments(_github, 'TRUSTED');
    records.look();
    asked.complete();
    await pumpEventQueue();

    expect(watched['laptop']!.set, [('github.com', 'github', null), ('github.com', 'github', 'TRUSTED')]);
  });

  // Harm: a machine that refused a forge, or lacked its adapter, is counted as told and never asked again once fixed.
  test('a machine that refused a forge says why and is asked again after a while', () async {
    watched['laptop']!.adapters = const [];
    forges.entries = [_github];
    await look();
    watched['laptop']!.adapters = const ['github'];
    await look();
    expect(watched['laptop']!.set, isEmpty);

    at = at.add(const Duration(minutes: 2));
    await look();
    expect(watched['laptop']!.set, [('github.com', 'github', null)]);
    expect(records.problems, isEmpty);
  });

  // Harm: a forge set up twice under one host is told twice with two readings, or trusted although one chose extended.
  test('two forges of one host are told once, trusted only where none chose extended', () async {
    forges.entries = [
      _github.readingComments('TRUSTED'),
      const ForgeEntry(id: 'github.com#2', kind: 'github', name: 'Work', address: 'github.com', comments: 'EXTENDED'),
    ];
    await look();

    expect(watched['laptop']!.set, [('github.com', 'github', null)]);
  });

  // Harm: a window closed while a machine is asked fails with a use after dispose.
  test('an answer that comes after the window closed is said to nobody', () async {
    final asked = Completer<void>();
    watched['laptop']!.hold = asked;
    forges.entries = [_github];
    records.look();
    await pumpEventQueue();
    records.dispose();
    asked.complete();
    await pumpEventQueue();

    expect(watched['laptop']!.set, isEmpty);
  });

  // Harm: the person's choice of trust is lost when the window starts again.
  test('the chosen reading of comments is kept with the forge', () {
    final kept = ForgeEntry.fromJson(_github.readingComments('TRUSTED').toJson());
    expect(kept?.trusted, isTrue);
    expect(ForgeEntry.fromJson(_github.toJson())?.comments, isNull);
    expect(ForgeEntry.fromJson({..._github.toJson(), 'comments': 'ANYTHING'})?.comments, isNull);
  });
}

/// A machine that knows forges as told, with the adapters it has installed.
class _Machine implements KnowsForges {
  final known = <String, ForgeInstance>{};
  final set = <(String, String, String?)>[];
  List<String> adapters = const ['github'];
  bool older = false, unreached = false;
  VarlinkException? refusal;

  /// Held until completed: the answer `Forges` waits for meanwhile.
  Completer<void>? hold;

  @override
  Future<MachineForges> forges() async {
    if (older) throw const FeatureNotSupported('Forges');
    if (unreached) throw const VarlinkDisconnected('the tunnel is down');
    if (refusal case final refused?) throw refused;
    await hold?.future;
    return MachineForges(forges: known.values.toList(), adapters: adapters);
  }

  @override
  Future<void> forgeSet(String host, String adapter, {String? comments}) async {
    set.add((host, adapter, comments));
    known[host] = ForgeInstance(host: host, adapter: adapter, comments: comments ?? 'EXTENDED');
  }
}

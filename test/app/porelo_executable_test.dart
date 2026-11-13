// Linux only: it reads owners and modes of real files, which Windows does not keep.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forward_records.dart';
import 'package:porelo_frontend/src/app/porelo_executable.dart';

void main() {
  late Directory where;
  late String home;
  late String real;
  final me = const LinuxProcessTable().myUid!;

  setUp(() {
    where = Directory(Directory.systemTemp.createTempSync('pe-').resolveSymbolicLinksSync());
    addTearDown(() => where.deleteSync(recursive: true));
    home = '${where.path}/home';
    Directory('$home/.local/bin').createSync(recursive: true);
    Directory('${where.path}/opt/porelo').createSync(recursive: true);
    real = '${where.path}/opt/porelo/porelo';
    File(real).writeAsStringSync('#!/bin/sh\n');
    for (final each in [where.path, home, '$home/.local', '$home/.local/bin', '${where.path}/opt']) {
      Process.runSync('chmod', <String>['755', each]);
    }
    Process.runSync('chmod', <String>['755', '${where.path}/opt/porelo', real]);
  });

  /// The folders above the test's own, as a machine's installed system has them: root's, written by root alone. The
  /// test's temporary folder may lie in a shared `/tmp`, which says nothing about where Porelo is installed.
  PathFacts? system(String path, int? descriptor) => path == where.path || path.startsWith('${where.path}/')
      ? pathFactsOf(path, descriptor)
      : const PathFacts(owner: 0, permissions: 0x1ed, type: FileSystemEntityType.directory);

  /// The test's own files carry the gid it runs as; [group] is that gid, or another.
  PoreloFound find({List<String>? places, ReadPathFacts? facts, int? group}) => findPoreloExecutable(
    places: places ?? poreloPlaces(<String, String>{'HOME': home}),
    onLinux: true,
    facts: facts ?? system,
    me: me,
    myGroup: group ?? pathFactsOf(real, null)!.group,
  );

  // Harm: the planner given a relative or linked path, which another file swapped in later would answer for.
  test("the account's own install is found first, by its absolute path with its links followed", () {
    Link('$home/.local/bin/porelo').createSync(real);

    expect(find(), (path: real, refused: null));
  });

  // Harm: a planner given nothing where only the package installed Porelo, or the package's where the person has
  // their own.
  test("the package's install is taken where the account has none of its own", () {
    expect(find(places: <String>['$home/.local/bin/porelo', real]), (path: real, refused: null));
    expect(poreloPlaces(<String, String>{'HOME': home}), <String>['$home/.local/bin/porelo', '/usr/bin/porelo']);
    expect(poreloPlaces(const <String, String>{}), <String>['/usr/bin/porelo'], reason: 'no home, no own install');
    expect(poreloPlaces(const <String, String>{'HOME': 'relative'}), <String>[
      '/usr/bin/porelo',
    ], reason: 'a home that is no absolute path is none');
  });

  // Harm: the planner lends the person's forge tokens through a program another account could swap.
  test('a Porelo that others could swap is refused, and the next place is not taken instead', () {
    Link('$home/.local/bin/porelo').createSync(real);
    // A second Porelo the check would pass, where a refused first place falling through would find it.
    final next = '${where.path}/opt/porelo/next';
    File(next).writeAsStringSync('#!/bin/sh\n');
    Process.runSync('chmod', <String>['755', next]);
    expect(find(places: <String>[next]).path, next, reason: 'the next place alone would be taken');
    Process.runSync('chmod', <String>['757', real]);
    expect(find(places: <String>['$home/.local/bin/porelo', next]).path, isNull);
    expect(find().refused, contains('can be written by others'));

    Process.runSync('chmod', <String>['755', real]);
    Process.runSync('chmod', <String>['777', '${where.path}/opt']);
    expect(find().path, isNull, reason: 'a folder above it others can write');
    expect(find().refused, contains('${where.path}/opt'));

    Process.runSync('chmod', <String>['755', '${where.path}/opt']);
    PathFacts? foreign(String path, int? descriptor) => path == real
        ? const PathFacts(owner: 4242, permissions: 0x1ed, type: FileSystemEntityType.file)
        : system(path, descriptor);
    final owned = find(places: <String>['$home/.local/bin/porelo'], facts: foreign);
    expect(owned.path, isNull);
    expect(owned.refused, contains('owned by another account'));
  });

  // Harm: a planner given a path no Porelo lies at, or one off Linux, where the window has no Porelo of its own.
  test('nothing is given where no Porelo is installed, or off Linux, and nothing is refused', () {
    expect(find(places: <String>['$home/.local/bin/porelo']), (path: null, refused: null));
    Link('$home/.local/bin/porelo').createSync(real);
    expect(findPoreloExecutable(places: <String>['$home/.local/bin/porelo'], onLinux: false, facts: system, me: me), (
      path: null,
      refused: null,
    ));
  });

  // Harm: private repositories silently not read where the person's umask is 002 with a group of their own; or a
  // Porelo another group may write lent the person's tokens.
  test("a Porelo its owner's own group may write is taken, another group's refused", () {
    Link('$home/.local/bin/porelo').createSync(real);
    Process.runSync('chmod', <String>['775', real, '$home/.local/bin', '${where.path}/opt']);
    final mine = pathFactsOf(real, null)!.group;

    expect(find(group: mine), (path: real, refused: null), reason: 'the group is the person\'s own');
    final other = find(group: mine + 1);
    expect(other.path, isNull);
    expect(other.refused, contains('a group other than your own'));
  });

  // Harm: a Porelo path the window inherited, which anybody who started it could choose, handed on to the planner.
  test('the planner never inherits a Porelo path, and is given only the one found', () {
    final inherited = <String, String>{'PATH': '/usr/bin', 'PORELO_EXECUTABLE': '/tmp/evil', 'porelo_executable': 'x'};

    expect(plannerEnvironment(inherited, const <String, String>{}), <String, String>{'PATH': '/usr/bin'});
    expect(plannerEnvironment(inherited, <String, String>{'PORELO_EXECUTABLE': real}), <String, String>{
      'PATH': '/usr/bin',
      'PORELO_EXECUTABLE': real,
    });
  });
}

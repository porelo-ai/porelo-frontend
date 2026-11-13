import 'dart:io';

import 'forward_records.dart' show LinuxProcessTable, PathFacts, ReadPathFacts, pathFactsOf;

/// The environment variable that names Porelo's executable to the planner the window starts.
const poreloExecutableVariable = 'PORELO_EXECUTABLE';

/// Where Porelo's own installs put it, in the order the window takes them: the account's own install, which its login
/// shell finds first, then the package's. Never a search path, a setting, or anything a repository controls.
List<String> poreloPlaces(Map<String, String> environment) => <String>[
  if (environment['HOME'] case final home? when home.startsWith('/') && !home.split('/').contains('..'))
    '$home/.local/bin/porelo',
  '/usr/bin/porelo',
];

/// Porelo's executable as the window found it: an absolute path with its links followed, or why none is given.
typedef PoreloFound = ({String? path, String? refused});

/// Finds Porelo at the first of [places] where anything is, follows its links, and gives its path only where neither
/// the file nor any folder up to `/` can be written by anybody but its owner, root and the person's own private group
/// ([myGroup], see [privateGroupOf]), and each is owned by root or by [me]. Off Linux ([onLinux]) the window has no Porelo of its own to
/// vouch for, so none is given and nothing is refused.
PoreloFound findPoreloExecutable({List<String>? places, bool? onLinux, ReadPathFacts? facts, int? me, int? myGroup}) {
  if (!(onLinux ?? Platform.isLinux)) return (path: null, refused: null);
  final read = facts ?? pathFactsOf;
  final uid = me ?? const LinuxProcessTable().myUid;
  final gid = myGroup ?? privateGroupOf(_myGid(), uid);
  for (final place in places ?? poreloPlaces(Platform.environment)) {
    if (FileSystemEntity.typeSync(place, followLinks: false) == FileSystemEntityType.notFound) continue;
    // The first place where anything is decides: a refused one is never passed over for the next.
    final String resolved;
    try {
      resolved = File(place).resolveSymbolicLinksSync();
    } on FileSystemException catch (failure) {
      return (
        path: null,
        refused: '$place cannot be followed to a file: ${failure.osError?.message ?? failure.message}',
      );
    }
    if (uid == null) return (path: null, refused: 'the account this window runs as cannot be told');
    final file = read(resolved, null);
    if (file == null || file.type != FileSystemEntityType.file) {
      return (path: null, refused: '$resolved is no file');
    }
    if (_whyNot(resolved, file, uid, gid) case final why?) return (path: null, refused: why);
    var folder = resolved.substring(0, resolved.lastIndexOf('/'));
    while (true) {
      final shown = folder.isEmpty ? '/' : folder;
      final facts = read(shown, null);
      if (facts == null || facts.type != FileSystemEntityType.directory) {
        return (path: null, refused: 'the folder $shown of $resolved cannot be read');
      }
      if (_whyNot(shown, facts, uid, gid) case final why?) {
        return (path: null, refused: '$why, and $resolved lies in it');
      }
      if (folder.isEmpty) break;
      folder = folder.substring(0, folder.lastIndexOf('/'));
    }
    return (path: resolved, refused: null);
  }
  return (path: null, refused: null);
}

/// Why [path] could be swapped by somebody else, or null where it cannot.
///
/// A group may write it only where the group is the person's own primary one, as a umask of 002 with a group of the
/// person's own leaves the person's folders.
String? _whyNot(String path, PathFacts facts, int me, int? myGroup) {
  if (facts.owner != 0 && facts.owner != me) return '$path is owned by another account';
  if (facts.permissions & 0x2 != 0) return '$path can be written by others than its owner';
  if (facts.permissions & 0x10 != 0 && (myGroup == null || facts.group != myGroup)) {
    return '$path can be written by a group other than your own private one';
  }
  return null;
}

/// [gid] where it is the person's own private group: the primary group of the account [me] alone, which no other
/// account has as its primary group in [passwd] and which [groups] lists with no member but the person; else null.
/// The planner keeps the same rule for the Porelo it is given.
int? privateGroupOf(int? gid, int? me, {String? passwd, String? groups}) {
  if (gid == null || me == null) return null;
  List<List<String>> rows(String? given, String path) {
    try {
      return (given ?? File(path).readAsStringSync())
          .split('\n')
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .map((line) => line.split(':'))
          .toList();
    } on FileSystemException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  final accounts = rows(passwd, '/etc/passwd').where((row) => row.length >= 4);
  final mine = accounts.where((row) => int.tryParse(row[2]) == me).firstOrNull;
  if (mine == null || int.tryParse(mine[3]) != gid) return null;
  if (accounts.any((row) => int.tryParse(row[2]) != me && int.tryParse(row[3]) == gid)) return null;
  // Every line naming the gid counts, as the system's own lookup takes them all.
  final lines = rows(groups, '/etc/group').where((row) => row.length >= 4 && int.tryParse(row[2]) == gid).toList();
  if (lines.isEmpty) return null;
  final members = lines.expand((line) => line[3].split(',')).map((each) => each.trim()).where((e) => e.isNotEmpty);
  return members.every((each) => each == mine[0]) ? gid : null;
}

/// The one gid this window runs as (real, effective, saved and file-system alike), or null where it cannot say.
int? _myGid() {
  try {
    final line = File('/proc/self/status').readAsLinesSync().firstWhere((each) => each.startsWith('Gid:'));
    final gids = line.substring(4).trim().split(RegExp(r'\s+')).map(int.tryParse).toSet();
    return gids.length == 1 ? gids.single : null;
  } on FileSystemException {
    return null;
  } on StateError {
    return null;
  }
}

/// The environment of a planner the window starts: [inherited] without any Porelo path it names, in any case of the
/// name as Windows reads it, then [added]. The planner is given only the Porelo the window found itself.
Map<String, String> plannerEnvironment(Map<String, String> inherited, Map<String, String> added) => <String, String>{
  for (final entry in inherited.entries)
    if (entry.key.toUpperCase() != poreloExecutableVariable) entry.key: entry.value,
  ...added,
};

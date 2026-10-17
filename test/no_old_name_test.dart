@Tags(<String>['documents'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds every tracked file to the product's present name.
///
/// **A renamed product keeps its old name only where a sentence says what the old name was.** One
/// stray spelling in a path, a socket or a package name is a contract nobody serves any more, and it
/// reads as current to whoever finds it. Spelled in two halves here, so this file is no finding.
void main() {
  final oldName = RegExp(
    'so'
    'kar',
    caseSensitive: false,
  );
  final tracked = _trackedFiles();

  test('the tracked files are the repository', () {
    // Without this every test below passes by examining nothing.
    expect(
      tracked,
      containsAll(<String>['pubspec.yaml', 'AGENTS.md', 'CHANGELOG.md', 'lib/main.dart']),
      reason: 'git ls-files did not list the repository',
    );
  });

  test('no tracked path says the old name', () {
    final named = tracked.where(oldName.hasMatch).toList();
    expect(named, isEmpty, reason: 'these paths still carry the old name:\n${named.join('\n')}');
  });

  test('no tracked file says the old name outside what says what it was', () {
    final found = <String>[];
    for (final path in tracked) {
      final bytes = File(path).readAsBytesSync();
      if (bytes.contains(0)) continue;
      final lines = String.fromCharCodes(bytes).split('\n');
      final kept = _kept(path, lines);
      for (var i = 0; i < lines.length; i++) {
        if (oldName.hasMatch(lines[i]) && !kept.contains(i)) found.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(found, isEmpty, reason: 'the old name is still written here:\n${found.join('\n')}');
  });

  test('every exception still holds the old name', () {
    // An exception that no longer matches anything is a hole the old name can come back through.
    for (final path in <String>['CHANGELOG.md']) {
      final lines = File(path).readAsLinesSync();
      final kept = _kept(path, lines);
      expect(
        kept.where((i) => oldName.hasMatch(lines[i])),
        isNotEmpty,
        reason: '$path is kept for the old name but says it nowhere',
      );
    }
  });
}

/// The lines of [path] that may say the old name, by index.
///
/// The released sections of the changelog say what was shipped under it, and the sentence that
/// announces the rename says what it was.
Set<int> _kept(String path, List<String> lines) {
  if (path == 'CHANGELOG.md') {
    final released = lines.indexWhere((line) => RegExp(r'^## \[\d').hasMatch(line));
    return <int>{
      for (var i = 0; i < lines.length; i++)
        if ((released >= 0 && i >= released) || lines[i].contains(_renameSentence)) i,
    };
  }
  return const <int>{};
}

/// The changelog's announcement of the rename, the one sentence above the released sections kept.
const _renameSentence = ' is now Porelo, ';

List<String> _trackedFiles() {
  final listed = Process.runSync(
    'git',
    <String>['ls-files', '-z'],
    environment: <String, String>{'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
  );
  if (listed.exitCode != 0) throw StateError('git ls-files exited ${listed.exitCode}: ${listed.stderr}');
  return (listed.stdout as String).split('\x00').where((path) => path.isNotEmpty && File(path).existsSync()).toList();
}

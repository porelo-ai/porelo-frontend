// Linux only: it reads the file's mode with stat, which Windows has no such thing as.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

/// How the preferences file is written.
///
/// Not about what is in it — that is proven where each choice is made — but about the two
/// properties of the file itself. It names the machines somebody watches and the accounts they log
/// in as, and a half-written one reads exactly like a first run.
void main() {
  late Directory where;
  late File file;

  setUp(() {
    where = Directory.systemTemp.createTempSync('porelo-settings-test');
    file = File('${where.path}/porelo/frontend.json');
    addTearDown(() {
      if (where.existsSync()) where.deleteSync(recursive: true);
    });
  });

  String inodeOf(File of) =>
      Process.runSync('stat', <String>['-c', '%i', of.path]).stdout.toString().trim();

  test('what it writes is readable by nobody but its owner', () async {
    final store = FileSettingsStore(file: file);

    await store.write(<String, Object?>{'appearance': 'dark'});

    expect(FileStat.statSync(file.path).mode & 0x3F, 0,
        reason: 'it names the hosts somebody logs in to');
  });

  test('the file is replaced in one step, never written into', () async {
    // A write in place is not one step: a crash halfway leaves truncated JSON, and truncated JSON
    // is read as an empty configuration — so "why are my machines gone" would have no answer in
    // the file. A rename within one directory is atomic.
    final store = FileSettingsStore(file: file);
    await store.write(<String, Object?>{'appearance': 'light'});
    final before = inodeOf(file);

    await store.write(<String, Object?>{'appearance': 'dark'});

    expect(inodeOf(file), isNot(before), reason: 'the same file was written into');
    expect(await store.read(), containsPair('appearance', 'dark'));
  });

  test('it leaves nothing beside itself', () async {
    final store = FileSettingsStore(file: file);

    await store.write(<String, Object?>{'appearance': 'dark'});

    final left = where
        .listSync(recursive: true)
        .map((each) => each.path.split('/').last)
        .where((name) => name != 'frontend.json' && name != 'porelo');
    expect(left, isEmpty);
  });

  test('a truncated file is a first run rather than a crash', () async {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('{"machines": [{"name": "half');

    expect(await FileSettingsStore(file: file).read(), isEmpty);
  });
}

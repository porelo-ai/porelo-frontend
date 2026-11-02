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

  String inodeOf(File of) => Process.runSync('stat', <String>['-c', '%i', of.path]).stdout.toString().trim();

  test('what it writes is readable by nobody but its owner', () async {
    final store = FileSettingsStore(file: file);

    await store.write(<String, Object?>{'appearance': 'dark'});

    expect(FileStat.statSync(file.path).mode & 0x3F, 0, reason: 'it names the hosts somebody logs in to');
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

  group('settings from before the organization model', () {
    late File dropped;

    setUp(() {
      dropped = File('${file.path}.dropped');
      file.parent.createSync(recursive: true);
    });

    // Harm: a person's old hosts and organization address stay in force under a model that no longer reads them, unsaid.
    test('a file with no mark is put aside whole, and the person told once', () async {
      const old = '{"machines":[{"name":"build"}],"registryRepository":"git@forge.example.org:acme/registry.git"}';
      file.writeAsStringSync(old);
      final store = FileSettingsStore(file: file);
      expect(await store.dropOldForm(), isTrue);
      expect(dropped.readAsStringSync(), old);
      expect(await store.read(), {'form': settingsForm});
      expect(await store.dropOldForm(), isFalse, reason: 'a second start says nothing');
      expect(dropped.readAsStringSync(), old, reason: 'and leaves what was kept');
    });

    // Harm: a person's settings are dropped again at every start.
    test('a file of the new form keeps all it holds', () async {
      final store = FileSettingsStore(file: file);
      final settings = Settings(store);
      await settings.load();
      await settings.setRefreshSeconds(45);
      settings.dispose();
      final written = file.readAsStringSync();
      expect(await store.dropOldForm(), isFalse);
      expect(file.readAsStringSync(), written);
      expect(dropped.existsSync(), isFalse);
      final again = Settings(store);
      await again.load();
      expect(again.refreshSeconds, 45);
      again.dispose();
    });

    // Harm: a damaged file is reported as an old one, or a first run is told of settings it never had.
    test('an unreadable file and no file are no old form', () async {
      final store = FileSettingsStore(file: file);
      expect(await store.dropOldForm(), isFalse);
      expect(file.existsSync(), isFalse);
      file.writeAsStringSync('{"machines":[');
      expect(await store.dropOldForm(), isFalse);
      expect(file.readAsStringSync(), '{"machines":[');
      expect(dropped.existsSync(), isFalse);
    });

    // Harm: other programs read the machines from this file, and find no list after the drop.
    test('the machines are written in their shape again after the drop', () async {
      file.writeAsStringSync('{"machines":[{"name":"build"}]}');
      final store = FileSettingsStore(file: file);
      await store.dropOldForm();
      final settings = Settings(store);
      await settings.load();
      await settings.setRefreshSeconds(45);
      settings.dispose();
      final kept = await store.read();
      expect(kept['form'], settingsForm);
      expect(kept['machines'], isA<List<Object?>>());
      expect(
        kept['machines'],
        isNot(contains(containsPair('name', 'build'))),
        reason: 'what was dropped stays dropped',
      );
    });
  });
}

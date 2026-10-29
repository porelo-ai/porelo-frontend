import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

class _DiscardingStore extends MemorySettingsStore {
  bool discard = false;
  @override
  Future<void> write(Map<String, Object?> values) async {
    if (!discard) await super.write(values);
  }
}

void main() {
  // Harm: removing an old copy from another host must not lose the project's current host association.
  test('confirmed removal clears only the associated host', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    final reloaded = Settings(store);
    addTearDown(settings.dispose);
    addTearDown(reloaded.dispose);
    await settings.rememberProjectHost('demo', 'orchard');
    await settings.forgetProjectHost('demo', host: 'garden');
    await reloaded.load();
    expect(settings.projectHost('demo'), 'orchard');
    expect(reloaded.projectHost('demo'), 'orchard');
    await settings.forgetProjectHost('demo', host: 'orchard');
    await reloaded.load();
    expect(settings.projectHost('demo'), isNull);
    expect(reloaded.projectHost('demo'), isNull);
  });

  // Harm: a lost or confused project association can direct a root removal to the wrong server.
  test('each project retains its own host across a settings reload', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    final reloaded = Settings(store);
    addTearDown(settings.dispose);
    addTearDown(reloaded.dispose);
    await settings.rememberProjectHost('demo', 'orchard');
    await settings.rememberProjectHost('other', 'garden');
    await reloaded.load();
    expect(reloaded.projectHost('demo'), 'orchard');
    expect(reloaded.projectHost('other'), 'garden');
    expect(reloaded.projectHost('absent'), isNull);
  });

  // Harm: an unsuccessful save must not silently retarget a destructive action in memory.
  test('a discarded association write preserves the previous host', () async {
    final store = _DiscardingStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.rememberProjectHost('demo', 'orchard');
    store.discard = true;
    await expectLater(settings.rememberProjectHost('demo', 'garden'), throwsA(isA<FileSystemException>()));
    expect(settings.projectHost('demo'), 'orchard');
  });

  // Harm: unchecked settings can become host-record lookups for root helper operations.
  test('malformed project associations are ignored on load and refused on write', () async {
    final settings = Settings(
      MemorySettingsStore({
        'projectHosts': {'demo': 'orchard', 'bad': 12, '../other': 'garden', 'unsafe': '../garden'},
      }),
    );
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.projectHost('demo'), 'orchard');
    for (final project in ['bad', '../other', 'unsafe']) {
      expect(settings.projectHost(project), isNull);
    }
    await expectLater(settings.rememberProjectHost('../other', 'garden'), throwsA(isA<HostFilesRefused>()));
    await expectLater(settings.rememberProjectHost('demo', '../garden'), throwsA(isA<HostFilesRefused>()));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../support/host_rental.dart';

import 'package:porelo_host/porelo_host.dart';

void main() {
  // Harm: setup retries silently lose resource limits or bind a different local service.
  test('preparation choices survive restart and become public setup arguments', () async {
    final record = signedSetup.withPreparationSettings(
      const HostPreparationSettings(forgeRunnerCapacity: 1, forgeJobCpus: 1, forgeJobMemory: '768m', matrixPort: 8548),
    );
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.rememberHostUp('orchard', record);
    final restored = Settings(store);
    addTearDown(restored.dispose);
    await restored.load();
    final saved = restored.hostUp('orchard')!;
    expect(saved.preparationSettings.stored, record.preparationSettings.stored);
    expect(
      saved.arguments('orchard'),
      containsAllInOrder(['--forge-runner-capacity', '1', '--forge-job-cpus', '1', '--forge-job-memory', '768m']),
    );
    expect(saved.arguments('orchard'), containsAllInOrder(['--matrix-port', '8548']));
    for (final invalid in [0, '1']) {
      expect(
        HostUpRecord.fromStored({
          ...record.stored,
          'preparationSettings': {'forge_job_cpus': invalid},
        }),
        isNull,
      );
    }
  });

  // Harm: an unrelated settings write must not hide a newly rented server during preparation.
  test('signed-state preparation and its original start survive reload and record updates', () async {
    final record = signedSetup.withPreparation(DateTime.utc(2000));
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.rememberHostUp('orchard', record.withProtocol(const []));
    final again = Settings(store);
    addTearDown(again.dispose);
    await again.load();
    expect(again.hostUp('orchard')?.preparing, isTrue);
    expect(again.hostUp('orchard')?.startedAt, DateTime.utc(2000));
    expect(again.hostUp('orchard')?.legacy, isFalse);
    expect(again.hostUp('orchard')?.arguments('orchard'), isNot(contains('--identity')));
  });
  // Harm: malformed new progress must not be promoted as a completed server.
  test('new preparation requires a valid UTC start', () {
    for (final start in [null, 7, 'bad', '2000-01-01T00:00:00']) {
      expect(HostUpRecord.fromStored({...signedSetup.stored, 'preparing': true, 'startedAt': start}), isNull);
    }
  });
}

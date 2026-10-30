import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../support/host_rental.dart';

void main() {
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
